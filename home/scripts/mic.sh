# mic: print waybar JSON for the default microphone.
# `mic toggle` mutes/unmutes it and refreshes the bar (signal 9).
if [ "${1:-}" = toggle ]; then
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
  pkill -RTMIN+9 waybar || true
  exit 0
fi

icon() { printf "<span font_family='lucide'>&#x%s;</span>" "$1"; }

# Apps currently capturing audio. Monitor streams and level meters from the
# mixer TUI don't count as "using the mic".
apps=$(pw-dump | jq -r '[.[] | .info.props? // {}
  | select(.["media.class"] == "Stream/Input/Audio"
      and ((.["stream.capture.sink"] // false) | tostring) != "true"
      and ((.["application.name"] // "") | test("^(wiremix|pavucontrol)$"; "i") | not))
  | .["application.name"] // .["node.name"]] | unique | join(", ")')

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
  class=muted cp=e119 tip="muted${apps:+ · in use: $apps}"
elif [ -n "$apps" ]; then
  class=live cp=e118 tip="in use: $apps"
else
  class=idle cp=e118 tip="mic idle"
fi

jq -nc --arg t "$(icon "$cp")" --arg c "$class" --arg tip "$tip" \
  '{text: $t, class: $c, alt: $c, tooltip: $tip}'
