# hub [section]: the settings hub. Runs in a floating Ghostty window
# (class dev.tushar.hub). With no argument it shows a menu; `hub <section>`
# jumps straight to one. Concatenated after lib.sh and the Nix-provided
# defaults (IDLE_*, SUNSET_*) at build time.
#
# Runtime state (everything else is Nix):
#   ~/.local/state/hypridle/overrides.conf   auto-lock timeouts, `source`d by hypridle
#   ~/.local/state/hypridle/off              flag: auto-lock disabled (idle inhibitor, see hub.nix)
#   ~/.local/state/hyprsunset/settings       night light choices
#   ~/.local/state/hyprsunset/hypr/hyprsunset.conf  generated from them

state=${XDG_STATE_HOME:-$HOME/.local/state}
idle=$state/hypridle/overrides.conf
sunset=$state/hyprsunset
LINES=$(tput lines) COLUMNS=$(tput cols) # not set in non-interactive bash

# Menus: hjkl to move/select/back, q or Esc to back out (non-zero -> caller
# returns). Centred in the hub window via fzf margins.
pick() {
  local n=$(( $# + 2 )) w=${#1} i # lines: items + header + prompt; width: longest line
  for i in "${@:2}"; do (( ${#i} > w )) && w=${#i}; done
  printf '%s\n' "${@:2}" | fzf --disabled --no-info --layout=reverse --header "$1" --prompt '' \
    --margin "$(( (LINES - n) / 2 > 0 ? (LINES - n) / 2 : 0 )),$(( (COLUMNS - w - 2) / 2 > 0 ? (COLUMNS - w - 2) / 2 : 0 ))" \
    --color "$fzf_colors" --bind 'j:down,k:up,l:accept,h:abort,q:abort'
}
oops() { gum style --foreground 9 "$1"; sleep 1.2; }
fzf_colors='bg:#000000,bg+:#1c1c1c,fg:#a0a0a0,fg+:#ffffff,hl:#f5a524,hl+:#f5a524,prompt:#e6e6e6,pointer:#e6e6e6,border:#262626'

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
        systemctl --user start autolock-off ;;
      "turn auto-lock on")
        rm -f "$state/hypridle/off"
        systemctl --user stop autolock-off ;;
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
  local k i
  confirm() { tput cup $(( row + ${#lines[@]} + 1 )) $col; printf '%s? [y/N] ' "$1"; read -rsn1 k; [[ $k == y ]]; }
  clear; tput civis
  local lines=("l  lock" "s  suspend" "e  log out" "r  reboot" "p  power off" "" "q  cancel") row col
  row=$(( (LINES - ${#lines[@]}) / 2 )); col=$(( (COLUMNS - 12) / 2 ))
  for i in "${!lines[@]}"; do tput cup $(( row + i )) $col; printf '%s' "${lines[i]}"; done
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
    | fzf --no-sort --layout=reverse --prompt 'keys > ' --color "$fzf_colors" >/dev/null
}

# ---------------------------------------------------------------- tailscale
tailscale_menu() {
  local c st state ip peer
  while :; do
    st=$(tailscale status --json 2>/dev/null) || st='{}'
    state=$(jq -r '.BackendState // "Stopped"' <<<"$st")
    ip=$(jq -r '.TailscaleIPs[0] // empty' <<<"$st")
    c=$(pick "tailscale: ${state,,}${ip:+ · $ip}" \
      "turn $([[ $state == Running ]] && echo off || echo on)" \
      "peers" \
      "copy my ip" \
      "admin console") || return
    case $c in
      "turn off") tailscale down ;;
      "turn on") tailscale up || oops "tailscale up failed" ;; # prints a login URL if needed
      peers)
        peer=$(tailscale status | fzf --no-sort --layout=reverse --prompt 'peers (enter copies ip) > ' --color "$fzf_colors") \
          && wl-copy -n "${peer%% *}" ;;
      "copy my ip") wl-copy -n "$ip" ;;
      admin*) xdg-open https://login.tailscale.com/admin/machines >/dev/null 2>&1 ;;
    esac
    refresh
  done
}

# ---------------------------------------------------------------- syncthing
# REST API on the local GUI port; the API key lives in Syncthing's config.
st_api() {
  local key
  key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$SYNCTHING_CONFIG" 2>/dev/null)
  curl -sf -H "X-API-Key: $key" "http://127.0.0.1:8384/rest/$1" "${@:2}"
}

syncthing_status() {
  local conns id label
  conns=$(st_api system/connections) || { echo "syncthing is not responding"; return; }
  echo "devices"
  st_api config/devices | jq -r --argjson c "$conns" \
    '.[] | select($c.connections[.deviceID]) | "  \(.name)\t\(if $c.connections[.deviceID].connected then "connected" else "offline" end)"'
  echo; echo "folders"
  st_api config/folders | jq -r '.[] | "\(.id)\t\(if .label == "" then .id else .label end)"' \
    | while IFS=$'\t' read -r id label; do
        st_api "db/status?folder=$id" | jq -r --arg l "$label" \
          '"  \($l)\t\(.state)\(if .needFiles > 0 then " · \(.needFiles) files to sync" else "" end)"'
      done
}

syncthing_menu() {
  local c n
  while :; do
    n=$(st_api system/connections | jq '[.connections[] | select(.connected)] | length') || n=
    c=$(pick "syncthing: ${n:+$n devices connected}${n:-not responding}" \
      "status" "rescan all" "open web ui" "restart") || return
    case $c in
      status) syncthing_status | column -t -s $'\t' | gum pager ;;
      "rescan all") st_api db/scan -X POST >/dev/null || oops "syncthing is not responding" ;;
      "open web ui") xdg-open http://127.0.0.1:8384 >/dev/null 2>&1 ;;
      restart) st_api system/restart -X POST >/dev/null || oops "syncthing is not responding" ;;
    esac
    refresh
  done
}

# ------------------------------------------------------------------- gdrive
gdrive_menu() {
  local c states
  while :; do
    states=$(systemctl --user list-units --all --plain --no-legend 'rclone-mount:@*' \
      | awk '{sub(/^rclone-mount:@/, "", $1); sub(/\.service$/, "", $1); printf "%s %s  ", $1, $3}')
    c=$(pick "gdrive: ${states:-no mounts}" "open in yazi" "restart mounts") || return
    case $c in
      open*) yazi "$HOME/gdrive" ;;
      restart*) systemctl --user restart 'rclone-mount:@*' || oops "restart failed" ;;
    esac
    refresh
  done
}

# Redraw the bar's service icons (home/waybar.nix, signal 10).
refresh() { pkill -RTMIN+10 waybar || true; }

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
    tailscale) tailscale_menu ;;
    syncthing) syncthing_menu ;;
    docker) lazydocker; refresh ;;
    gdrive) gdrive_menu ;;
    *) oops "unknown section: $1"; return 1 ;;
  esac
}

# Launched without a terminal (a waybar click): reopen in the hub window.
if [[ ! -t 0 ]]; then
  exec setsid -f ghostty --class=dev.tushar.hub -e hub "$@"
fi
if [[ $# -gt 0 ]]; then
  run "$1"
  exit
fi
while c=$(pick "hub" wifi bluetooth audio displays brightness nightlight autolock power keys services \
  tailscale syncthing docker gdrive); do
  run "$c"
done
