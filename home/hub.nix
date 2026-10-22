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
  hyprmon = pkgs.writeShellScriptBin "hyprmon" ''
    dir=''${XDG_STATE_HOME:-$HOME/.local/state}/hyprmon
    mkdir -p "$dir"
    export HYPRLAND_CONFIG=$dir/hyprland.lua
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

  # Lock screen: black, the top bar's clock where the bar would be, and
  # "tushar" centred, looping through a matrix-style decode/re-encode.
  # Typing echoes nothing: the password field is a small ring under the name,
  # and hyprlock's hide_input lights a random quarter of it on every
  # keystroke, so it ticks like a spinner while you type and fades out when
  # empty. (Labels can't see keystrokes, so the field is the only thing that
  # can react to typing.)
  programs.hyprlock = {
    enable = true;
    settings =
      let
        white = "rgb(e6e6e6)";
        # 6.5s loop: random glyphs settle into "tushar" left to right (1.2s),
        # hold, scramble back right to left (1.2s), stay scrambled briefly.
        # Unsettled glyphs are grey. Run every 100ms by the label below.
        scramble = pkgs.writeShellScript "hyprlock-scramble" ''
          name=tushar
          glyphs='abcdefghijklmnopqrstuvwxyz0123456789#%*+=?/'
          n=''${#name}
          t=''${EPOCHREALTIME/[.,]/}
          ms=$(( t / 1000 % 6500 ))
          if (( ms < 1200 )); then settled=$(( ms * (n + 1) / 1200 ))
          elif (( ms < 5000 )); then settled=$n
          elif (( ms < 6200 )); then settled=$(( n - (ms - 5000) * (n + 1) / 1200 ))
          else settled=0
          fi
          noise=
          for (( i = settled; i < n; i++ )); do noise+=''${glyphs:RANDOM % ''${#glyphs}:1}; done
          printf '%s<span foreground="#5c5c5c">%s</span>\n' "''${name:0:settled}" "$noise"
        '';
        text = {
          monitor = "";
          font_family = "JetBrains Mono";
          font_size = 14;
        };
      in
      {
        general.hide_cursor = true;
        # Speeds are in 100ms units.
        bezier = [ "out, 0.16, 1, 0.3, 1" ]; # easeOutExpo-ish: quick start, soft landing
        animation = [
          "fadeIn, 1, 4, out"
          "fadeOut, 1, 4, out"
          "inputFieldFade, 1, 3, out"
          "inputFieldColors, 1, 4, out"
        ];
        background = [{ monitor = ""; color = "rgb(000000)"; }];
        label = map (l: text // l) [
          # Same as waybar's custom/clock (home/waybar.nix): format, font,
          # tabular digits, centred in the 34px bar. font_size is in points:
          # 11pt ~ the bar's 15px.
          {
            text = ''cmd[update:1000] date "+<span font_features='tnum'>%a %m/%d · %H:%M:%S</span>"'';
            color = white;
            font_family = "Atkinson Hyperlegible Next";
            font_size = 11;
            position = "0, -8";
            halign = "center";
            valign = "top";
          }
          { text = "cmd[update:100] ${scramble}"; color = white; position = "0, 12"; halign = "center"; valign = "center"; }
          # The field is faded out after a failed attempt (it's empty), so
          # the failure gets its own label.
          { text = ''<span foreground="##ff8080">$FAIL</span>''; color = white; position = "0, -56"; halign = "center"; valign = "center"; }
        ];
        input-field = [{
          monitor = "";
          size = "16, 16";
          position = "0, -24";
          rounding = -1; # a circle
          outline_thickness = 2;
          outer_color = "rgb(1a1a1a)"; # the dim ring
          hide_input = true;
          # Lit quarter colour. Grey has no hue, so the random hue rotation
          # keeps it grey; give it a colour for random-colour ticks.
          hide_input_base_color = "rgb(e6e6e6)";
          check_color = "rgb(5c5c5c)"; # whole ring while PAM checks
          fail_color = "rgb(000000)";
          inner_color = "rgba(00000000)";
          placeholder_text = "";
          fail_text = "";
          fade_on_empty = true;
          fade_timeout = 0;
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
