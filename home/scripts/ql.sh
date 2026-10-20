# ql <file>: macOS-style quick look, full screen. Space or q closes it.
case "$(file -Lb --mime-type "$1")" in
  image/*) exec imv -f "$1" ;;
  application/pdf) exec zathura --mode=fullscreen "$1" ;;
  video/* | audio/*) exec mpv --fs "$1" ;;
  *) exit 0 ;;
esac
