# notif [toggle|clear|dnd|isDnd|count|status]: talk to the notification pane
# (home/quickshell/shell.qml) over Quickshell IPC.
#   toggle  open/close the pane
#   clear   dismiss everything
#   dnd     flip do-not-disturb, prints the new state (use `dnd` to also mute apps)
#   status  waybar JSON: bell + pane count, amber bell-off while DND is on
ipc() { qs -c shell ipc call notifs "$@"; }

case "${1:-toggle}" in
  status)
    n=$(ipc count 2>/dev/null) || { echo '{"text": ""}'; exit 0; }
    dnd=$(ipc isDnd)
    jq -nc --arg n "$n" --arg dnd "$dnd" '
      (if $n == "0" then "" else "  \($n)" end) as $count
      | if $dnd == "true" then
          {text: ("<span font_family=\"lucide\" rise=\"-1600\">&#xe05a;</span>" + $count), class: "dnd", tooltip: "do not disturb · \($n) in the pane"}
        else
          {text: ("<span font_family=\"lucide\" rise=\"-1600\">&#xe059;</span>" + $count), class: (if $n == "0" then "empty" else "some" end), tooltip: "\($n) notifications"}
        end'
    ;;
  toggle|clear|dnd|isDnd|count) ipc "$1" ;;
  *) echo "usage: notif [toggle|clear|dnd|isDnd|count|status]" >&2; exit 1 ;;
esac
