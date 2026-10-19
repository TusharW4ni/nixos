# Home Manager config for the Hyprland session: keybinds, bar, launcher,
# notifications, and the small Wayland tool belt it needs. Imported from
# home/tushar.nix. The system-level enable lives in modules/desktop/hyprland.nix.
{ pkgs, ... }:
let
  # Toggle screen recording. `screenrec region|monitor` starts one; calling it
  # again while wf-recorder runs stops it, and the first call then opens the
  # file in Shotcut. `screenrec status` prints the waybar label (empty = idle).
  screenrec = pkgs.writeShellScriptBin "screenrec" ''
    if pid=$(pgrep -xo wf-recorder); then
      if [ "$1" = status ]; then
        echo "● REC $(ps -o etime= -p "$pid" | tr -d ' ')"
      else
        pkill -INT -x wf-recorder
      fi
      exit 0
    fi
    [ "$1" = status ] && exit 0

    mkdir -p ~/ss/vids
    file=~/ss/vids/recording-$(date +%Y%m%d-%H%M%S).mp4
    case "$1" in
      region) geom=$(slurp) || exit 0 # Esc cancels
              wf-recorder -g "$geom" -f "$file" ;;
      monitor) wf-recorder -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" -f "$file" ;;
      *) echo "usage: screenrec region|monitor|status" >&2; exit 1 ;;
    esac
    exec shotcut "$file"
  '';
in {
  # Wayland tools used by the session / keybinds below. ghostty and
  # wl-clipboard are already in home/tushar.nix, so they're not repeated here.
  home.packages = with pkgs; [
    grim          # screenshot capture
    slurp         # screenshot region select
    satty         # screenshot preview / annotate
    wf-recorder   # screen recording
    shotcut       # video editor opened after a recording (crop, trim, text)
    screenrec     # recording toggle script (above)
    swaybg        # solid-color / image background
    brightnessctl # brightness keys
  ];

  # Screenshots save to ~/ss/pics, recordings to ~/ss/vids. Create both up front so satty can save.
  systemd.user.tmpfiles.rules = [ "d %h/ss/pics - - - -" "d %h/ss/vids - - - -" ];

  # Hyprland window manager config, written in Lua (hyprlang is deprecated
  # and removed in 0.57). The config itself lives in ./hypr/main.lua.
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    extraLuaFiles.main = ./hypr/main.lua;
  };
}
