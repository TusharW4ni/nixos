# media play-pause|next|previous: control the active player, then update one
# self-replacing banner: "<app>  <playing|paused>" / title / artist.
playerctl "$1" || exit 0
sleep 0.2 # let the player publish its new status

idf=${XDG_RUNTIME_DIR:-/tmp}/media-notify-id
id=$(cat "$idf" 2>/dev/null || echo 0)
notify-send -a media -p -r "$id" \
  "$(playerctl metadata --format '{{playerName}}  {{lc(status)}}')" \
  "$(playerctl metadata --format '{{trunc(title, 60)}}
{{artist}}')" > "$idf"
