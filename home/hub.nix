# Settings hub (Super+A) plus the things it controls: auto-lock (hypridle),
# lock screen (hyprlock), night light (hyprsunset), power menu, displays
# (hyprmon) and the keybind cheat sheet. Hyprland binds/rules: ./hypr/hub.lua.
{ pkgs, config, ... }:
let
  # Nix-owned defaults. The hub stores overrides under ~/.local/state.
  idle = { lock = 300; off = 330; suspend = 1800; };
  sunset = { start = "20:30"; end = "07:00"; kelvin = 4000; };

  # hyprmon saves by writing hyprmon.lua next to the config it's given and
  # adding a require() to that config. The real hyprland.lua is a read-only
  # Nix symlink, so give it a writable stub in ~/.local/state/hyprmon; the
  # layout lands in ~/.local/state/hyprmon/hyprmon.lua, which hypr/main.lua loads.
  #
  # hyprmon (0.0.17) applies live changes with `hyprctl keyword monitor ...`,
  # which a Lua-config Hyprland rejects ("keyword can't work with non-legacy
  # parsers"). This hyprctl, first on hyprmon's PATH, turns those calls into
  # `hyprctl eval 'hl.monitor({...})'` and passes everything else through.
  hyprctlLua = pkgs.writeShellScriptBin "hyprctl" ''
    real=/run/current-system/sw/bin/hyprctl
    if [ "''${1:-}" = keyword ] && [ "''${2:-}" = monitor ]; then
      # NAME,disable | NAME,WxH@R,XxY,SCALE[,mirror,SRC]
      IFS=, read -r out mode pos scale flag src <<<"$3"
      if [ "$mode" = disable ]; then
        lua="output = \"$out\", disabled = true"
      else
        lua="output = \"$out\", mode = \"$mode\", position = \"$pos\", scale = $scale"
        [ "$flag" = mirror ] && lua="$lua, mirror = \"$src\""
      fi
      exec "$real" eval "hl.monitor({ $lua })"
    fi
    exec "$real" "$@"
  '';
  hyprmon = pkgs.writeShellScriptBin "hyprmon" ''
    dir=''${XDG_STATE_HOME:-$HOME/.local/state}/hyprmon
    mkdir -p "$dir"
    export HYPRLAND_CONFIG=$dir/hyprland.lua
    export PATH=${hyprctlLua}/bin:$PATH
    exec ${pkgs.hyprmon}/bin/hyprmon "$@"
  '';

  hub = pkgs.writeShellApplication {
    name = "hub";
    bashOptions = [ "nounset" "pipefail" ]; # no errexit: Esc in a submenu must not close the hub
    runtimeInputs = with pkgs; [
      gum fzf jq gnused coreutils util-linux brightnessctl
      wifitui bluetui wiremix systemd-manager-tui hyprmon
      curl tailscale lazydocker wl-clipboard procps ncurses
      gdu duf smartmontools udisks
    ];
    text = ''
      SYNCTHING_CONFIG=${config.home.homeDirectory}/Sync/.config/syncthing/config.xml # dataDir in modules/system/syncthing.nix
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
    ${pkgs.util-linux}/bin/setsid -f ${pkgs.systemd}/bin/systemd-run --user --scope --collect --quiet --slice=app.slice -- ghostty --class=dev.tushar.hub -e hub ${name} >/dev/null 2>&1
  '';
in
{
  home.packages = [ hub hyprmon ] ++ (with pkgs; [ gdu duf smartmontools ]); # disk tools, also in hub > disk

  wayland.windowManager.hyprland.extraLuaFiles.hub = ./hypr/hub.lua;

  # hub > audio: only devices and per-app volume, no level meters, capped at 100%.
  xdg.configFile."wiremix/wiremix.toml".text = ''
    tab = "output"
    tabs = ["output", "playback", "input"]
    peaks = "off"
    max_volume_percent = 100.0
    enforce_max_volume = true
  '';

  vicinaeScripts = {
    hub-wifi = section "wifi" "Wi-Fi";
    hub-bluetooth = section "bluetooth" "Bluetooth";
    hub-audio = section "audio" "Audio Mixer";
    hub-displays = section "displays" "Displays";
    hub-autolock = section "autolock" "Auto-lock Settings";
    hub-nightlight = section "nightlight" "Night Light";
    hub-power = section "power" "Power Menu";
    hub-keys = section "keys" "Keybinds";
    hub-disk = section "disk" "Disk Space and Health";
    hub-drives = section "drives" "Eject Drive";
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
        lock_cmd = "pidof hyprlock || ${config.programs.hyprlock.package}/bin/hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = dpms "enable";
      };
      listener = [
        { 
          timeout = "$lock"; 
          on-timeout = "loginctl lock-session"; 
        }
        # Suspend + screen-off only on battery.
        { 
          timeout = "$off"; 
          on-timeout = "[ \"$(cat /sys/class/power_supply/AC0/online)\" = 1 ] || ${dpms "disable"}"; 
          on-resume = dpms "enable"; 
        }
        { 
          timeout = "$suspend"; 
          on-timeout = "[ \"$(cat /sys/class/power_supply/AC0/online)\" = 1 ] || systemctl suspend"; 
        }
      ];
    };
  };
  # "turn auto-lock off" in the hub. hypridle keeps running (it is also what
  # locks on `loginctl lock-session` and before sleep); instead an idle
  # inhibitor blocks the idle timers while the flag file exists, across logins.
  systemd.user.services.autolock-off = {
    Unit = {
      Description = "Auto-lock disabled (idle inhibitor)";
      ConditionPathExists = "%h/.local/state/hypridle/off";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=hub --why=auto-lock-off ${pkgs.coreutils}/bin/sleep infinity";
    Install.WantedBy = [ "graphical-session.target" ];
  };
  systemd.user.tmpfiles.rules = [
    "d %h/.local/state/hypridle - - - -"
    "f %h/.local/state/hypridle/overrides.conf - - - -"
  ];

  # Lock screen: black, the top bar's clock up top, and a blinking bar in the
  # middle with a * per typed character before it. Enter submits.
  programs.hyprlock = {
    enable = true;
    # hyprlock has no caret; the patch draws one after the dots.
    package = pkgs.hyprlock.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../pkgs/hyprlock-caret.patch ];
    });
    settings =
      let
        white = "rgb(e6e6e6)";
      in
      {
        general.hide_cursor = true;
        animations.enabled = false;
        background = [{ monitor = ""; color = "rgb(000000)"; }];
        label = [
          # Same as waybar's custom/clock (home/waybar.nix): format, font,
          # tabular digits. font_size is in points: 11pt ~ the bar's 15px.
          {
            monitor = "";
            text = ''cmd[update:1000] date "+<span font_features='tnum'>%a %m/%d · %H:%M:%S</span>"'';
            color = white;
            font_family = "Atkinson Hyperlegible Next";
            font_size = 11;
            position = "0, -8";
            halign = "center";
            valign = "top";
          }
        ];
        input-field = [{
          monitor = "";
          size = "600, 40";
          outline_thickness = 0;
          inner_color = "rgba(00000000)";
          font_color = white;
          font_family = "JetBrains Mono";
          dots_text_format = "<b>*</b>";
          dots_size = 0.35;
          dots_rounding = 0; # the default rounds the glyph box, softening it
          dots_spacing = 0.3;
          dots_center = true;
          placeholder_text = "";
          fail_text = ''<span foreground="##ff8080">$FAIL</span>'';
          fade_on_empty = false;
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
