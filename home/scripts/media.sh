# media play-pause|next|previous: control the active player, then update one
# self-replacing banner: "<app>  <playing|paused>" / title / artist.
playerctl "$1" || exit 0
sleep 0.2 # let the player publish its new status

meta() { playerctl metadata --format "$1"; }
# mako renders Pango markup, so titles like "Tom & Jerry" must be escaped.
esc() { local s=${1//\&/"&amp;"}; s=${s//</"&lt;"}; s=${s//>/"&gt;"}; printf '%s' "$s"; }

summary=$(esc "$(meta '{{playerName}}  {{lc(status)}}')")
body="$(esc "$(meta '{{trunc(title, 60)}}')")
$(esc "$(meta '{{artist}}')")"

idf=${XDG_RUNTIME_DIR:-/tmp}/media-notify-id
id=$(cat "$idf" 2>/dev/null || true)
[[ $id =~ ^[0-9]+$ ]] || id=0
# Only replace the saved id on success, so one failed notify-send (e.g. while
# mako restarts) can't leave an empty id that breaks every later -r.
if new=$(notify-send -a media -p -r "$id" "$summary" "$body") && [[ $new =~ ^[0-9]+$ ]]; then
  echo "$new" > "$idf"
fi
