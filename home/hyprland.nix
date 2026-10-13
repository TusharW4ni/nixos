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
    pavucontrol   # audio GUI (handy while setting things up)
    networkmanagerapplet # nm-applet tray icon + nm-connection-editor GUI
    nwg-displays  # GUI monitor arrangement; writes ~/.config/hypr/monitors.conf
    blueman       # Bluetooth manager GUI, opened from the waybar bluetooth module
  ];

  # Screenshots save to ~/ss/pics, recordings to ~/ss/vids. Create both up front so satty can save.
  systemd.user.tmpfiles.rules = [ "d %h/ss/pics - - - -" "d %h/ss/vids - - - -" ];

  # App launcher (bound to Super+Space below).
  programs.wofi.enable = true;

  # Notification daemon.
  services.mako.enable = true;

  # Status bar.
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "custom/clock" ];
      modules-right = [ "custom/recording" "pulseaudio" "bluetooth" "network" "battery" "tray" ];
      # Custom clock: MM (mon) - DD (ddd) | HH:MM:SS, lowercased.
      # e.g. "10 (oct) - 01 (thu) | 07:11:10". Ticks every second.
      "custom/clock" = {
        exec = "date '+%m (%b) - %d (%a) | %H:%M:%S' | tr '[:upper:]' '[:lower:]'";
        interval = 1;
      };
      # Red "● REC 0:42" while recording, hidden otherwise. Click to stop.
      "custom/recording" = {
        exec = "screenrec status";
        interval = 1;
        on-click = "screenrec";
      };
      battery = {
        format = "BAT {capacity}%";
        format-charging = "CHG {capacity}%";
      };
      network = {
        format-wifi = "{essid} ({signalStrength}%)";
        format-ethernet = "eth";
        format-disconnected = "offline";
        on-click = "nm-connection-editor"; # click the bar label to manage WiFi
      };
      bluetooth = {
        format = "BT {status}";
        format-connected = "BT {device_alias}";
        format-disabled = "BT off";
        on-click = "blueman-manager"; # click the bar label to manage devices
      };
      pulseaudio = {
        format = "VOL {volume}%";
        format-muted = "muted";
        on-click = "pavucontrol";
      };
    };
    style = ''
      * {
        font-family: monospace;
        font-size: 13px;
      }
      window#waybar {
        background: #1e1e2e;
        color: #cdd6f4;
      }
      #workspaces button {
        padding: 0 8px;
        color: #cdd6f4;
      }
      #workspaces button.active {
        background: #313244;
      }
      #custom-recording {
        color: #f38ba8;
      }
      #custom-recording, #clock, #battery, #network, #bluetooth, #pulseaudio, #tray {
        padding: 0 10px;
      }
    '';
  };

  # Hyprland window manager config.
  wayland.windowManager.hyprland = {
    enable = true;

    # Write a classic hyprland.conf (hyprlang). home.stateVersion = "26.05"
    # makes this module default to "lua", which renders our hyprlang-style
    # `settings` into invalid Lua (hl.$mod / hl.exec-once) and Hyprland then
    # rejects the config and falls back to defaults.
    configType = "hyprlang";

    settings = {
      # Auto-detect every monitor at its preferred resolution. Sourced after:
      # nwg-displays (GUI) writes explicit per-output rules there, which
      # override this wildcard for whatever monitor it's been run on.
      monitor = ",preferred,auto,1";
      source = "~/.config/hypr/monitors.conf";

      "$mod" = "SUPER";

      # Start the bar, notification daemon, and a solid background on login.
      exec-once = [
        "waybar"
        "mako"
        "swaybg -c 000000"
        "nm-applet --indicator" # WiFi tray icon (left-click for network menu)
      ];

      env = [ "NIXOS_OZONE_WL,1" ];

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        natural_scroll = false;          # mouse wheel
        touchpad.natural_scroll = false; # touchpad
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
      };

      decoration.rounding = 6;

      bind = [
        # Core
        "$mod, Q, exec, ghostty"
        "$mod, SPACE, exec, wofi --show drun"
        "$mod, C, killactive,"
        "$mod, F, fullscreen,"
        "$mod, V, togglefloating,"
        "$mod SHIFT, M, exit,"

        # Move focus with Super + arrows
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Workspaces 1-9
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        # Move active window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Screenshot region -> satty editor
        ''$mod SHIFT, S, exec, grim -g "$(slurp)" - | satty --filename - --output-filename ~/ss/pics/screenshot-%Y%m%d-%H%M%S.png''
        # Screenshot monitor under the pointer (follow_mouse=1 keeps it focused) -> satty editor
        '', Print, exec, grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" - | satty --filename - --output-filename ~/ss/pics/screenshot-%Y%m%d-%H%M%S.png''
        ''$mod, S, exec, grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" - | satty --filename - --output-filename ~/ss/pics/screenshot-%Y%m%d-%H%M%S.png''

        # Screen recording toggle (press the same key again to stop) -> Shotcut
        "$mod SHIFT, R, exec, screenrec region"
        "$mod, R, exec, screenrec monitor"
      ];

      # Volume / brightness keys (bindel repeats while held).
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Super + drag to move / resize windows.
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
