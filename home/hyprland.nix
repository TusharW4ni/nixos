# Home Manager config for the Hyprland session: keybinds, bar, launcher,
# notifications, and the small Wayland tool belt it needs. Imported from
# home/tushar.nix. The system-level enable lives in modules/desktop/hyprland.nix.
{ pkgs, ... }: {
  # Wayland tools used by the session / keybinds below. ghostty and
  # wl-clipboard are already in home/tushar.nix, so they're not repeated here.
  home.packages = with pkgs; [
    grim          # screenshot capture
    slurp         # screenshot region select
    swaybg        # solid-color / image background
    brightnessctl # brightness keys
    pavucontrol   # audio GUI (handy while setting things up)
  ];

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
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "battery" "tray" ];
      clock.format = "{:%a %d %b  %H:%M}";
      battery = {
        format = "BAT {capacity}%";
        format-charging = "CHG {capacity}%";
      };
      network = {
        format-wifi = "{essid} ({signalStrength}%)";
        format-ethernet = "eth";
        format-disconnected = "offline";
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
      #clock, #battery, #network, #pulseaudio, #tray {
        padding: 0 10px;
      }
    '';
  };

  # Hyprland window manager config.
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Auto-detect every monitor at its preferred resolution.
      monitor = ",preferred,auto,1";

      "$mod" = "SUPER";

      # Start the bar, notification daemon, and a solid background on login.
      exec-once = [
        "waybar"
        "mako"
        "swaybg -c 1e1e2e"
      ];

      env = [ "NIXOS_OZONE_WL,1" ];

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
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

        # Screenshot region -> clipboard
        ''$mod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
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
