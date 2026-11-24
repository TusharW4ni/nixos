# audio-out: make the next audio output (sink) the default and show a banner.
# WirePlumber moves playing streams along with the default.
# Exists because the Dell D6000 dock's headphone jack sensor always reads
# "plugged in", so nothing can switch outputs on its own when headphones come out.
sinks=$(pw-dump | jq -c '[.[] | select(.info.props["media.class"]? == "Audio/Sink")
  | {id, name: .info.props["node.name"], desc: (.info.props["node.description"] // .info.props["node.name"])}]
  | sort_by(.id)')
cur=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | sed -n 's/.*node\.name = "\(.*\)"/\1/p' | head -1)

# Sink after the current one, wrapping around. Unknown current: first sink.
next=$(jq -c --arg cur "$cur" '
  (map(.name) | index($cur)) as $i
  | if length == 0 then empty elif $i == null then .[0] else .[($i + 1) % length] end' <<<"$sinks")
[ -n "$next" ] || exit 0

wpctl set-default "$(jq -r .id <<<"$next")"

idf=${XDG_RUNTIME_DIR:-/tmp}/audio-out-notify-id
id=$(cat "$idf" 2>/dev/null || true)
[[ $id =~ ^[0-9]+$ ]] || id=0
if new=$(notify-send -a audio -p -r "$id" "Audio output" "$(jq -r .desc <<<"$next")") && [[ $new =~ ^[0-9]+$ ]]; then
  echo "$new" > "$idf"
fi
