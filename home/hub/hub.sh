# hub [section]: the settings hub. Runs in a floating Ghostty window
# (class dev.tushar.hub). With no argument it shows a menu; `hub <section>`
# jumps straight to one. Concatenated after lib.sh and the Nix-provided
# defaults (IDLE_*, SUNSET_*) at build time.
#
# Runtime state (everything else is Nix):
#   ~/.local/state/hypridle/overrides.conf   auto-lock timeouts, `source`d by hypridle
#   ~/.local/state/hypridle/off              flag: auto-lock disabled
#   ~/.local/state/hyprsunset/settings       night light choices
#   ~/.local/state/hyprsunset/hypr/hyprsunset.conf  generated from them

state=${XDG_STATE_HOME:-$HOME/.local/state}
idle=$state/hypridle/overrides.conf
sunset=$state/hyprsunset

pick() { gum choose --header "$1" "${@:2}"; } # Esc -> non-zero -> caller returns
oops() { gum style --foreground 9 "$1"; sleep 1.2; }

# ---------------------------------------------------------------- auto-lock
autolock() {
  local c st v
  while :; do
    [[ -e $state/hypridle/off ]] && st=off || st=on
    c=$(pick "auto-lock: $st" \
      "lock after      $(kv_get "$idle" lock "$IDLE_LOCK")s" \
      "screen off      $(kv_get "$idle" off "$IDLE_OFF")s" \
      "suspend (bat)   $(kv_get "$idle" suspend "$IDLE_SUSPEND")s" \
      "turn auto-lock $([[ $st == on ]] && echo off || echo on)" \
      "caffeine for 1 hour" \
      "reset to defaults") || return
    case $c in
      lock*|screen*|suspend*)
        local key=${c%% *}; [[ $key == screen ]] && key=off
        local def; def=IDLE_${key^^}
        v=$(gum input --header "$key timeout in seconds (default ${!def})" \
          --value "$(kv_get "$idle" "$key" "${!def}")") || continue
        if valid_seconds "$v"; then
          kv_set "$idle" "$key" "$v"
          systemctl --user restart hypridle
        else
          oops "needs a whole number of seconds, at least 30"
        fi ;;
      "turn auto-lock off")
        mkdir -p "$state/hypridle"; touch "$state/hypridle/off"
        systemctl --user stop hypridle ;;
      "turn auto-lock on")
        rm -f "$state/hypridle/off"
        systemctl --user start hypridle ;;
      caffeine*)
        setsid -f systemd-inhibit --what=idle --who=hub --why=caffeine sleep 3600
        oops "staying awake for 1 hour" ;;
      reset*)
        : > "$idle"
        systemctl --user restart hypridle ;;
    esac
  done
}

# -------------------------------------------------------------- night light
sunset_save() { # writes the config hyprsunset reads, then restarts it
  local on start end k
  on=$(kv_get "$sunset/settings" on 1)
  start=$(kv_get "$sunset/settings" start "$SUNSET_START")
  end=$(kv_get "$sunset/settings" end "$SUNSET_END")
  k=$(kv_get "$sunset/settings" kelvin "$SUNSET_KELVIN")
  mkdir -p "$sunset/hypr"
  sunset_conf "$on" "$start" "$end" "$k" > "$sunset/hypr/hyprsunset.conf"
  systemctl --user restart hyprsunset
}

nightlight() {
  local c v on
  while :; do
    on=$(kv_get "$sunset/settings" on 1)
    c=$(pick "night light: $([[ $on == 1 ]] && echo on || echo off)" \
      "turn $([[ $on == 1 ]] && echo off || echo on)" \
      "starts at      $(kv_get "$sunset/settings" start "$SUNSET_START")" \
      "ends at        $(kv_get "$sunset/settings" end "$SUNSET_END")" \
      "temperature    $(kv_get "$sunset/settings" kelvin "$SUNSET_KELVIN")K" \
      "off for now" \
      "warm now" \
      "reset to defaults") || return
    case $c in
      "turn off") kv_set "$sunset/settings" on 0; sunset_save ;;
      "turn on") kv_set "$sunset/settings" on 1; sunset_save ;;
      starts*|ends*)
        local key=start; [[ $c == ends* ]] && key=end
        v=$(gum input --header "$key time, HH:MM (24h)" \
          --value "$(kv_get "$sunset/settings" "$key" "$( [[ $key == start ]] && echo "$SUNSET_START" || echo "$SUNSET_END")")") || continue
        if valid_hhmm "$v"; then kv_set "$sunset/settings" "$key" "$v"; sunset_save
        else oops "use HH:MM, e.g. 20:30"; fi ;;
      temperature*)
        v=$(gum input --header "temperature in K (1000-6500, lower is warmer)" \
          --value "$(kv_get "$sunset/settings" kelvin "$SUNSET_KELVIN")") || continue
        if ! valid_kelvin "$v"; then oops "pick a number from 1000 to 6500"; continue; fi
        hyprctl hyprsunset temperature "$v" >/dev/null # live preview
        if gum confirm "keep ${v}K?"; then kv_set "$sunset/settings" kelvin "$v"; sunset_save
        else hyprctl hyprsunset reset >/dev/null; fi ;;
      "off for now") hyprctl hyprsunset identity >/dev/null ;;   # until the next scheduled change
      "warm now") hyprctl hyprsunset temperature 3500 >/dev/null ;;
      reset*) rm -rf "$sunset"; systemctl --user restart hyprsunset ;;
    esac
  done
}

# -------------------------------------------------------------------- power
power() {
  local k
  confirm() { printf '\n  %s? [y/N] ' "$1"; read -rsn1 k; [[ $k == y ]]; }
  clear; tput civis
  printf '\n  l  lock\n  s  suspend\n  e  log out\n  r  reboot\n  p  power off\n\n  esc  cancel\n'
  read -rsn1 k
  tput cnorm
  case $k in
    l) loginctl lock-session ;;
    s) systemctl suspend ;;
    e) confirm "log out" && hyprctl dispatch 'hl.dsp.exit()' ;;
    r) confirm "reboot" && systemctl reboot ;;
    p) confirm "power off" && systemctl poweroff ;;
    *) return ;;
  esac
  exit 0
}

# --------------------------------------------------------------------- keys
keys() {
  hyprctl binds -j \
    | jq -r '.[] | [.modmask, .key, (if .has_description then .description else "\(.dispatcher) \(.arg)" end)] | @tsv' \
    | while IFS=$'\t' read -r m key desc; do
        local combo; combo=$(mods "$m"); combo=${combo:+$combo+}$key
        printf '%-26s %s\n' "$combo" "$desc"
      done \
    | sort -u \
    | fzf --no-sort --layout=reverse --prompt 'keys > ' --color 'bg:#000000,bg+:#1c1c1c,fg:#a0a0a0,fg+:#ffffff,hl:#f5a524,hl+:#f5a524,prompt:#e6e6e6,pointer:#e6e6e6,border:#262626' >/dev/null
}

# --------------------------------------------------------------- dispatcher
run() {
  case $1 in
    wifi) wifitui ;;
    bluetooth) bluetui ;;
    audio) wiremix ;;
    displays) hyprmon ;;
    autolock) autolock ;;
    nightlight) nightlight ;;
    brightness)
      local b; b=$(pick "brightness: $(brightnessctl -m | cut -d, -f4)" 10% 25% 50% 75% 100%) \
        && brightnessctl -q set "$b" ;;
    power) power ;;
    keys) keys ;;
    services) systemd-manager-tui ;;
    *) oops "unknown section: $1"; return 1 ;;
  esac
}

if [[ $# -gt 0 ]]; then
  run "$1"
  exit
fi
while c=$(pick "hub" wifi bluetooth audio displays brightness nightlight autolock power keys services); do
  run "$c"
done
