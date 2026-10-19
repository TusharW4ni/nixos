# dnd [toggle|watch|status]: manual do-not-disturb.
#   toggle  flip mako's dnd mode; mute/unmute Slack and Discord sounds; refresh the bar (signal 8)
#   watch   long-running: mute Slack/Discord streams created while DND is on
#   status  waybar JSON (empty text = module hidden)
# Discord call audio ("WEBRTC VoiceEngine") and the browser are never muted.
apps='^(slack|\.Discord-wrapped)$'

active() { makoctl mode | grep -qx dnd; }

mute_apps() {
  pactl -f json list sink-inputs \
    | jq -r --arg re "$apps" '.[] | .properties as $p
        | select(($p["application.process.binary"] // "" | test($re))
            and $p["application.name"] != "WEBRTC VoiceEngine")
        | .index' \
    | while read -r id; do pactl set-sink-input-mute "$id" "$1"; done
}

case "${1:-toggle}" in
  toggle)
    makoctl mode -t dnd >/dev/null
    if active; then mute_apps 1; else mute_apps 0; fi
    pkill -RTMIN+8 waybar || true
    ;;
  watch)
    pactl subscribe | grep --line-buffered "'new' on sink-input" \
      | while read -r _; do if active; then mute_apps 1; fi; done
    ;;
  status)
    if active; then
      n=$(makoctl list -j | jq length)
      jq -nc --arg n "$n" \
        '{text: "<span font_family=\"lucide\">&#xe05a;</span>  \($n)", class: "on", tooltip: "do not disturb · \($n) hidden"}'
    else
      echo '{"text": ""}'
    fi
    ;;
  *) echo "usage: dnd [toggle|watch|status]" >&2; exit 1 ;;
esac
