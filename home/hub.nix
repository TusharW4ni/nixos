# Settings hub (Super+A) plus the things it controls: auto-lock (hypridle),
# lock screen (hyprlock), night light (hyprsunset), power menu, displays
# (hyprmon) and the keybind cheat sheet. Hyprland binds/rules: ./hypr/hub.lua.
{ pkgs, config, ... }:
let
  # Nix-owned defaults. The hub stores overrides under ~/.local/state.
  idle = { lock = 300; off = 330; suspend = 1800; };
  sunset = { start = "20:30"; end = "07:00"; kelvin = 4000; };

  # hyprmon writes the monitor layout to ~/.config/hypr/hyprmon.lua, which
  # hypr/main.lua loads.
  hyprmon = pkgs.writeShellScriptBin "hyprmon" ''
    export HYPRLAND_CONFIG=$HOME/.config/hypr/hyprland.lua
    exec ${pkgs.hyprmon}/bin/hyprmon "$@"
  '';

  hub = pkgs.writeShellApplication {
    name = "hub";
    bashOptions = [ "nounset" "pipefail" ]; # no errexit: Esc in a submenu must not close the hub
    runtimeInputs = with pkgs; [
      gum fzf jq gnused coreutils util-linux brightnessctl
      wifitui bluetui wiremix systemd-manager-tui hyprmon
    ];
    text = ''
      IDLE_LOCK=${toString idle.lock}
      IDLE_OFF=${toString idle.off}
      IDLE_SUSPEND=${toString idle.suspend}
      SUNSET_START=${sunset.start}
      SUNSET_END=${sunset.end}
      SUNSET_KELVIN=${toString sunset.kelvin}
    '' + builtins.readFile ./hub/lib.sh + builtins.readFile ./hub/hub.sh;
  };

  # Default night light config, used until the hub saves its own.
  sunsetDefaults = pkgs.writeTextDir "hypr/hyprsunset.conf" ''
    profile {
        time = ${sunset.end}
        identity = true
    }

    profile {
        time = ${sunset.start}
        temperature = ${toString sunset.kelvin}
    }
  '';

  dpms = action: ''hyprctl dispatch 'hl.dsp.dpms({ action = "${action}" })' '';

  # Vicinae entries that open hub sections.
  section = name: title: ''
    #!${pkgs.bash}/bin/bash
    # @vicinae.schemaVersion 1
    # @vicinae.title ${title}
    # @vicinae.mode silent
    # @vicinae.keywords ["hub", "settings", "${name}"]
    ${pkgs.util-linux}/bin/setsid -f ghostty --class=dev.tushar.hub -e hub ${name} >/dev/null 2>&1
  '';
in
{
  home.packages = [ hub hyprmon ];

  wayland.windowManager.hyprland.extraLuaFiles.hub = ./hypr/hub.lua;

  vicinaeScripts = {
    hub-wifi = section "wifi" "Wi-Fi";
    hub-bluetooth = section "bluetooth" "Bluetooth";
    hub-audio = section "audio" "Audio Mixer";
    hub-displays = section "displays" "Displays";
    hub-autolock = section "autolock" "Auto-lock Settings";
    hub-nightlight = section "nightlight" "Night Light";
    hub-power = section "power" "Power Menu";
    hub-keys = section "keys" "Keybinds";
  };

  # Auto-lock. Timeouts are variables so the hub's override file (sourced
  # after them) can redefine them.
  services.hypridle = {
    enable = true;
    importantPrefixes = [ "$" "source" ];
    settings = {
      "$lock" = idle.lock;
      "$off" = idle.off;
      "$suspend" = idle.suspend;
      source = "${config.xdg.stateHome}/hypridle/overrides.conf";
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = dpms "enable";
      };
      listener = [
        { timeout = "$lock"; on-timeout = "loginctl lock-session"; }
        { timeout = "$off"; on-timeout = dpms "disable"; on-resume = dpms "enable"; }
        # Suspend only on battery.
        { timeout = "$suspend"; on-timeout = "[ \"$(cat /sys/class/power_supply/AC0/online)\" = 1 ] || systemctl suspend"; }
      ];
    };
  };
  # "turn auto-lock off" in the hub: a flag file keeps hypridle off across logins.
  systemd.user.services.hypridle.Unit.ConditionPathExists = "!%h/.local/state/hypridle/off";
  systemd.user.tmpfiles.rules = [
    "d %h/.local/state/hypridle - - - -"
    "f %h/.local/state/hypridle/overrides.conf - - - -"
  ];

  # Lock screen, styled like the tuigreet login: black, monospace, the date
  # on top, an 80-column box with a thin grey border holding bold
  # "Username:" / "Password:" rows, and a key-hint bar bottom-left.
  programs.hyprlock = {
    enable = true;
    settings =
      let
        mono = "JetBrains Mono";
        size = 14;
        cw = 0.6 * size; # JetBrains Mono advance: 600/1000 em
        grey = "rgb(5c5c5c)";
        white = "rgb(e6e6e6)";
        box = { w = 80 * cw; h = 6 * size * 1.4; };
        left = -box.w / 2 + 2 * cw; # text starts two cells in from the border
        px = n: toString (builtins.floor n);
        # A row of `chars` visible characters whose left edge is at `left`.
        row = markup: chars: y: {
          monitor = "";
          text = markup;
          color = white;
          font_size = size;
          font_family = mono;
          position = "${px (left + chars * cw / 2)}, ${toString y}";
          halign = "center";
          valign = "center";
        };
        key = k: "<span background='#e6e6e6' foreground='#000000'>${k}</span>";
      in
      {
        general.hide_cursor = true;
        background = [{ monitor = ""; color = "rgb(000000)"; }];
        shape = [{
          monitor = "";
          size = "${px box.w}, ${px box.h}";
          color = "rgb(000000)";
          rounding = 0;
          border_size = 1;
          border_color = grey;
          zindex = -1; # under the text
          position = "0, 0";
          halign = "center";
          valign = "center";
        }];
        label = [
          {
            monitor = "";
            text = ''cmd[update:1000] date '+%a, %d %b %Y - %H:%M' '';
            color = grey;
            font_size = size;
            font_family = mono;
            position = "0, -16";
            halign = "center";
            valign = "top";
          }
          (row "<b>Username:</b> tushar" 16 12)
          (row "<b>Password:</b>" 9 (-12))
          {
            monitor = "";
            text = "${key "ESC"} Clear ${key "ENTER"} Unlock";
            color = grey;
            font_size = size;
            font_family = mono;
            position = "12, 10";
            halign = "left";
            valign = "bottom";
          }
        ];
        input-field = [{
          monitor = "";
          size = "${px (40 * cw)}, ${px (size * 1.6)}";
          outline_thickness = 0;
          rounding = 0;
          inner_color = "rgb(000000)";
          font_color = white;
          check_color = "rgb(000000)";
          fail_color = "rgb(000000)";
          font_family = mono;
          dots_text_format = "*";
          dots_size = 0.5;
          dots_spacing = 0.1;
          dots_center = false;
          placeholder_text = "";
          fail_text = ''<span foreground="##ff8080">wrong password</span>'';
          fade_on_empty = false;
          # Starts right after "Password: " (10 cells); 40 cells wide.
          position = "${px (left + 10 * cw + 20 * cw)}, -12";
          halign = "center";
          valign = "center";
        }];
      };
  };

  # Night light. hyprsunset 0.4 only reads $XDG_CONFIG_HOME/hypr/hyprsunset.conf,
  # so point that at the hub's saved config if there is one, else the defaults.
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Night light (hyprsunset)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "hyprsunset-start" ''
        saved=''${XDG_STATE_HOME:-$HOME/.local/state}/hyprsunset
        if [ -f "$saved/hypr/hyprsunset.conf" ]; then
          export XDG_CONFIG_HOME=$saved
        else
          export XDG_CONFIG_HOME=${sunsetDefaults}
        fi
        exec ${pkgs.hyprsunset}/bin/hyprsunset
      ''}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
