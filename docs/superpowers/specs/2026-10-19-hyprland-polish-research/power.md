# power
## summary
The physical power button can open a small, all-black, keyboard-only power menu. Systemd's login manager (logind) is told to ignore a short press, and Hyprland catches the key instead. The menu is a tiny script running in a floating Ghostty window: you press l, s, e, r or p (lock, suspend, log out, reboot, power off), and log out, reboot and power off ask y/N first. Holding the button for 5 seconds still powers off cleanly. The script can later be one of the screens in your umbrella TUI. wleave is the alternative if you'd rather have a graphical menu.

The smaller items:
- batsignal: battery warnings at 20% and 10%, suspend at 5%.
- A custom waybar mic module: only appears when the mic is in use or muted, click to mute or unmute.
- waybar's backlight module for brightness.
- A `media` script on the media keys that shows one mako banner with the app, whether it played or paused, and the title.
- hyprsunset for night light, warm from 20:30 to 07:00.
- greetd with tuigreet as the black text login screen.

I checked all of it against your pinned flake with Plasma switched off (in memory only, no repo edits). The whole system evaluates, Hyprland's config checker says "config ok", and the three scripts pass a syntax check. The mic script detected a real recording. Nothing was deployed, so none of it has been tried on the real session.

The biggest thing removing Plasma breaks: it currently brings your Noto and Hack fonts, the password storage that unlocks at login (kwallet), power-profiles-daemon, udisks2 (needed to mount USB drives without sudo), upower and fwupd. Separately, no password-prompt helper (polkit agent) runs under Hyprland today; I checked.
## recommendation
Everything below was evaluated against the pinned flake with Plasma forced off. The full system evaluates (`nix eval` of the system build target), `Hyprland --verify-config` on the generated hyprland.conf prints "config ok", and the scripts pass `bash -n` and shellcheck (one warning, fixed below). Versions in the pinned nixpkgs: hyprsunset 0.4.0, hyprlock 0.9.6, hypridle 0.1.8, hyprpolkitagent 0.1.3, batsignal 1.8.0, playerctl 2.4.1, tuigreet 0.11.1 (the attribute is `pkgs.tuigreet`; `greetd.tuigreet` no longer exists), wleave 0.7.1, gnome-keyring 50.0, waybar 0.15.0, Hyprland 0.56.2.

== 1. SYSTEM: replace modules/desktop/plasma.nix (e.g. modules/desktop/session.nix) ==
Also remove: the plasma-manager flake input, `home/plasma.nix` and its import, and `kdePackages.kate` in home/tushar.nix.
```nix
{ config, pkgs, ... }: {
  # Power key: logind ignores a short press so Hyprland gets XF86PowerOff.
  # A 5 s hold still powers off cleanly if the session hangs.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };

  # Login: greetd + tuigreet on tty1 (the VT background is already #000).
  services.greetd = {
    enable = true;
    useTextGreeter = true; # stops boot messages from drawing over the TUI
    settings.default_session.command = builtins.concatStringsSep " " [
      "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks"
      "--cmd ${config.programs.hyprland.package}/bin/start-hyprland"
      "--theme 'border=darkgray;text=white;prompt=white;time=darkgray;action=darkgray;button=white;container=black;input=white'"
    ];
  };

  # Secrets: replaces kwallet. The NixOS module turns on pam_gnome_keyring
  # for `login`; greetd's PAM stack does `auth substack login` /
  # `session include login` (checked), so the keyring unlocks with your password.
  services.gnome.gnome-keyring.enable = true;
  # Writing this file overrides Hyprland's own portal config, so keep `default`.
  xdg.portal.config.hyprland = {
    default = [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
  };

  # Lock screen PAM service. Without it hyprlock cannot unlock.
  programs.hyprlock.enable = true;

  # Plasma was turning these on implicitly. Keep them.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.udisks2.enable = true;   # lets yazi/udiskie mount USB drives without root
  services.fwupd.enable = true;
}
```
Screen sharing (Teams in Chrome) keeps working without extra config. `programs.hyprland` already installs xdg-desktop-portal-hyprland and the gtk portal. Home-manager's `exec-once` already passes XDG_CURRENT_DESKTOP and WAYLAND_DISPLAY to the systemd user session (checked in the generated config). Chrome captures through PipeWire and the portal by default.

== 2. HOME: add to home/hyprland.nix ==
```nix
let
  # Single-key power menu. With no argument it toggles a floating ghostty.
  powermenu = pkgs.writeShellScriptBin "powermenu" ''
    if [ "$1" != menu ]; then
      pid=$(hyprctl clients -j | jq -r '.[] | select(.class == "tushar.powermenu") | .pid')
      [ -n "$pid" ] && exec kill "$pid"
      exec ghostty --class=tushar.powermenu --background=000000 --font-size=14 \
        --window-padding-x=24 --window-padding-y=16 -e powermenu menu
    fi
    confirm() { printf '\n  %s? [y/N] ' "$1"; read -rsn1 k; [ "$k" = y ]; }
    tput civis
    printf '\n  l  lock\n  s  suspend\n  e  log out\n  r  reboot\n  p  power off\n\n  esc  cancel'
    read -rsn1 key
    case "$key" in
      l) loginctl lock-session ;;
      s) systemctl suspend ;;
      e) confirm "log out" && hyprctl dispatch exit ;;
      r) confirm reboot && systemctl reboot ;;
      p) confirm "power off" && systemctl poweroff ;;
    esac
  '';

  # media play-pause|next|previous, then one mako banner that replaces itself.
  media = pkgs.writeShellScriptBin "media" ''
    playerctl "$1" || exit 0
    sleep 0.2 # give the player time to publish its new status
    id=$XDG_RUNTIME_DIR/media-notify-id
    notify-send -a media -t 2500 -p -r "$(cat "$id" 2>/dev/null || echo 0)" \
      "$(playerctl metadata --format '{{playerName}}  {{lc(status)}}')" \
      "$(playerctl metadata --format '{{trunc(title, 60)}}
{{artist}}')" > "$id"
  '';

  # `mic` prints waybar JSON; `mic toggle` mutes or unmutes the default source.
  mic = pkgs.writeShellScriptBin "mic" ''
    if [ "$1" = toggle ]; then
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      exec pkill -RTMIN+8 waybar
    fi
    apps=$(pw-dump | jq -r '[.[] | .info.props? // {}
      | select(.["media.class"] == "Stream/Input/Audio"
          and ((.["stream.capture.sink"] // false) | tostring) != "true"
          and .["application.id"] != "org.PulseAudio.pavucontrol")
      | .["application.name"] // .["node.name"]] | unique | join(", ")')
    muted=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -o MUTED)
    case "$apps:$muted" in
      :)      text="" class=idle ;;
      :MUTED) text="mic off" class=muted ;;
      *:)     text="● MIC" class=live ;;
      *)      text="MIC muted" class=muted ;;
    esac
    jq -nc --arg t "$text" --arg c "$class" --arg a "$apps" \
      '{text: $t, class: $c, tooltip: (if $a == "" then "mic idle" else "in use: " + $a end)}'
  '';
in {
  home.packages = [ powermenu media mic pkgs.playerctl pkgs.libnotify ]; # notify-send isn't installed today

  services.playerctld.enable = true;      # media keys act on the last-active player
  services.hyprpolkitagent.enable = true; # no polkit agent runs today (checked)

  services.hyprsunset = {                 # night light; the right profile applies at startup
    enable = true;
    settings.profile = [
      { time = "7:00"; identity = true; }
      { time = "20:30"; temperature = 4000; }
    ];
  };

  services.batsignal = {                  # warn at 20 and 10, suspend at 5
    enable = true;
    extraArgs = [ "-w" "20" "-c" "10" "-d" "5" "-D" "systemctl suspend" ];
  };

  # Lock before suspend so menu "l" and "s" (and lid close) end on hyprlock.
  # The auto-lock research owns timeouts; this is the minimum the menu needs.
  services.hypridle = {
    enable = true;
    settings.general = {
      lock_cmd = "pidof hyprlock || hyprlock";
      before_sleep_cmd = "loginctl lock-session";
      after_sleep_cmd = "hyprctl dispatch dpms on";
    };
  };
  programs.hyprlock.enable = true;

  services.mako.settings = {              # pure black banners
    background-color = "#000000"; text-color = "#ffffff"; border-color = "#333333";
    default-timeout = 5000;
    "urgency=critical" = { border-color = "#ff5555"; default-timeout = 0; };
  };

  programs.waybar.settings.mainBar = {
    # add "custom/mic" and "backlight" to modules-right
    "custom/mic" = { exec = "mic"; return-type = "json"; interval = 1; signal = 8; on-click = "mic toggle"; };
    backlight = {
      device = "intel_backlight";       # the only device in /sys/class/backlight
      format = "BRI {percent}%";
      on-scroll-up = "brightnessctl set 5%+";
      on-scroll-down = "brightnessctl set 5%-";
    };
  };
  # waybar CSS: #custom-mic.live { color: #f38ba8; }  #custom-mic.muted { color: #666; }

  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "match:class ^(tushar\\.powermenu)$, float on, center on, size 320 260, pin on, stay_focused on, dim_around on"
    ];
    bind = [
      ", XF86PowerOff, exec, powermenu"   # plain bind, not bindl: a menu behind the lock screen is useless
      "$mod, Escape, exec, powermenu"
    ];
    bindl = [                             # media keys also work while locked
      ", XF86AudioPlay, exec, media play-pause"
      ", XF86AudioPause, exec, media play-pause"
      ", XF86AudioNext, exec, media next"
      ", XF86AudioPrev, exec, media previous"
    ];
  };
}
```
Once this is in, remove `"mako"` from exec-once, because the home-manager mako service already starts it. The existing `$mod SHIFT, M, exit` bind becomes redundant with the menu's "e".

Why these choices:
- **Power menu:** a bash script that reads one key, instead of gum or fzf. It needs no extra package and it is a single keystroke. The same script can be one screen in the umbrella TUI later.
- **Toggling the menu:** it closes by looking up the window's PID with `hyprctl clients`, not with `pkill -f`. Hyprland runs commands through `sh -c`, and that shell's own command line contains the pattern, so `pkill -f` would kill the shell.
- **Mic module:** a custom script, not waybar's `privacy` module. The `privacy` module only draws themed icons and has no click action (waybar 0.15 man page).
- **Battery:** batsignal, not poweralertd. poweralertd only sends notifications and can't run a suspend command; batsignal's `-D` option does. It reads /sys directly, so it doesn't depend on upower.
## alternatives
GUI power menu: wleave 0.7.1 (GTK4, the maintained fork of wlogout). It has a home-manager module, `programs.wleave = { enable; settings.buttons = [{ label; action; keybind; text; }]; style = "window { background: #000; } button { background: #000; color: #fff; border: 1px solid #222; } button:focus { border-color: #fff; }"; }`, and is bound with `", XF86PowerOff, exec, wleave"`. It has single-key shortcuts and Esc to close, but it is a full-screen icon grid with no y/N confirmation. wlogout 1.2.2 has been unmaintained for years.

Launcher dmenu mode: `printf 'lock\nsuspend\nlogout\nreboot\npoweroff' | walker --dmenu` (walker 2.17.1) or `vicinae dmenu` (vicinae 0.29.0). This is worth it only if one of them becomes your launcher in place of wofi. They are slower to start and select by fuzzy search, not by a single key.

Battery: poweralertd 0.3.0 (notifications only, needs upower). Or upower's system-level action: `services.upower = { percentageAction = 5; criticalPowerAction = "Suspend"; allowRiskyCriticalPowerAction = true; }` with no 20/10 warnings. HybridSleep or Hibernate would be safer at 5%, but there is no resume= kernel parameter today, so hibernate isn't set up (a 25.5G swap partition exists).

Media banner: mpris-notifier 0.2.1 sends notifications only on track change, not on play or pause (its README), so it doesn't meet the request. Waybar's `mpris` module can also show the current track in the bar.

Secrets: keep kwallet on its own (`kdePackages.kwallet` + `security.pam.services.login.kwallet = { enable = true; package = pkgs.kdePackages.kwallet-pam; }`, Secret portal routed to "kwallet"). Only do this if you have secrets in ~/.local/share/kwalletd you want to keep.

Night light: services.wlsunset (by time or location) works too, but hyprsunset is the native Hyprland option and screenshots don't capture it.
## risks
Not tested live (nothing was deployed):
- **Ghostty startup.** The power menu, the floating-window rule and the speed of a separate Ghostty start (likely a few hundred ms) were never run in a real session. If it feels slow, use wleave.
- **Repeated power-key events.** I didn't check whether the ASUS power button sends a single XF86PowerOff. There are two "Power Button" input devices (event2, event3), and if both fire, the toggle opens the menu and immediately closes it. Check with `wev`. If it happens, drop the kill branch and use the window rule alone.
- **Login screen.** greetd and tuigreet were checked at evaluation time only. Keep a working boot generation and know how to switch to a TTY (Ctrl+Alt+F2) before the first boot without SDDM.

Secrets (the main unknown):
- Chrome and Slack both have `"os_crypt":{"portal":{"prev_desktop":"Hyprland","prev_init_success":false}}` in their Local State. Their Secret-portal backend currently fails under Hyprland. Chromium's auto-detection treats Hyprland as an "other" desktop and falls back to plain-text storage.
- So removing kwallet should not lose Chrome cookies or the Slack login. Going from plain-text storage to a keyring should also be safe, because the old encryption key is fixed. I believe this but did not test it.
- Whether gnome-keyring's portal works for apps that aren't sandboxed (Chrome has no Flatpak app id) is also unverified. If `prev_init_success` stays false after the change, fall back to `(pkgs.google-chrome.override { commandLineArgs = "--password-store=gnome-libsecret"; })`. One NixOS Discourse user reported even that failing on Hyprland, so expect to possibly sign in again.
- Your password comes from agenix (mutableUsers=false). If it changes, the gnome-keyring login keyring will no longer unlock automatically.
- Anything stored in kwallet (~/.local/share/kwalletd/kdewallet.kwl) is left behind; export it first if it matters. gh is not affected: its token is in ~/.config/gh/hosts.yml.

What disappears with Plasma (comparison of the config with and without it):
- Fonts: noto-fonts and hack-font, plus the default font settings (monospace=Hack, sans=Noto Sans). Everything falls back to DejaVu. The fonts research must add fonts explicitly.
- kwallet, kwallet-pam and ksecretd, which provide org.freedesktop.secrets today.
- Services: power-profiles-daemon, udisks2, upower, fwupd, geoclue2, accounts-daemon.
- Qt integration (`qt.enable`) and the breeze_cursors fallback cursor. GTK and Chrome may show a different cursor; set `home.pointerCursor` if it looks wrong.
- The librsvg loader for SVG images in GTK.
- Password prompts: the ssh-askpass prompt becomes x11-ssh-askpass, and the GPG prompt switches from pinentry-qt to pinentry-gnome3. The GPG one only matters if the gpg agent is enabled.
- `services.xserver.enable` and the xkb layout, which plasma.nix sets itself. Hyprland doesn't need X; XWayland still comes from programs.hyprland.
- No polkit agent runs under Hyprland today (checked with pgrep), so pkexec, blueman and nm prompts already have nothing to show them.

Pitfalls:
- Without `programs.hyprlock.enable` on the NixOS side there is no PAM service for hyprlock and you cannot unlock.
- `loginctl lock-session` does nothing unless hypridle is running with `lock_cmd`.
- The mic module runs pw-dump every second (about 0.1 s each run). Cheap, but not event-driven.
- The mic module hides itself when the mic is idle and unmuted, so you can't mute ahead of time from the bar. Show a dim "mic" instead if you want that.
- I'm not certain playerctl automatically prefers playerctld; if the media keys hit the wrong player, use `playerctl -p playerctld`. Chrome shows up as playerName "chromium".
- Brightness on the HDMI monitor isn't covered (it needs ddcutil).
- In Hyprland 0.55+ the wiki documents Lua and treats hyprlang as deprecated. The `match:class` windowrule syntax used here is from the 0.53+ hyprlang docs and passes `--verify-config` on 0.56.2, but it may need porting if you move to Lua.
- tuigreet now lives at github.com/tuigreet/tuigreet. Theme colors are named ANSI colors; the Linux console renders them coarsely.
## sources
https://wiki.hypr.land/Configuring/Basics/Window-Rules/ (hyprlang version read from hyprwm/hyprland-wiki commit e99eac80^ content/Configuring/Window-Rules.md; match:class, float/center/size/pin/stay_focused/dim_around)
https://wiki.hypr.land/0.54.0/Configuring/Window-Rules/
hyprwm/hyprland-wiki content/Configuring/Binds.md (bindl = works while locked; XF86Audio* playerctl examples)
https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/ (hyprwm/hyprland-wiki content/hypr-ecosystem/user/hyprsunset.md: profiles, identity, applies current profile on startup)
https://github.com/tuigreet/tuigreet (theme components: text,time,container,border,title,greet,prompt,input,action,button)
https://github.com/l1na-forever/mpris-notifier (notifies on track change only)
https://discourse.nixos.org/t/unable-to-use-gnome-keyring-with-chromium-based-browser/62733
https://claudeissues.com/issue/77913-bug-desktop-linux-on-chromeos-crostini-silent-fallback-to-unencrypted-storage-si (Chromium portal backend, prev_init_success, Hyprland -> BASIC_TEXT fallback)
https://chromium.googlesource.com/chromium/src/+/08fbce0a25be93e3ccef86182a5a7e8f08f4be2f/components/os_crypt/key_storage_linux.cc
https://github.com/emersion/mako/blob/master/doc/mako.5.scd
https://man.sr.ht/~kennylevinsen/greetd/
Local: pinned nixpkgs /nix/store/pgp7knjgswsdv1mzgdhx21v8zmdkbisy-source nixos/modules/{system/boot/systemd/logind.nix, services/display-managers/greetd.nix, services/desktop-managers/plasma6.nix, programs/wayland/hyprland.nix, programs/wayland/wayland-session.nix, programs/wayland/hyprlock.nix, services/hardware/upower.nix, services/desktops/gnome/gnome-keyring.nix}
Local: pinned home-manager /nix/store/40h4dglabpdbvbx535xgfz3ifiz49cz6-source modules/services/{hyprsunset,batsignal,poweralertd,hyprpolkitagent,playerctld,gnome-keyring,mako}.nix, modules/programs/{wleave,wlogout,hyprlock}.nix
Local: waybar 0.15.0 man waybar-privacy(5), batsignal -h, tuigreet --help, ghostty +show-config --docs (class), playerctl(1) format functions, Hyprland --verify-config on rendered config
Scratchpad verification files: /tmp/claude-1000/-home-tushar-nixos-config/0cc27cb5-619c-4e21-8713-bf9fd40f9011/scratchpad/{proposal-system.nix,proposal-home.nix,eval.nix,hyprland.conf,diff.nix}