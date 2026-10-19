# theming
## summary
All six parts work with stock tools. One palette, Vesper on a #000 background, now covers herdr, Ghostty, yazi, waybar and mako. Vesper is mostly greys with a peach accent (#ffc799). herdr has Vesper built in, and Ghostty ships a "Vesper" theme.

- **herdr 0.9.0:** use `[theme] name = "vesper"` and set `[theme.custom]` panel_bg, sidebar_bg and surface_dim to #000000. `herdr config check` passed this against the installed binary.
- **Ghostty:** manage it with `programs.ghostty` (current config.ghostty is empty). The Ghostty config passed `+validate-config`.
- **mako:** the config parses on mako 1.11. `ignore-timeout=1` is needed so apps can't set their own timeout. A `dnd` mode hides popups, and the hidden notifications show again when DND turns off.
- **Discord/Slack muting:** one `dnd` script toggles mako DND and mutes only Slack and Discord streams. It leaves Chrome and Discord call audio alone. It also needs a WirePlumber rule so the mute isn't remembered after DND ends. The script passes shellcheck and its stream filter was tested.
- **yazi:** image previews work in Ghostty and inside herdr. Space opens a full-screen quick look and selection moves to `i`.
- **waybar:** black bar with thin line icons from the Lucide font, plus a clickable DND bell.

Main risk: once Plasma is removed, Ghostty/herdr may tell TUIs the theme is light, and yazi would then use its light theme. Setting `window-theme = dark` in Ghostty should prevent this, but it's untested.
## recommendation
Palette (use it everywhere): bg #000000, raised #121212/#1c1c1c, border #262626/#333333, dim #5c5c5c, muted text #a0a0a0, text #e6e6e6, accent #ffc799, mint #99ffe4, red #ff8080.

## 1. herdr — home/herdr.toml (passed `herdr config check` on the installed v0.9.0)
Theme fields come from src/config/theme.rs: accent, panel_bg, sidebar_bg, active_row_bg, selection_bg, surface0, surface1, surface_dim, overlay0, overlay1, text, subtext0, mauve, green, yellow, red, blue, teal, peach. Panes fall back to the terminal's own background, so they are already black.
```toml
onboarding = false
[keys]
split_vertical = "prefix+|"
split_horizontal = "prefix+minus"
[ui]
status_indicators = "symbols"
copy_on_select = true
[ui.toast]
delivery = "system"
[terminal]
kitty_graphics = true        # already the default in 0.9.0; written out so it's visible
[theme]
name = "vesper"
auto_switch = false
[theme.custom]
panel_bg      = "#000000"
sidebar_bg    = "#000000"
surface_dim   = "#000000"
active_row_bg = "#121212"
selection_bg  = "#1c1c1c"
surface0      = "#1c1c1c"
surface1      = "#2a2a2a"
```
Instead of Vesper you could use `name = "terminal"`, which takes every colour from Ghostty's palette. To check a change: `HERDR_CONFIG_PATH=./home/herdr.toml herdr config check`. To apply it: `herdr server reload-config`.

## 2. Ghostty — home/tushar.nix
Remove `ghostty` from home.packages (this module installs it). Delete the empty ~/.config/ghostty/config.ghostty, since home-manager writes ~/.config/ghostty/config. Fonts are left to the font research.
```nix
programs.ghostty = {
  enable = true;   # systemd.enable defaults to true on Linux
  settings = {
    theme = "Vesper";                 # built-in; the keys below override it
    background = "#000000";
    foreground = "#e6e6e6";
    selection-background = "#262626";
    selection-foreground = "#ffffff";
    cursor-color = "#ffc799";
    cursor-text = "#000000";
    cursor-style-blink = false;
    window-theme = "dark";            # so TUIs/herdr are told "dark" once Plasma's portal is gone
    window-decoration = "none";
    window-padding-x = 8;
    window-padding-y = 6;
    window-padding-balance = true;
    window-padding-color = "background";
    confirm-close-surface = false;
  };
};
```

## 3. mako — replaces `services.mako.enable = true;` in home/hyprland.nix
This config parses on mako 1.11. Sections are written in alphabetical order, which happens to be the order needed.
```nix
services.mako = {
  enable = true;
  settings = {
    font = "monospace 11";            # swap in the chosen UI font
    background-color = "#000000";
    text-color = "#e6e6e6";
    border-color = "#333333";
    border-size = 1;
    border-radius = 0;
    padding = "10,14";
    margin = 8;
    width = 380;
    layer = "overlay";
    default-timeout = 0;              # never auto-dismiss
    ignore-timeout = 1;               # stop apps from sending their own timeout
    history = 1;
    max-history = 100;
    "mode=dnd" = { invisible = 1; on-notify = "exec pkill -RTMIN+8 waybar"; };
    "mode=dnd urgency=critical" = { invisible = 0; };   # critical alerts still show
    "urgency=critical" = { border-color = "#ff8080"; };
  };
};
```
- **During DND:** notifications stay in `makoctl list` but are hidden. Turning DND off shows them all again, so nothing is missed.
- **Dismissed notifications:** `makoctl history -j` lists them and `makoctl restore` brings back the last one. Suggested key: `"$mod, N, exec, makoctl restore"`. Plus `"$mod SHIFT, N, exec, makoctl dismiss -a"` to clear everything.

## 4. DND toggle that also mutes Slack and Discord (passes shellcheck; the stream filter was tested)
Measured on this machine:
- Slack plays through the process `slack` with name "Slack".
- Discord plays through `.Discord-wrapped`: "Chromium" for notification sounds and "WEBRTC VoiceEngine" for calls.
- Chrome is `chrome`.

The script matches on process name and skips Discord's call audio. Add it to the `let` block in hyprland.nix:
```nix
dnd = pkgs.writeShellApplication {
  name = "dnd";
  runtimeInputs = with pkgs; [ mako jq pulseaudio procps gnugrep ];
  text = ''
    apps='^(slack|\.Discord-wrapped)$'
    active() { makoctl mode | grep -qx dnd; }
    mute_apps() {
      pactl -f json list sink-inputs \
        | jq -r --arg re "$apps" '.[] | .properties as $p | select(($p["application.process.binary"] // "" | test($re)) and $p["application.name"] != "WEBRTC VoiceEngine") | .index' \
        | while read -r id; do pactl set-sink-input-mute "$id" "$1"; done
    }
    case "''${1:-toggle}" in
      toggle) makoctl mode -t dnd >/dev/null
              if active; then mute_apps 1; else mute_apps 0; fi
              pkill -RTMIN+8 waybar || true ;;
      watch)  pactl subscribe | grep --line-buffered "'new' on sink-input" \
                | while read -r _; do if active; then mute_apps 1; fi; done ;;
      status) n=$(makoctl list -j | jq length)
              if active; then
                jq -nc --arg n "$n" '{text: "<span font_family=\"lucide\">&#xe05a;</span> \($n)", class: "on", tooltip: "do not disturb: \($n) waiting"}'
              else
                jq -nc '{text: "<span font_family=\"lucide\">&#xe059;</span>", class: "off", tooltip: "notifications on"}'
              fi ;;
      *) echo "usage: dnd [toggle|watch|status]" >&2; exit 1 ;;
    esac
  '';
};
```
Wiring:
- Add `dnd` to home.packages.
- Add `"dnd watch"` to exec-once.
- Bind `"$mod, D, exec, dnd"`.

Also required, in modules/system/audio.nix. Without it, WirePlumber saves the mute under the stream name. Slack would then stay muted after DND ends. Discord's "Chromium" mute would also carry over to Steam.
```nix
services.pipewire.wireplumber.extraConfig."90-dnd-apps" = {
  "stream.rules" = [{
    matches = [ { "application.process.binary" = "slack"; } { "application.process.binary" = ".Discord-wrapped"; } ];
    actions.update-props."state.restore-props" = false;
  }];
};
```

## 5. yazi + quick look
The nixpkgs yazi package (26.9.1) already bundles poppler-utils, ffmpeg-headless, imagemagick, resvg, chafa, 7zz, fd, rg, fzf, zoxide and jq. No extraPackages are needed for PDF, video or image previews.
```nix
ql = pkgs.writeShellApplication {   # passes shellcheck
  name = "ql";
  runtimeInputs = with pkgs; [ file imv zathura mpv ];
  text = ''
    case "$(file -Lb --mime-type "$1")" in
      image/*)         exec imv -f "$1" ;;
      application/pdf) exec zathura --mode=fullscreen "$1" ;;
      video/*|audio/*) exec mpv --fs "$1" ;;
    esac
  '';
};
programs.yazi = {
  enable = true;      # with stateVersion 26.05 the shell wrapper is `y`
  settings.mgr = { show_hidden = true; sort_dir_first = true; };
  settings.preview = { max_width = 1920; max_height = 1200; };   # default is 600x900; larger looks sharper
  keymap.mgr.prepend_keymap = [
    { on = "<Space>"; run = "shell --orphan -- ql %h"; desc = "Quick look (full screen)"; }
    { on = "i"; run = [ "toggle" "arrow 1" ]; desc = "Toggle selection"; }   # v still does range select
  ];
  theme = {
    app.overall = { bg = "#000000"; };
    mgr = { cwd = { fg = "#ffc799"; }; border_style = { fg = "#262626"; }; };
    indicator = { current = { bg = "#1c1c1c"; bold = true; }; parent = { bg = "#121212"; }; };
    tabs = { active = { fg = "#000000"; bg = "#ffc799"; bold = true; }; inactive = { fg = "#7e7e7e"; bg = "#121212"; }; };
    mode = {
      normal_main = { fg = "#000000"; bg = "#ffc799"; bold = true; }; normal_alt = { fg = "#ffc799"; bg = "#121212"; };
      select_main = { fg = "#000000"; bg = "#99ffe4"; bold = true; }; select_alt = { fg = "#99ffe4"; bg = "#121212"; };
      unset_main  = { fg = "#000000"; bg = "#ff8080"; bold = true; }; unset_alt  = { fg = "#ff8080"; bg = "#121212"; };
    };
    status.progress_normal = { fg = "#ffc799"; bg = "#121212"; };
    which.border = { fg = "#262626"; };
  };
};
programs.imv = { enable = true; settings.options.background = "000000"; settings.binds."<space>" = "quit"; };
programs.zathura = { enable = true; options = {
  default-bg = "#000000"; statusbar-bg = "#000000"; inputbar-bg = "#000000"; completion-bg = "#000000";
  recolor = true; recolor-keephue = true; recolor-lightcolor = "#000000"; recolor-darkcolor = "#e6e6e6"; }; };   # Ctrl+R switches recolouring off
programs.mpv.enable = true;   # then remove mpv from home.packages
```
Add `ql` to home.packages. Pressing `q` closes every viewer, and Space also closes imv, like macOS Quick Look.

**Images inside herdr:** inside a herdr pane TERM_PROGRAM is still ghostty and GHOSTTY_RESOURCES_DIR is set (checked live). yazi therefore uses kitty graphics with Unicode placeholders, which herdr handles (its source has a "Yazi-style virtual placement" test). Images in plain Ghostty work as is.

## 6. waybar — pure black with Lucide line icons
Install the font at system level with `fonts.packages = [ pkgs.lucide ];` (version 0.563.0; codepoints below were read from that exact font).

Lucide must never be the first font-family: it also maps a–z and 0–9 to icons. Wrap each icon in a span instead. In hyprland.nix `let`: `ic = cp: "<span font_family='lucide'>&#x${cp};</span>";`
```nix
modules-right = [ "custom/recording" "custom/dnd" "pulseaudio" "bluetooth" "network" "battery" "tray" ];
"custom/dnd" = { exec = "dnd status"; return-type = "json"; interval = "once"; signal = 8; on-click = "dnd"; };
pulseaudio = { format = "${ic "e1ab"}  {volume}%"; format-muted = ic "e1ac"; on-click = "pavucontrol"; };
bluetooth  = { format = ic "e05c"; format-connected = "${ic "e1b8"}  {device_alias}"; format-disabled = ic "e1b9"; format-off = ic "e1b9"; on-click = "blueman-manager"; };
network    = { format-wifi = "${ic "e1ae"}  {essid}"; format-ethernet = ic "e620"; format-disconnected = ic "e1af"; tooltip-format-wifi = "{essid} {signalStrength}%"; on-click = "nm-connection-editor"; };
battery    = { states = { warning = 20; critical = 10; }; format = "{icon}  {capacity}%"; format-charging = "${ic "e054"}  {capacity}%";
               format-icons = [ (ic "e056") (ic "e057") (ic "e055") ]; };
# other codepoints: mic e118, mic-off e119, sun e178, sun-dim e299, moon e11e, bell-dot e42b, circle-dot e345
```
```css
* { font-family: monospace; font-size: 13px; border: none; border-radius: 0; min-height: 0; box-shadow: none; }
window#waybar { background: #000000; color: #a0a0a0; border-bottom: 1px solid #1c1c1c; }
tooltip { background: #000000; border: 1px solid #333333; }
tooltip label { color: #e6e6e6; }
#workspaces button { padding: 0 8px; color: #5c5c5c; background: transparent; }
#workspaces button:hover { background: #121212; color: #e6e6e6; }
#workspaces button.active { color: #ffffff; box-shadow: inset 0 -1px #ffffff; }
#workspaces button.urgent, #custom-recording, #pulseaudio.muted, #battery.critical { color: #ff8080; }
#custom-clock { color: #e6e6e6; }
#custom-dnd.on { color: #ffc799; }
#battery.charging { color: #99ffe4; }
#custom-recording, #custom-clock, #custom-dnd, #pulseaudio, #bluetooth, #network, #battery, #tray { padding: 0 10px; }
```
The current CSS styles `#clock`, but the module is `custom/clock`, so the clock never got its padding. The `#custom-clock` selector above fixes that.

## Black Hyprland frame (all options confirmed on the running 0.56.2)
```nix
general."col.active_border" = "rgb(5c5c5c)";
general."col.inactive_border" = "rgb(1c1c1c)";
misc = { background_color = "rgb(000000)"; disable_hyprland_logo = true; disable_splash_rendering = true; };
```
## alternatives

## risks
- **Light/dark detection after Plasma is removed (most likely to bite).** The desktop portal currently reports dark (prefer-dark = 1), which probably comes from Plasma's KDE portal. Without it, Ghostty may tell herdr "light", herdr passes that to TUIs, and yazi 26.8+ trusts the answer and loads its light theme (herdr issue #3198, still open). `window-theme = dark` in Ghostty should make Ghostty report dark, but I haven't tested it. To check from a pane run `printf '\e[?996n'`: you want `?997;1`. If that fails, add the GTK portal and `dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"`.
- **Squashed images in herdr.** Issue #4858 (open; reported on herdr 0.9.3 with Ghostty 1.3.1): Unicode-placeholder images, as yazi uses, lose their aspect ratio inside herdr panes. Plain Ghostty is fine. Changing the flake pin from v0.9.0 to 0.9.3 won't fix it.
- **Muting timing.** `dnd watch` mutes Slack/Discord streams only after they are created, so the first few milliseconds of a sound can get through. Slack huddle audio is muted too. Discord calls ("WEBRTC VoiceEngine") are deliberately left alone. The `.Discord-wrapped` name is specific to the NixOS package. Not tested end to end: I didn't toggle DND live, to avoid changing your current state. Easier fallback: Discord's own DND status and Slack's "Pause notifications".
- **`on-notify` in DND.** Not confirmed that `on-notify` runs for invisible notifications. If the waybar count stays stale, set `interval = 5` on custom/dnd.
- **yazi theme not checked by running yazi.** The theme keys match the 26.9.1 dark preset (`[app] overall`, `[indicator] current/parent`, `[mode]`, `[tabs]`). yazi wouldn't start without a real terminal here, so it wasn't run with this config.
- **Space binding syntax.** `shell --orphan -- ql %h` follows the documented examples; yazi quotes `%h` itself.
- **Selection key.** `i` was unbound by default. If you'd rather use `<C-Space>`, test it inside herdr first.
- **`zathura --mode=fullscreen`.** The flag appears in this build's `--help`, but the value "fullscreen" is taken from zathurarc's mode names, not tested. If it fails, use F11.
- **Ghostty systemd mode.** home-manager runs Ghostty as a systemd service by default. Plain `ghostty` keeps working; Ghostty recommends `ghostty +new-window` for faster launches. Theme "Vesper" exists in the installed 1.3.1 theme list.
- **Lucide maps letters and digits.** Lucide maps a–z and 0–9 to icons. Never put it first in a font-family list; the per-icon span avoids this.
- **pactl.** pulseaudio 17.0 (for `pactl`) is cached and already in the local store, so it adds no build. `pactl -f json` works on this machine.
- **Sources.** herdr, yazi and mako details come from source and man pages for the pinned versions, not just web docs.
## sources
https://raw.githubusercontent.com/herdrdev/herdr/v0.9.5/docs/next/website/src/content/docs/configuration.mdx (Theme + Kitty graphics sections)
herdr v0.9.0 source: /nix/store/lvni9nvdq59q5f4978wa5wh01z77zw8p-source/src/config/theme.rs, src/app/state.rs (vesper/terminal palettes), src/config.rs (kitty_graphics default true), src/pane.rs (TERM=xterm-256color), src/server/headless/tests/pane_graphics.rs (Yazi-style virtual placement)
https://github.com/herdrdev/herdr/issues/3198 (CSI ?996n answers light; yazi picks light preset)
https://github.com/herdrdev/herdr/issues/4858 (Unicode-placeholder images stretched in herdr)
https://github.com/herdrdev/herdr/issues/1324 (Image preview with Yazi)
yazi 26.9.1 source: yazi-config/preset/{keymap-default,yazi-default,theme-dark}.toml, yazi-emulator/src/brand.rs (TERM_PROGRAM=ghostty detection), yazi-config/src/lib.rs (light/dark preset choice)
https://yazi-rs.github.io/docs/configuration/keymap (shell %h/%s placeholders, --orphan, open --hovered)
https://yazi-rs.github.io/docs/tips (shell -- cmd %h examples)
nixpkgs pkgs/by-name/ya/yazi/package.nix (optionalDeps: poppler-utils, ffmpeg-headless, imagemagick, resvg, chafa...)
home-manager modules/programs/{ghostty,yazi,imv,zathura,mpv}.nix and modules/services/mako.nix (/nix/store/40h4dglabpdbvbx535xgfz3ifiz49cz6-source)
mako 1.11.0 man pages mako(5)/makoctl(1): default-timeout, ignore-timeout, history, max-history, [mode=...] invisible, makoctl mode -t, makoctl history/restore
wireplumber 0.5.18 scripts/node/state-stream.lua (stream.rules + state.restore-props)
https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/settings.html
https://ghostty.org/docs/config/reference
https://ghostty.org/docs/linux/systemd
https://man.voidlinux.org/zathura.1
https://lucide.dev (icon names; codepoints extracted from nixpkgs lucide 0.563.0 Lucide.ttf via fontTools)