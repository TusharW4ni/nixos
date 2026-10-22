# Pure helpers for the settings hub. No side effects at load time, so
# tests/hub-test.sh can source this file directly.

# valid_seconds <v>: an integer >= 30, at most 6 digits (bash arithmetic
# wraps on overflow). hypridle silently drops a listener whose timeout isn't
# an integer, so bad input must never reach the file.
valid_seconds() { [[ ${1:-} =~ ^[0-9]{1,6}$ ]] && (( 10#$1 >= 30 )); }

# valid_hhmm <v>: 24h HH:MM with a leading zero.
valid_hhmm() { [[ ${1:-} =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; }

# valid_kelvin <v>: an integer in 1000..6500 (4 digits).
valid_kelvin() { [[ ${1:-} =~ ^[0-9]{4}$ ]] && (( 10#$1 >= 1000 && 10#$1 <= 6500 )); }

# kv_get <file> <key> <default>: value of the last "$key = v" line, else default.
kv_get() {
  local v
  v=$(sed -n "s/^\\\$$2 = //p" "$1" 2>/dev/null | tail -n 1)
  echo "${v:-$3}"
}

# kv_set <file> <key> <value>: replace or append "$key = value", keep every
# other line, write atomically.
kv_set() {
  local f=$1 key=$2 val=$3
  mkdir -p "$(dirname "$f")"
  { grep -v "^\\\$$key = " "$f" 2>/dev/null || true; echo "\$$key = $val"; } > "$f.tmp" \
    && mv "$f.tmp" "$f"
}

# sunset_conf <on:0|1> <start HH:MM> <end HH:MM> <kelvin>: a hyprsunset
# config. On: warm from <start>, back to normal at <end>. Off: identity all day.
sunset_conf() {
  if [[ $1 == 1 ]]; then
    printf 'profile {\n    time = %s\n    identity = true\n}\n\nprofile {\n    time = %s\n    temperature = %s\n}\n' "$3" "$2" "$4"
  else
    printf 'profile {\n    time = 00:00\n    identity = true\n}\n'
  fi
}

# mods <modmask>: Hyprland's modifier bitmask as "Super+Ctrl+Alt+Shift"
# (64 Super, 4 Ctrl, 8 Alt, 1 Shift), empty for none.
mods() {
  local m=$1 out=()
  (( m & 64 )) && out+=(Super)
  (( m & 4 )) && out+=(Ctrl)
  (( m & 8 )) && out+=(Alt)
  (( m & 1 )) && out+=(Shift)
  local IFS=+
  echo "${out[*]}"
}
