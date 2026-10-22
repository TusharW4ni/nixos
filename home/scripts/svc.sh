# svc <tailscale|syncthing|docker|gdrive>: print waybar JSON for one
# background service. Class "up" (dim), "down" (red) or, for syncthing,
# "syncing" (amber). Clicking opens the
# matching hub section; the hub refreshes these modules with signal 10.

icon() { printf "<span font_family='lucide'>&#x%s;</span>" "$1"; }
up() { systemctl is-active --quiet "$1"; }

case ${1:-} in
  tailscale)
    cp=e542 # waypoints
    st=$(tailscale status --json 2>/dev/null) || st='{}'
    state=$(jq -r '.BackendState // "stopped"' <<<"$st")
    if [ "$state" = Running ]; then
      class=up
      tip=$(jq -r '"tailscale · \(.TailscaleIPs[0]) · \([.Peer[]? | select(.Online)] | length) peers online"' <<<"$st")
    else
      class=down tip="tailscale: ${state,,}"
    fi ;;
  syncthing)
    cp=e4c9 # folder-sync
    if ! up syncthing; then
      class=down tip="syncthing stopped"
    else
      # Folders still pulling changes in, via the local REST API.
      key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$SYNCTHING_CONFIG" 2>/dev/null)
      api() { curl -sf -m 2 -H "X-API-Key: $key" "http://127.0.0.1:8384/rest/$1"; }
      folders=$(api config/folders) || folders=
      busy=$(jq -r '.[] | "\(.id)\t\(if .label == "" then .id else .label end)"' <<<"${folders:-[]}" \
        | while IFS=$'\t' read -r id label; do
            api "db/status?folder=$id" | jq -r --arg l "$label" \
              'select(.state == "syncing" or .state == "sync-preparing" or .needFiles > 0)
               | "\($l): \(.needFiles) files left"'
          done)
      if [ -z "$folders" ]; then
        class=up tip="syncthing running (API unreachable)"
      elif [ -n "$busy" ]; then
        class=syncing tip=$(printf 'syncthing · syncing\n%s' "$busy")
      else
        class=up tip="syncthing · up to date"
      fi
    fi ;;
  docker)
    cp=e4d5 # container
    if up docker; then
      class=up tip="docker · $(docker ps -q | wc -l) containers running"
    else
      class=down tip="docker stopped"
    fi ;;
  gdrive)
    cp=e088 # cloud
    # One rclone-mount:@<remote> user unit per Drive account.
    states=$(systemctl --user list-units --all --plain --no-legend 'rclone-mount:@*' \
      | awk '{sub(/^rclone-mount:@/, "", $1); sub(/\.service$/, "", $1); print $1 " " $3}')
    if [ -n "$states" ] && ! grep -qv ' active$' <<<"$states"; then class=up; else class=down; fi
    tip=$(printf 'gdrive\n%s' "${states:-no mounts}") ;;
  *) echo "usage: svc tailscale|syncthing|docker|gdrive" >&2; exit 1 ;;
esac

jq -nc --arg t "$(icon "$cp")" --arg c "$class" --arg tip "$tip" \
  '{text: $t, class: $c, alt: $c, tooltip: $tip}'
