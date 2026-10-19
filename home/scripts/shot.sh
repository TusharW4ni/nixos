# shot region|monitor: screenshot -> ~/ss/pics + clipboard, then a banner.
# Clicking the banner opens satty on that file; nothing opens otherwise.
dir=$HOME/ss/pics
mkdir -p "$dir"
f=$dir/screenshot-$(date +%Y%m%d-%H%M%S).png

case "${1:-}" in
  region)
    geom=$(slurp) || exit 0 # Esc cancels
    grim -g "$geom" "$f"
    ;;
  monitor)
    grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$f"
    ;;
  *) echo "usage: shot region|monitor" >&2; exit 1 ;;
esac

wl-copy --type image/png < "$f"

# Each banner waits on its own file, so clicking an older banner opens that
# older shot. ponytail: one sleeping notify-send per unclicked banner; fine at
# human screenshot rates.
# shellcheck disable=SC2016 # $1 expands in the child shell
setsid -f sh -c '
  if [ "$(notify-send -a screenshot -i "$1" --action=default=Edit --wait "Screenshot copied" "$(basename "$1")")" = default ]; then
    exec satty --filename "$1" --output-filename "$1"
  fi' _ "$f"
