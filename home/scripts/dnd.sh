# dnd [toggle|watch]: manual do-not-disturb.
#   toggle  flip the pane's DND (banners hidden, notifications still collect);
#           mute/unmute Slack and Discord sounds. The pane refreshes the bar.
#   watch   long-running: mute Slack/Discord streams created while DND is on
# Discord call audio ("WEBRTC VoiceEngine") and the browser are never muted.
apps='^(slack|\.Discord-wrapped)$'

active() { [ "$(notif isDnd)" = true ]; }

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
    if [ "$(notif dnd)" = true ]; then mute_apps 1; else mute_apps 0; fi
    ;;
  watch)
    pactl subscribe | grep --line-buffered "'new' on sink-input" \
      | while read -r _; do if active; then mute_apps 1; fi; done
    ;;
  *) echo "usage: dnd [toggle|watch]" >&2; exit 1 ;;
esac
