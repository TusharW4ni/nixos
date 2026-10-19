# umbrella
## summary
I recommend writing a small `hub` script with gum (about 70 lines of bash) instead of adopting an existing project. Nothing I found is a terminal hub for these settings. Omarchy's menu is a GUI launcher (walker) on Arch. Its only reusable idea is opening each TUI in a floating window with its own class. systemd-manager-tui only manages systemd units, so it becomes one entry in the hub. The hub opens in a floating Ghostty window with app-id `dev.tushar.hub`, held by one Hyprland window rule. From there you pick wifitui, bluetui, wiremix, systemd-manager-tui, or the built-in menus: auto-lock, night light, brightness, battery limit and power. `hub <section>` jumps straight to one menu, so the waybar modules and the power key can open it too.

Nix and runtime changes work together like this. Nix writes `hypridle.conf` with the timeouts as `$lock/$off/$suspend` variables. Next it sources `~/.local/state/hypridle/overrides.conf`, and only then defines the listeners. The hub writes that file and restarts hypridle. I tested this with the pinned hypridle 0.1.8: the override wins, an empty file keeps the Nix defaults, and a missing file logs an error but still runs. Turning auto-lock off is a flag file that a systemd condition checks. Night light changes use hyprsunset's IPC (temporary); the schedule stays in Nix. "Reset" empties the override file, so Nix stays the source of truth.
## recommendation
All of this goes in home/hyprland.nix (or a new home/hub.nix). Versions in the flake's nixpkgs: gum 2.0.2, wifitui 0.13.0, bluetui 0.8.1, wiremix 0.11.0, systemd-manager-tui 1.2.5, hypridle 0.1.8, hyprlock 0.9.6, hyprsunset 0.4.0, Hyprland 0.56.2. NetworkManager is already on, so wifitui works.

```nix
{ pkgs, ... }:
let
  idle = { lock = 300; off = 330; suspend = 1800; };   # Nix defaults; the hub overrides them at runtime
  hub = pkgs.writeShellApplication {
    name = "hub";
    bashOptions = [ "nounset" "pipefail" ];  # no errexit: pressing Esc in a submenu must not close the hub
    runtimeInputs = with pkgs; [ gum wifitui bluetui wiremix brightnessctl systemd-manager-tui ];
    text = ''
      state=''${XDG_STATE_HOME:-$HOME/.local/state}/hypridle
      ovr=$state/overrides.conf
      pick() { gum choose --header "$1" "''${@:2}"; }   # Esc -> non-zero -> caller returns

      # current value: the override file wins, otherwise the Nix default
      cur() { v=$(sed -n "s/^\$$1 = //p" "$ovr" 2>/dev/null | tail -1 || true); echo "''${v:-$2}"; }

      setval() { # $1=var $2=default
        v=$(gum input --header "$1 seconds (Nix default $2)" --value "$(cur "$1" "$2")") || return
        # validate: a non-int makes hypridle DROP that listener (tested) -> no auto-lock
        [[ $v =~ ^[0-9]+$ && $v -ge 30 ]] || { gum log -l error "need integer >= 30"; sleep 1; return; }
        mkdir -p "$state"
        { grep -v "^\$$1 = " "$ovr" 2>/dev/null || true; echo "\$$1 = $v"; } > "$ovr.tmp" && mv "$ovr.tmp" "$ovr"
        systemctl --user restart hypridle
      }

      autolock() {
        while :; do
          [[ -e $state/off ]] && st=OFF || st=ON
          c=$(pick "auto-lock: $st" \
            "lock after   $(cur lock ${toString idle.lock})s" \
            "screen off   $(cur off ${toString idle.off})s" \
            "suspend      $(cur suspend ${toString idle.suspend})s" \
            "toggle on/off" "caffeine 1h" "reset to Nix defaults") || return
          case $c in
            lock*)    setval lock ${toString idle.lock} ;;
            screen*)  setval off ${toString idle.off} ;;
            suspend*) setval suspend ${toString idle.suspend} ;;
            toggle*)  if [[ $st == ON ]]; then mkdir -p "$state"; touch "$state/off"; systemctl --user stop hypridle
                      else rm -f "$state/off"; systemctl --user start hypridle; fi ;;
            caffeine*) setsid -f systemd-inhibit --what=idle --who=hub --why=caffeine sleep 3600 ;;
            reset*)   : > "$ovr"; systemctl --user restart hypridle ;;
          esac
        done
      }

      nightlight() {
        c=$(pick "night light" "warm 4000K" "warmer 3000K" "off (identity)" "back to schedule") || return
        case $c in
          warmer*) hyprctl hyprsunset temperature 3000 ;;
          warm*)   hyprctl hyprsunset temperature 4000 ;;
          off*)    hyprctl hyprsunset identity ;;
          back*)   hyprctl hyprsunset reset ;;
        esac >/dev/null
      }

      power() {
        c=$(pick "power" lock suspend logout reboot shutdown) || return
        case $c in
          lock)     loginctl lock-session ;;
          suspend)  systemctl suspend ;;
          logout)   gum confirm "log out?" && hyprctl dispatch exit ;;
          reboot)   gum confirm "reboot?" && systemctl reboot ;;
          shutdown) gum confirm "shut down?" && systemctl poweroff ;;
        esac
        exit
      }

      battery() {
        f=/sys/class/power_supply/BAT0/charge_control_end_threshold
        c=$(pick "charge limit: $(cat "$f")%" 60 80 100) || return
        echo "$c" | sudo tee "$f" >/dev/null   # lost on reboot; the lasting default is the udev rule below
      }

      run() { case $1 in
        wifi) wifitui ;; bluetooth) bluetui ;; audio) wiremix ;;
        autolock) autolock ;; nightlight) nightlight ;; power) power ;; battery) battery ;;
        brightness) b=$(pick brightness 10% 25% 50% 75% 100%) && brightnessctl -q set "$b" ;;
        services) systemd-manager-tui ;;
      esac; }

      [[ $# -gt 0 ]] && { run "$1"; exit; }   # `hub power` jumps straight to a section
      while c=$(pick "hub" wifi bluetooth audio autolock nightlight brightness battery power services); do run "$c"; done
    '';
  };
  open = s: "ghostty --class=dev.tushar.hub -e hub ${s}";   # GTK app-id needs a dot
in {
  home.packages = [ hub ];

  services.hypridle = {
    enable = true;
    importantPrefixes = [ "$" "source" ];   # emitted in order: $vars, then source, then listener blocks
    settings = {
      "$lock" = idle.lock; "$off" = idle.off; "$suspend" = idle.suspend;
      source = "~/.local/state/hypridle/overrides.conf";   # hypridle's source handler expands ~ (GLOB_TILDE)
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = "$lock";    on-timeout = "loginctl lock-session"; }
        { timeout = "$off";     on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
        { timeout = "$suspend"; on-timeout = "systemctl suspend"; }
      ];
    };
  };
  # The "toggle" item: a flag file keeps hypridle off across logins too
  systemd.user.services.hypridle.Unit.ConditionPathExists = "!%h/.local/state/hypridle/off";
  # Create the override file empty so hypridle doesn't log a "no match" error
  systemd.user.tmpfiles.rules = [ "f %h/.local/state/hypridle/overrides.conf - - - -" ];

  programs.hyprlock.enable = true;   # styling belongs to the black-theme work

  services.hyprsunset = {
    enable = true;
    settings.profile = [
      { time = "7:00";  identity = true; }
      { time = "20:00"; temperature = 4000; }
    ];
  };

  wayland.windowManager.hyprland.settings = {
    # Hyprland 0.53+ named-rule syntax (the old windowrulev2 syntax was replaced)
    windowrule = [{
      name = "hub";
      "match:class" = "^(dev\\.tushar\\.hub)$";
      float = "on"; center = "on"; size = "900 600";
    }];
    bind = [
      "$mod, A, exec, ${open ""}"            # Super+A is free in the current binds
      ", XF86PowerOff, exec, ${open "power"}"
    ];
  };
  # waybar: network.on-click = open "wifi"; bluetooth.on-click = open "bluetooth"; pulseaudio.on-click = open "audio"
  # After that, nm-applet, blueman and pavucontrol can be dropped.
}
```

NixOS side, in a system module:
```nix
services.logind.settings.Login.HandlePowerKey = "ignore";   # let Hyprland receive XF86PowerOff
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="80"
'';
```

How Nix and runtime changes fit together:
- **Nix owns:** the defaults, the listener structure, the commands, the night-light schedule and the battery default.
- **The hub owns:** `~/.local/state/hypridle/{overrides.conf,off}`.
- **What happens on `home-manager switch`:** hypridle restarts through `X-Restart-Triggers` and re-reads the overrides, so runtime choices survive a switch.
- **Reset:** "reset to Nix defaults" empties the override file.

What I verified: running the pinned hypridle with `-c` against a test config, the override changed the lock timeout to 120s while the other listener kept its default. An empty override gave the Nix defaults. A missing file logged `source= globbing error: found no match` and still ran with the defaults. `$lock = abc` dropped that listener, which is why `setval` validates input. The script passes shellcheck with writeShellApplication's options, and an assert-style test of `cur`/`setval` passed under nounset and pipefail.

Left out on purpose:
- **Focus-instead-of-relaunch** (Omarchy's launch-or-focus). Add it if pressing Super+A twice opens two hubs and that bothers you.
- **Persistent night-light overrides.** Add them the same way as hypridle if hyprsunset turns out to accept `source`.
## alternatives
- **Omarchy's approach:** the `omarchy-menu` menu is a GUI launcher (walker), plus `omarchy-launch-or-focus-tui`, which gives each TUI its own app-id `org.omarchy.<name>` and focuses an existing window instead of opening a new one. It is Arch/uwsm specific and its menu is a GUI, but the focus-or-launch idea can be borrowed later in about 5 lines of `hyprctl clients -j | jq`.
- **fzf instead of gum:** works just as well for menus. gum is nicer for number input and yes/no prompts, which the auto-lock menu needs. Neither is installed now.
- **A custom ratatui hub (Rust):** much more code for the same routing. Only worth it if you want live status panels.
- **Let the TUI own `hypridle.conf` entirely** (no HM `settings`): simpler, but loses the declarative defaults and the restart on switch.
- **A wrapper that runs `hypridle -c <generated file>`:** works the same as the `source` + variables approach, with more code.
- **wofi menus** (already installed): GUI pop-ups, which goes against the terminal-only goal.
- **Separate floating window per TUI:** more window rules. One hub window that runs the sub-TUIs inside it and returns to the menu when you quit one is simpler.
## risks
- **Hyprland config format.** Hyprland 0.55+ deprecates hyprlang (`hyprland.conf`) in favour of Lua, and the old format is to be dropped after 1–2 releases. Your 0.56.2 still reads it. When Hyprland drops it, the window rule and binds must be ported (Lua form: `hl.window_rule({ match = { class = ... }, float = true, ... })`). The hub script itself does not change.
- **The anonymous windowrule form** with several effects on one line is not verified. I used the named-block form shown in the 0.54 wiki. I did not run the HM-generated `windowrule { ... }` block through Hyprland 0.56.2; check with `hyprctl configerrors` after switching.
- **`hyprctl dispatch dpms off/on`.** The current (Lua) wiki shows the new style `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`. Omarchy tries the Lua form first and falls back to the legacy form. I have not confirmed that the legacy form still works on 0.56.2 with a hyprlang config. Test it by hand before relying on the dpms listener.
- **`%h` in `ConditionPathExists`.** I believe systemd expands it in user units but did not test it. If it doesn't, the "off" toggle only lasts until the next login.
- **The power key** reaching Hyprland as XF86PowerOff after `HandlePowerKey=ignore` is untested on this ASUS. Check with `wev` or `libinput debug-events`. If logind still handles it, the key will suspend or power off instead.
- **Battery threshold:**
  - The sysfs file is root-owned (checked), so the hub uses `sudo tee`, which asks for your password inside the floating window.
  - Some ASUS firmware resets the threshold after resume. Only an `add` event is covered by the udev rule; it may also need a resume hook or asusd.
- **Caffeine** depends on hypridle respecting systemd idle inhibitors. That is the default (`ignore_systemd_inhibit = false`, per the wiki), but I did not test it live.
- **Night-light IPC changes are temporary:** hyprsunset reverts at the next profile switch (per the wiki). Whether hyprsunset accepts `source` for lasting overrides is unverified.
- **No `errexit` on purpose:** with errexit, pressing Esc in a submenu would close the whole hub. The trade-off is that a failing command doesn't abort.
- **Restarting hypridle** resets its idle timer. That is harmless.
- **gum 2.0.2** is a major-version bump. I checked the `choose`/`input` flags with `--help`; `gum log -l` and `gum confirm` were not run interactively.
## sources
https://wiki.hypr.land/0.54.0/Configuring/Window-Rules/ (hyprlang windowrule syntax: named block and `windowrule = match:class X, effect`)
https://wiki.hypr.land/configuring/core/rules/window-rules/ (current wiki, now Lua `hl.window_rule`)
https://hypr.land/news/26_lua/ and https://linuxiac.com/hyprland-0-55-brings-lua-configs-and-user-defined-layouts/ (hyprlang deprecated in 0.55, dropped after 1-2 releases)
https://github.com/hyprwm/hyprland-wiki/blob/main/content/hypr-ecosystem/user/hypridle.md (listener options, ignore_systemd_inhibit, condition_cmd)
https://github.com/hyprwm/hyprland-wiki/blob/main/content/hypr-ecosystem/user/hyprsunset.md (profiles, `hyprctl hyprsunset temperature|identity|reset` IPC)
https://github.com/hyprwm/hypridle/blob/main/src/config/ConfigManager.cpp (hypridle's own `source` handler, GLOB_TILDE, error on missing file)
https://github.com/hyprwm/hyprlang/blob/main/src/config.cpp (variables can be redefined and are substituted at parse time)
https://github.com/basecamp/omarchy/blob/master/bin/omarchy-launch-or-focus-tui and bin/omarchy-launch-or-focus (per-TUI app-id, focus-or-launch)
https://learn.omacom.io/2/the-omarchy-manual/59/tuis.md (Omarchy TUIs and menu)
home-manager source /nix/store/40h4dglabpdbvbx535xgfz3ifiz49cz6-source/modules/services/hypridle.nix (settings, importantPrefixes, X-Restart-Triggers, systemd unit), modules/services/hyprsunset.nix (settings.profile, transitions deprecated), modules/programs/hyprlock.nix, modules/lib/generators.nix toHyprconf (important fields emitted first, alphabetically)
nixpkgs (flake pin) nixos/modules/system/boot/systemd/logind.nix: services.logind.settings.Login.HandlePowerKey (powerKey renamed)
Ghostty `ghostty +show-config --default --docs`: `class` sets the Wayland app-id and must be a valid GTK application ID
Local tests: pinned hypridle 0.1.8 `-c` run (override applied, empty file = defaults, missing file = error but keeps running, non-int drops the listener); shellcheck-minimal on the hub script; assert check of cur/setval