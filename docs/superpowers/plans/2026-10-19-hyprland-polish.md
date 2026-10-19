# Hyprland Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the vivobook's Hyprland session into a polished, pure-black, terminal-first desktop. It covers:
- KDE removed
- tuned font rendering
- a minimal bar
- do-not-disturb (DND)
- a Vicinae launcher
- a settings hub with TUIs
- lock, idle, power and night light
- yazi
- on-demand Google Drive

All of it is declarative in this repo.

**Architecture:** System pieces go in new NixOS modules under `modules/desktop/`, imported only by `hosts/nixos-vivobook`. User pieces go in focused home-manager files under `home/`, imported by a new `home/vivobook.nix`. Each host gets its own home import list in `flake.nix`, so the Latitude keeps Plasma and gets none of this. Shell logic that has branches lives in plain `.sh` files, so a test script can source it.

**Tech Stack:** NixOS unstable flake, home-manager, Hyprland 0.56.2 (hyprlang), waybar, mako, Vicinae 0.29, gum, hypridle/hyprlock/hyprsunset, batsignal, playerctl, yazi 26.9.1, rclone 1.75.1, agenix.

**Spec:** `docs/superpowers/specs/2026-10-19-hyprland-polish-design.md`. Research with tested Nix sketches is in `docs/superpowers/specs/2026-10-19-hyprland-polish-research/` (`render.md`, `fonts.md`, `launcher.md`, `umbrella.md`, `power.md`, `gdrive.md`, `theming.md`, `bar-mockup.html`). Each task names the research section to start from. The spec wins over the research wherever they differ.

## Global Constraints

- Host in scope: `nixos-vivobook` only. `nix eval .#nixosConfigurations.latitude7490.config.system.build.toplevel.drvPath` must still succeed after every task.
- **Palette:**
  - bg `#000000`; raised `#121212`/`#1c1c1c`; border `#262626`/`#333333`; dim `#5c5c5c`; muted `#a0a0a0`; text `#e6e6e6`
  - attention: amber `#f5a524`
  - live/critical: red `#ff8080`
- **Fonts:**
  - UI: `"Atkinson Hyperlegible Next"`, bar at 15px.
  - Terminal: `"JetBrains Mono"`.
  - Icons: `lucide`, only inside Pango `<span font_family='lucide'>`, never in a font-family list.
- **Banners never auto-dismiss:** mako `default-timeout=0` and `ignore-timeout=1`. No script passes a timeout that would contradict this.
- **No GUI file explorer, no GUI settings apps.** wofi, nm-applet, networkmanagerapplet, blueman, pavucontrol and nwg-displays are all removed by the end.
- **Mutable state lives only under `~/.local/state/{hypridle,hyprsunset}/`** and in `~/.config/hypr/monitors.conf`. Everything else is in the repo.
- **Hyprland config stays hyprlang** (`configType = "hyprlang"`). After every switch, `hyprctl configerrors` must print nothing.
- **Switching needs sudo with a password.** The agent cannot run it.
  - The agent verifies by building: `nixos-rebuild build --flake .#nixos-vivobook`.
  - At each **SWITCH POINT**, ask the user to run `nixos-switch` in their own terminal, then continue with the runtime checks.
  - `nixos-switch` commits and pushes to `main` itself. Work happens on `main`, which is this repo's workflow. The per-task commits below just land first.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Login after removing SDDM.** If greetd or tuigreet fails, the user is stuck at a TTY. Expectation: the user knows how to recover before the first reboot, and the previous generation boots. This is pinned by the pre-reboot checklist in Task 1, Step 5.
2. **Bad input in the hub.** For example, a timeout of `abc` or `10`, a time of `25:00`, or a temperature of `99999`. Expectation: the value is rejected, the old value is kept, and hypridle and hyprsunset keep running. Pinned by `tests/hub-test.sh` in Task 7.
3. **DND toggled off, but Slack or Discord stays muted.** This also covers a restart or reboot while DND is on. Expectation: turning DND off unmutes them, and the mute never survives a reboot. Pinned by the runtime check in Task 5, Step 6.
4. **Something crawls `~/gdrive` and downloads the whole Drive.** Candidates: Vicinae indexing, yazi preloading, `rg`/`fd` from `~`. Expectation: browsing and searching download nothing that wasn't opened. Pinned by the cache-size check in Task 9, Step 7.
5. **Several screenshots waiting at once.** Expectation: clicking each banner opens satty on that banner's own file. Pinned by Task 5, Step 7.

---

### Task 0: Per-host home config + commit the design

**Files:**
- Modify: `flake.nix`. For each host, set `home-manager.users.tushar.imports`:
  - vivobook: `[ ./home/tushar.nix ./home/vivobook.nix ]`
  - latitude: `[ ./home/tushar.nix ./home/latitude.nix ]`
- Create: `home/latitude.nix`. It imports `inputs.plasma-manager.homeModules.plasma-manager` and `./plasma.nix`, and adds `kdePackages.kate`.
  - It does **not** import `./hyprland.nix`. Later tasks rewrite that file with vivobook-only binds and packages.
  - The Latitude runs Plasma, so dropping its Hyprland user config is accepted (planner's call). Its Hyprland session would fall back to defaults.
- Create: `home/vivobook.nix`. For now it only has `imports = [ ./hyprland.nix ];`. Later tasks append to it.
- Modify: `home/tushar.nix`. Remove the plasma-manager import, `./plasma.nix`, `./hyprland.nix` and `kdePackages.kate`.

**Interfaces:**
- Produces: `home/vivobook.nix`, which is the import list every later home task appends to.

- [ ] **Step 1: Commit the spec, research and this plan as-is**
  `git add docs && git commit -m "docs: hyprland polish design, research and plan"`
- [ ] **Step 2: Make the flake, home and host edits above**
- [ ] **Step 3: Verify both hosts evaluate**
  Run: `nix eval .#nixosConfigurations.latitude7490.config.system.build.toplevel.drvPath && nixos-rebuild build --flake .#nixos-vivobook`
  Expected: both succeed.
- [ ] **Step 4: Verify the Latitude keeps its Plasma config**
  Run: `nix eval --json .#nixosConfigurations.latitude7490.config.home-manager.users.tushar.programs.plasma.enable`
  Expected: `true`.
- [ ] **Step 5: Commit** (`refactor: split home config per host`)

### Task 1: Session plumbing and KDE removal (system)

Start from: `power.md` §1 and its "What disappears with Plasma" list.

**Files:**
- Create: `modules/desktop/session.nix`. It contains:
  - `services.greetd` + tuigreet: `--time --remember --asterisks`, a black theme, and `--cmd` set to Hyprland's `start-hyprland`.
  - `services.gnome.gnome-keyring.enable`
  - `xdg.portal.config.hyprland`, with `default = [ "hyprland" "gtk" ]` and Secret → gnome-keyring
  - `programs.hyprlock.enable`
  - upower, power-profiles-daemon, udisks2 and fwupd enabled
  - `programs.fuse.enable`
  - logind settings: `HandlePowerKey = "ignore"`, `HandlePowerKeyLongPress = "poweroff"`, `HandleLidSwitch = "suspend"`, `HandleLidSwitchDocked = "ignore"`
  - `services.xserver.xkb.layout = "us"`, carried over from plasma.nix.
- Modify: `hosts/nixos-vivobook/default.nix`. Replace `../../modules/desktop/plasma.nix` with `../../modules/desktop/session.nix`.
- Modify: `home/vivobook.nix`. Add `services.hyprpolkitagent.enable = true;`.

- [ ] **Step 1: Write the failing check**
  Run: `ls /run/current-system/sw/share/applications | grep -ciE 'org\.kde|kate|dolphin|konsole|systemsettings'`
  Expected now: more than 0. Record the number.
- [ ] **Step 2: Implement the module and imports above**
- [ ] **Step 3: Build and check the result has no KDE apps**
  Run: `nixos-rebuild build --flake .#nixos-vivobook && ls result/sw/share/applications | grep -ciE 'org\.kde|kate|dolphin|konsole|systemsettings'`
  Expected: `0`. Also run `readlink -f result/etc/systemd/system/greetd.service` and expect it to exist.
- [ ] **Step 4: Commit** (`feat: replace plasma with greetd session on vivobook`)
- [ ] **Step 5: Pre-reboot checklist.** Tell the user all of this before the switch:
  - If something matters in kwallet, export it first from `~/.local/share/kwalletd/`.
  - After switching, reboot. The previous generation stays in the systemd-boot menu.
  - If login fails, press Ctrl+Alt+F2 for a TTY, then log in and run `sudo nixos-rebuild switch --rollback`.
  - Chrome and Slack may ask you to sign in again.
- [ ] **SWITCH POINT A:** the user runs `nixos-switch` and then reboots.
- [ ] **Step 6: Runtime checks after login through tuigreet**
  - `pgrep -x hyprpolkitagent`: prints a PID.
  - `busctl --user list | grep -c org.freedesktop.secrets`: at least 1.
  - `ls /run/wrappers/bin/fusermount3`: exists.
  - `hyprctl configerrors`: prints nothing.
  - The user shares their screen in a Chrome tab (meet.google.com or Teams): the screen picker appears and sharing works.
  - Super+Space shows no KDE apps.

### Task 2: Fonts and rendering

Start from: `render.md` (the corrected recipe, section A) and `fonts.md`.

**Files:**
- Create: `modules/desktop/fonts.nix`, imported by the vivobook host.
  - **`fonts.packages`:** `atkinson-hyperlegible-next`, `jetbrains-mono`, `noto-fonts`, `noto-fonts-cjk-sans`, `noto-fonts-color-emoji`, `nerd-fonts.symbols-only`, `lucide`.
  - **`fontconfig`:**
    - `hinting.style = "slight"`
    - `subpixel.rgba = "none"`
    - `useEmbeddedBitmaps = false`
    - `defaultFonts`: sansSerif `[ "Atkinson Hyperlegible Next" "Noto Sans" ]`, serif `[ "Noto Serif" ]`, monospace `[ "JetBrains Mono" "Symbols Nerd Font Mono" ]`, emoji `[ "Noto Color Emoji" ]`
  - **`environment.sessionVariables.FREETYPE_PROPERTIES`:**
    `"autofitter:no-stem-darkening=0 autofitter:darkening-parameters=500,400,1000,400,2500,400,4000,0 cff:no-stem-darkening=0"`

- [ ] **Step 1: Write the failing check**
  Run: `fc-match -v sans-serif | grep -E 'family:|embeddedbitmap'`
  Expected now: DejaVu or Noto Sans, and `embeddedbitmap: True`.
- [ ] **Step 2: Implement `modules/desktop/fonts.nix` and import it**
- [ ] **Step 3: Build** (`nixos-rebuild build --flake .#nixos-vivobook`) **and commit** (`feat: font stack and freetype stem darkening`)
- [ ] (Folded into SWITCH POINT B after Task 3.)
- [ ] **Step 4: Runtime checks** (after logging out and back in)
  - `fc-match -v sans-serif | grep -E 'family:|hintstyle|rgba|embeddedbitmap'`: family Atkinson Hyperlegible Next, hintstyle 1, rgba 5, embeddedbitmap False.
  - `tr '\0' '\n' </proc/$(pgrep -x waybar)/environ | grep FREETYPE`: shows the value.
  - A/B test:
    1. Render with darkening off: `FREETYPE_PROPERTIES= pango-view -q --backend=cairo --font='Atkinson Hyperlegible Next 11' --hinting=slight -o /tmp/off.png --text='The quick brown fox 0123'`
    2. Render the same command again with the variable set, saving to `/tmp/on.png`.
    3. Expect `on.png` to have visibly more ink. pango-view comes from `pkgs.pango.bin`; use `nix shell`.
- [ ] **Step 5: Calibrate with the user.** Show them Ghostty, the bar and a mako banner (`notify-send Test 'The quick brown fox'`) on both monitors. If it's too bold, switch to Adobe's curve, `500,400,1000,275,1667,275,2333,0` (`render.md` §E). Change one knob, rebuild, and ask again. Commit the final value.

### Task 3: Terminal and frame theming

Start from: `theming.md` §1, §2 and "Black Hyprland frame".

**Files:**
- Create: `home/terminal.nix`, imported by `home/vivobook.nix`.
  - `programs.ghostty`, with these settings and no font-family (Ghostty bundles JetBrains Mono):
    - `background = "#000000"`, `foreground = "#e6e6e6"`
    - `selection-background = "#262626"`
    - `window-theme = "dark"`, `window-decoration = "none"`
    - padding 8/6, `confirm-close-surface = false`
- Modify: `home/tushar.nix`. Remove `ghostty` from `home.packages`; `programs.ghostty` installs it on the vivobook. Add `ghostty` to `home/latitude.nix`'s packages so the Latitude keeps it. The herdr `xdg.configFile` line stays in `home/tushar.nix`, so both hosts keep getting it.
- Modify: `home/herdr.toml`. Add `[theme] name = "vesper"`, `auto_switch = false`, and `[theme.custom]` with `panel_bg`, `sidebar_bg` and `surface_dim` = `#000000`, `active_row_bg = "#121212"`, `selection_bg`/`surface0 = "#1c1c1c"`, `surface1 = "#2a2a2a"`. Also add `[terminal] kitty_graphics = true`.
  - The Latitude shares this file, which is acceptable: it's a theme change only.
- Modify: `home/hyprland.nix`:
  - `general."col.active_border" = "rgb(5c5c5c)"`, `"col.inactive_border" = "rgb(1c1c1c)"`
  - `misc = { background_color = "rgb(000000)"; disable_hyprland_logo = true; disable_splash_rendering = true; }`

- [ ] **Step 1: Write the failing check.** In a herdr pane, run `printf '\e[?996n'; read -rsn6 -t1 r; echo "$r" | od -c | head -1`. Record the result.
- [ ] **Step 2: Implement the files above**
- [ ] **Step 3: Validate the configs before switching**
  - `HERDR_CONFIG_PATH=./home/herdr.toml herdr config check`: OK.
  - Build: OK.
- [ ] **Step 4: Commit** (`feat: pure black ghostty, herdr and hyprland frame`)
- [ ] **SWITCH POINT B** (Tasks 2 and 3). Before switching, the user deletes `~/.config/ghostty/config.ghostty` (a manual step), then runs `nixos-switch`, then logs out and back in.
- [ ] **Step 5: Runtime checks**
  - `ghostty +validate-config`: no errors.
  - Step 1's probe in a herdr pane: `?997;1`, meaning dark. If it reports light, add `dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"` and recheck.
  - herdr's sidebar, panels and panes are all pure black, judged by eye with the user.

### Task 4: Waybar

Start from: `theming.md` §6, `power.md` (mic script, backlight), and `bar-mockup.html` variant C.

**Files:**
- Create: `home/waybar.nix`, imported by `home/vivobook.nix`. Move the `programs.waybar` block here from `home/hyprland.nix`, and remove `"waybar"` from `exec-once` there in favor of `programs.waybar.systemd.enable = true`.
- Create: `home/scripts/mic.sh`. Logic is in the Interfaces block below.

**Interfaces:**
- **`mic` (writeShellApplication from `mic.sh`):**
  - No arguments: print waybar JSON `{text, class, tooltip}`.
    - `class` is `muted` when the default source is muted.
    - Otherwise `live` when any capture stream exists, ignoring monitor streams.
    - Otherwise `idle`.
    - The text is always a Lucide mic icon (`e118`, or `e119` when muted). The tooltip lists the capturing apps.
  - `mic toggle`: run `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`, then `pkill -RTMIN+9 waybar`.
- **Waybar signals:** DND is `8` (Task 5). Mic is `9`.
- **Bar layout:**
  - `modules-left = [ "hyprland/workspaces" ]`
  - `modules-center = [ "custom/clock" ]`, with `exec = "date '+%a %m/%d · %H:%M:%S'"`, `interval = 1`
  - `modules-right = [ "custom/recording" "custom/dnd" "custom/mic" "backlight" "pulseaudio" "bluetooth" "network" "battery" ]`, with no tray
- **Module formats:**
  - backlight and pulseaudio: icon plus `{percent}%`/`{volume}%` in dim grey, through Pango `<span color='#5c5c5c'>`
  - bluetooth: `format = ""` (hidden) unless connected. When connected, icon only; the alias goes in the tooltip.
  - network: icon only; the ESSID goes in the tooltip.
  - battery: icon plus `{capacity}%`, with `states = { warning = 20; critical = 10; }`.
- **On-click:**
  - network: `hub wifi`
  - bluetooth: `hub bluetooth`
  - pulseaudio: `hub audio`
  - backlight: `hub brightness`; scroll runs `brightnessctl set 5%±`
  - mic: `mic toggle`
  - DND: `dnd` (defined in Task 5)
  - Until Task 7 lands, `hub` doesn't exist and those clicks do nothing. That's acceptable.
- **CSS:** `font-family: "Atkinson Hyperlegible Next"; font-size: 15px;` and the black styles from `theming.md` §6. Use `#custom-clock`, not `#clock`.
  - Colors: `.warning` amber; `.critical`, `#custom-mic.live` and `#custom-recording` red; `#custom-mic.idle` and `.muted` dim.

- [ ] **Step 1: Write the failing check**
  Run: `mic | jq -e '.class'`
  Expected: `mic: command not found`.
- [ ] **Step 2: Implement `mic.sh` and `home/waybar.nix`**
- [ ] **Step 3: Build and commit** (`feat: minimal pure-black waybar with mic and brightness`)
- [ ] (Runtime checks happen at SWITCH POINT C, after Task 5.)
- [ ] **Step 4: Runtime checks**
  - `mic | jq -r .class`: `idle`.
  - Start recording with `pw-record /tmp/x.wav &`: the class is `live` and the icon turns red within 1s.
  - `mic toggle`: the class is `muted`.
  - `mic toggle` again: back to normal. Then `kill %1`.
  - The bar matches mockup C on both monitors (the user confirms).

### Task 5: Notifications, DND, screenshots, media keys, battery

Start from: `theming.md` §3 and §4, and `power.md` (media, batsignal).

**Files:**
- Create: `home/notifications.nix`, imported by `home/vivobook.nix`. Remove `services.mako.enable` and `"mako"` from `home/hyprland.nix`.
  - **mako:** `settings` from `theming.md` §3, with `font = "Atkinson Hyperlegible Next 11"`, `max-icon-size = 96`, and a 1px `#333333` border.
  - **batsignal:** `extraArgs = [ "-w" "20" "-c" "10" "-d" "5" "-D" "systemctl suspend" ]`.
  - **playerctld:** `services.playerctld.enable`.
- Create: `home/scripts/dnd.sh`, `home/scripts/shot.sh`, `home/scripts/media.sh`.
- Modify: `modules/system/audio.nix`. Add the WirePlumber `90-dnd-apps` rule from `theming.md` §4, which sets `state.restore-props = false` for `slack` and `.Discord-wrapped`.
- Modify: `home/hyprland.nix` binds:
  - `$mod, D` → `dnd`
  - `$mod, N` → `makoctl restore`
  - `$mod SHIFT, N` → `makoctl dismiss -a`
  - the three screenshot binds → `shot region` / `shot monitor`
  - `bindl` for XF86AudioPlay, Pause, Next and Prev → `media play-pause|next|previous`
  - `exec-once`: add `dnd watch`

**Interfaces:**
- **`dnd [toggle|watch|status]`:** behaves as in `theming.md` §4, with signal `8`.
  - `status` prints `{"text":"",…}` when DND is off, so the module hides.
  - When on, it prints the amber Lucide bell-off (`e05a`) plus the hidden count.
- **`shot region|monitor`:**
  1. Capture with grim (slurp for a region). Esc in slurp exits 0 and does nothing.
  2. Write `~/ss/pics/screenshot-%Y%m%d-%H%M%S.png`.
  3. Copy it: `wl-copy --type image/png < file`.
  4. Then run `setsid -f sh -c 'notify-send -a screenshot -i "$f" --action=default=Edit --wait "Screenshot" "$name" | grep -qx default && satty --filename "$f" --output-filename "$f"'`. Each banner owns its file.
  - `# ponytail: one sleeping notify-send per unclicked banner; fine at human screenshot rates`
- **`media <playerctl-cmd>`:** runs `playerctl <cmd> || exit 0`, waits `sleep 0.2`, then `notify-send -a media -r <id saved in $XDG_RUNTIME_DIR/media-notify-id> -p`.
  - Summary: `{{playerName}}  {{lc(status)}}`
  - Body: `{{trunc(title,60)}}\n{{artist}}`
  - No `-t`. The single banner replaces itself.

- [ ] **Step 1: Write the failing checks**
  - `makoctl mode`: no `dnd` mode configured yet.
  - `notify-send -t 1000 probe; sleep 2; makoctl list -j | jq length`: 0. The banner expired, which proves `ignore-timeout` isn't set yet.
- [ ] **Step 2: Implement the files above.** Package each script with `pkgs.writeShellApplication { name; runtimeInputs; text = builtins.readFile ./scripts/<name>.sh; }`.
- [ ] **Step 3: Build and commit** (`feat: black mako, manual DND, screenshot/media banners, battery alerts`)
- [ ] **SWITCH POINT C** (Tasks 4 and 5): the user runs `nixos-switch` and then logs out and back in.
- [ ] **Step 4: Check the never-dismiss setting**
  Run: `notify-send -t 1000 probe; sleep 2; makoctl list -j | jq length`
  Expected: at least 1.
- [ ] **Step 5: Check DND hides and restores banners**
  1. Run `dnd`: the bell appears.
  2. `notify-send hidden`: no banner shows, and the bell count goes up.
  3. Run `dnd` again: the banner appears.
- [ ] **Step 6: Check the Slack/Discord mute** (Review Focus 3). Slack must be running.
  1. Run `dnd`, then `pactl -f json list sink-inputs | jq '[.[]|select(.properties["application.process.binary"]=="slack")|.mute]'`: all `true`, or an empty list if Slack is silent.
  2. Run `dnd` again: all `false`.
  3. Turn DND on, run `systemctl --user restart wireplumber`, turn DND off, and play a Slack sound: it's audible.
- [ ] **Step 7: Check screenshots** (Review Focus 5)
  1. Take two region shots.
  2. `wl-paste -l` lists `image/png`, and two new files exist in `~/ss/pics`.
  3. Click the older banner: satty opens on the older file.
- [ ] **Step 8: Check media keys.** Play a YouTube video in Chrome and press Play/Pause: one banner shows `chromium  paused` and the title. Press it again: the same banner updates and doesn't stack.

### Task 6: Vicinae launcher

Start from: `launcher.md` §1 and §2.

**Files:**
- Create: `home/vicinae.nix`, imported by `home/vivobook.nix`. It covers:
  - `programs.vicinae` with the `pure-black` theme, using the Global Constraints palette
  - font `normal.family = "Atkinson Hyperlegible Next"`, `rendering = "native"`
  - layer shell
  - aliases: `f` (files), `v` (clipboard), `c` (ask-claude)
  - `excludedIndexingPaths = [ "/home/tushar/gdrive" ]`
  - `fallbacks = [ "scripts:ask-claude" "files:search" ]`
  - the script directory built with `runCommandLocal`, containing `ask-claude`
- Modify: `home/hyprland.nix`.
  - Bind `$mod, SPACE` → `vicinae toggle` and `$mod SHIFT, V` → `vicinae deeplink vicinae://launch/clipboard/history`.
  - Add the `no_anim` layerrule.
  - Remove `programs.wofi.enable`.
- Create: `home/.ignore` content via `home.file.".ignore".text = "/gdrive/\n";`. Put it here, because the indexer is the first crawler.

**Interfaces:**
- **`ask-claude` script command:** takes one `percentEncoded` argument and runs `setsid -f google-chrome-stable --profile-directory=Default "https://claude.ai/new?q=$1"`.
- **Task 7 adds more script commands** to the same `scripts` attrset: `wifi`, `bluetooth`, `audio`, `displays`, `autolock`, `nightlight`, `power`. Each one is `setsid -f ghostty --class=dev.tushar.hub -e hub <section>`.
  - Expose the attrset as `let scripts = { … }` in `home/vicinae.nix`, and import `hubSections` from Task 7's file once it exists. Until then, only `ask-claude`.

- [ ] **Step 1: Write the failing check**
  Run: `systemctl --user is-active vicinae`
  Expected: inactive, or the unit doesn't exist.
- [ ] **Step 2: Implement `home/vicinae.nix`**
- [ ] **Step 3: Build and commit** (`feat: vicinae launcher with calculator, files, clipboard and ask-claude`)
- [ ] (Runtime checks happen at SWITCH POINT D, after Task 7.)
- [ ] **Step 4: Runtime checks**
  - Super+Space opens a black window.
  - `2*21` shows 42.
  - `f hyprland` finds `~/nixos-config/home/hyprland.nix`.
  - Super+Shift+V lists recent copies, including a screenshot image.
  - `c say hi` opens claude.ai in the parone Chrome profile with the prompt filled in. Report to the user whether it auto-sent.
  - Typing `zzzz-nomatch` offers "Ask Claude" as the fallback. If not, note it and keep the alias.

### Task 7: Hub, auto-lock, power, lid, night light, displays

Start from: `umbrella.md` (hub, hypridle overrides), `power.md` (power menu, hyprlock), and the spec's §8, §9 and §9b.

**Files:**
- Create: `home/hub/lib.sh`, the pure functions tested below. It contains no top-level side effects.
- Create: `home/hub/hub.sh`, the menus. It sources `lib.sh` (the two files are concatenated at build time).
- Create: `home/hub.nix`, imported by `home/vivobook.nix`. It contains:
  - the `hub` package (`writeShellApplication`, `bashOptions = [ "nounset" "pipefail" ]`, and `runtimeInputs` of gum, wifitui, bluetui, wiremix, hyprmon, systemd-manager-tui, brightnessctl, hyprsunset and jq)
  - `services.hypridle`: `$lock = 300`, `$off = 330`, `$suspend = 1800`, `source = ~/.local/state/hypridle/overrides.conf`, `importantPrefixes = [ "$" "source" ]`, and the three listeners. `before_sleep_cmd = "loginctl lock-session"`.
  - `ConditionPathExists=!%h/.local/state/hypridle/off`
  - tmpfiles creating an empty `overrides.conf`
  - `programs.hyprlock`: black background, a clock label and an input field in Atkinson Hyperlegible Next. Nothing else.
  - `services.hyprsunset`: defaults `{ time = "7:00"; identity = true; }` and `{ time = "20:30"; temperature = 4000; }`. ExecStart is overridden by a wrapper that uses `~/.local/state/hyprsunset/hyprsunset.conf` if it exists, and the HM-generated config otherwise.
  - the `hyprmon` wrapper, with `HYPRLAND_CONFIG=$HOME/.config/hypr/monitors.conf`
  - the window rule for class `dev.tushar.hub`: float, center, size 900 600
  - binds:
    - `$mod, A` → hub
    - `$mod, Escape` and `, XF86PowerOff` → `hub power`
    - `bindl` `, switch:on:Lid Switch` → `lid close`
    - `bindl` `, switch:off:Lid Switch` → `hyprctl reload`
- Create: `home/scripts/lid.sh`. When `hyprctl monitors -j | jq length` is greater than 1, run `hyprctl keyword monitor "eDP-1,disable"`. Otherwise do nothing, because logind suspends and hypridle locks.
- Create: `tests/hub-test.sh`. It sources `home/hub/lib.sh` and uses asserts only, with no framework.
- Modify: `home/vicinae.nix`. Add the hub section scripts (Task 6's Interfaces).
- Modify: `home/waybar.nix`. The on-click handlers now resolve.
- Modify: `home/hyprland.nix`. Remove `pavucontrol`, `networkmanagerapplet`, `blueman`, `nwg-displays` and `nm-applet` from exec-once. Remove `$mod SHIFT, M, exit`, because the power menu covers it.

**Interfaces (lib.sh; each function returns 0 on success and 1 on rejection):**
- `valid_seconds <v>`: an integer of at least 30.
- `valid_hhmm <v>`: matches `^([01][0-9]|2[0-3]):[0-5][0-9]$`.
- `valid_kelvin <v>`: an integer from 1000 to 6500.
- `kv_get <file> <key> <default>`: prints the value of the last `$key = v` line in `file`, or `default` if there is none or the file is missing.
- `kv_set <file> <key> <value>`: atomically replaces or appends `$key = value` and leaves every other line alone. It writes through a temp file plus `mv`.
- `sunset_conf <on:0|1> <start HH:MM> <end HH:MM> <kelvin>`: prints a hyprsunset config with two `profile { }` blocks. When on is 0, it prints only an identity profile at `00:00`.

**Hub sections** (`hub <section>`, or a gum menu when called with no arguments):
- `wifi`, `bluetooth`, `audio`, `displays` (hyprmon) and `services` run their TUI.
- `brightness`: a gum choice of 10/25/50/75/100%.
- `autolock`: the `umbrella.md` menu, using `valid_seconds` and `kv_set`, then `systemctl --user restart hypridle`.
- `nightlight`: on/off, start, end and temperature.
  - Each temperature input previews live with `hyprctl hyprsunset temperature <k>` before saving.
  - Saving runs `sunset_conf` into the state file and restarts hyprsunset.
  - Quick actions: "off until tomorrow" (`hyprctl hyprsunset identity`), "warm now" (`hyprctl hyprsunset temperature 3500`), and "reset" (deletes the state file and restarts).
- `power`: a single-key screen.
  - `l` runs `loginctl lock-session`.
  - `s` runs `systemctl suspend`.
  - `e`, `r` and `p` (log out, reboot, power off) each ask `y/N` before `hyprctl dispatch exit`, `systemctl reboot` or `systemctl poweroff`.
  - Esc exits.

- [ ] **Step 1: Write the failing tests** in `tests/hub-test.sh`

```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/../home/hub/lib.sh"
ok()  { "$@" || { echo "FAIL: $*"; exit 1; }; }
nok() { ! "$@" || { echo "FAIL (accepted): $*"; exit 1; }; }
ok valid_seconds 30;  nok valid_seconds 29; nok valid_seconds abc; nok valid_seconds ""
ok valid_hhmm 20:30;  ok valid_hhmm 07:00;  nok valid_hhmm 25:00; nok valid_hhmm 7:00; nok valid_hhmm 20:60
ok valid_kelvin 4000; nok valid_kelvin 999; nok valid_kelvin 6501; nok valid_kelvin 4k
f=$(mktemp); trap 'rm -f "$f"' EXIT
[ "$(kv_get "$f" lock 300)" = 300 ]               || { echo "FAIL: default"; exit 1; }
kv_set "$f" lock 120; kv_set "$f" off 400; kv_set "$f" lock 150
[ "$(kv_get "$f" lock 300)" = 150 ]               || { echo "FAIL: overwrite"; exit 1; }
[ "$(kv_get "$f" off 330)" = 400 ]                || { echo "FAIL: other key kept"; exit 1; }
[ "$(grep -c '^\$lock = ' "$f")" = 1 ]            || { echo "FAIL: duplicate keys"; exit 1; }
[ "$(kv_get /nonexistent lock 300)" = 300 ]       || { echo "FAIL: missing file"; exit 1; }
sunset_conf 1 20:30 07:00 4000 | grep -q 'temperature = 4000' || { echo "FAIL: sunset on"; exit 1; }
[ "$(sunset_conf 0 20:30 07:00 4000 | grep -c 'profile')" = 1 ] || { echo "FAIL: sunset off"; exit 1; }
echo PASS
```

- [ ] **Step 2: Run the tests and watch them fail**
  Run: `bash tests/hub-test.sh`
  Expected: FAIL, because `lib.sh` doesn't exist yet.
- [ ] **Step 3: Implement `home/hub/lib.sh`** with the signatures above.
- [ ] **Step 4: Run the tests and watch them pass**
  Run: `bash tests/hub-test.sh && nix shell nixpkgs#shellcheck -c shellcheck home/hub/*.sh home/scripts/*.sh`
  Expected: `PASS`, and shellcheck prints nothing.
- [ ] **Step 5: Validate the hyprsunset config.** Run `sunset_conf 1 20:30 07:00 4000 > /tmp/hs.conf`, then run `hyprsunset -c /tmp/hs.conf` briefly. Expected: it starts with no parse error, and you kill it afterwards.
- [ ] **Step 6: Implement `hub.sh`, `home/hub.nix`, `lid.sh` and the edits above. Build, then commit** (`feat: settings hub, auto-lock, power menu, lid and night light`)
- [ ] **SWITCH POINT D** (Tasks 6 and 7): the user runs `nixos-switch` and then logs out and back in.
- [ ] **Step 7: Runtime checks**
  - **Power button:** `wev` shows how many XF86PowerOff events one press sends. If there are two, make sure the second press focuses the existing window instead of opening a second one. Use the focus-or-launch rule from `umbrella.md` "Left out".
  - **Auto-lock:** `hub autolock` → set lock to 60. `grep lock ~/.local/state/hypridle/overrides.conf` shows `$lock = 60`. After 60s idle, the screen locks. Reset afterwards.
  - **Bad input:** `hub autolock` → enter `abc`. It's rejected, and `systemctl --user is-active hypridle` still reports active.
  - **Night light:** `hub nightlight` → temperature 3000. The screen warms during the preview. After saving, it survives `systemctl --user restart hyprsunset`. Reset afterwards.
  - **Lid with HDMI connected:** close the lid. eDP-1 is disabled, and the session stays unlocked on the external monitor. Open the lid: eDP-1 comes back in its `monitors.conf` position.
  - **Lid with HDMI disconnected:** close the lid. The machine suspends, and resumes on hyprlock.
  - **hyprmon:** open it, move nothing, and save. Expected: only `monitor=` lines change in `~/.config/hypr/monitors.conf`, and `hyprland.conf` is untouched. If it writes anything else, revert to nwg-displays and tell the user (spec §9b).
  - **`hyprctl dispatch dpms off`:** run it by hand. If the syntax is rejected on 0.56, switch the hypridle listener to the working form.

### Task 8: yazi

Start from: `theming.md` §5 and `gdrive.md` §5.

**Files:**
- Create: `home/yazi.nix`, imported by `home/vivobook.nix`. It contains:
  - `programs.yazi`, with the theme from `theming.md` §5 using the Global Constraints palette
  - the keymaps: `<Space>` → `shell --orphan -- ql %h`, and `i` → toggle selection and move down one
  - the mime-ext plugin
  - `prepend_preloaders` set to `noop` for `/home/tushar/gdrive/**`
  - `programs.imv`, `programs.zathura` (recolored to black) and `programs.mpv`
- Create: `home/scripts/ql.sh`. It routes by `file -Lb --mime-type`: `image/*` opens `imv -f`, `application/pdf` opens `zathura --mode=fullscreen`, and `video/*|audio/*` opens `mpv --fs`. Anything else does nothing, with exit 0.
- Modify: `home/tushar.nix`. Remove `mpv` from `home.packages`, and add it to `home/latitude.nix` so the Latitude keeps it.

- [ ] **Step 1: Write the failing check**
  Run: `command -v yazi ql`
  Expected: not found.
- [ ] **Step 2: Implement the files above, build, and commit** (`feat: yazi with quick-look on space`)
- [ ] **SWITCH POINT E:** the user runs `nixos-switch`.
- [ ] **Step 3: Runtime checks**
  - `y ~/ss/pics` shows an image preview in Ghostty and inside a herdr pane. In herdr the aspect ratio may be off; that's a known issue and accepted.
  - Space on a PNG opens imv full screen. Space closes it.
  - Space on a PDF opens zathura full screen with a black background.
  - `i` selects a file.

### Task 9: Google Drive (blocked on the user)

Start from: `gdrive.md` (all sections).

**Files:**
- Create: `modules/desktop/gdrive.nix`, imported only by the vivobook host. It sets `programs.fuse.enable` (already set in Task 1, which is harmless) and adds three `age.secrets` entries: `rclone-gdrive-client-secret`, `rclone-gdrive-personal-token` and `rclone-gdrive-study-token`, each with owner tushar and mode 0400.
- Modify: `secrets/secrets.nix`. Add the three `.age` entries.
- Create: `home/rclone.nix`, imported by `home/vivobook.nix`. It's `gdrive.md` §4 as written:
  - accounts `personal` and `study`, with `client_id` filled in
  - mount options `dir-cache-time 1000h`, `poll-interval 15s`, `vfs-cache-max-age 720h`, `vfs-cache-max-size 10G`, `vfs-cache-min-free-space 20G`
  - `export_formats = "link.html"`, `use_trash = true`
  - the systemd overrides for restarts and stale FUSE mounts
- Modify: `programs.nixvim` (in `home/vivobook.nix`). Set `opts.backupcopy = "yes"`, and set `opts.backupdir` to state-home only.

- [ ] **Step 1: Hand the user the one-time manual steps** from `gdrive.md`, "One-time manual steps", 1–6. Those steps cover:
  - the Google Cloud project and Drive API
  - an OAuth Desktop client, published to "In production"
  - `rclone authorize` for each account, signing in as `reachtusharwani@gmail.com` and `tusharstudydocs@gmail.com`
  - `agenix -e` for the three secrets

  Wait until the user says they're done and gives you the `client_id` (it isn't a secret).
- [ ] **Step 2: Implement the files above, build, and commit** (`feat: on-demand google drive mounts via rclone`)
- [ ] **SWITCH POINT F:** the user runs `nixos-switch`.
- [ ] **Step 3: Check both mounts**
  Run: `systemctl --user is-active 'rclone-mount:@gdrive-personal' 'rclone-mount:@gdrive-study' && ls ~/gdrive/personal ~/gdrive/study`
  Expected: both active, and both list files.
- [ ] **Step 4: Check that nothing downloads before you open it**
  Run: `du -sh ~/.cache/rclone/vfs` before and after `ls -R ~/gdrive/personal | head -200`.
  Expected: the size is unchanged.
- [ ] **Step 5: Check that a local edit uploads**
  1. Run `echo hi > ~/gdrive/personal/claude-test.txt`.
  2. Wait 10s.
  3. Run `rclone lsf gdrive-personal: | grep claude-test`.
  Expected: present.
- [ ] **Step 6: Check that deletes go both ways**
  1. Run `rm ~/gdrive/personal/claude-test.txt`. It's gone from `rclone lsf` and sits in Drive's trash.
  2. The user deletes a test file on drive.google.com. Within about 15s it's gone from `ls`.
- [ ] **Step 7: Check that browsing doesn't download** (Review Focus 4). Browse `~/gdrive/personal` in yazi, hovering over a few folders but no files. Then run `rg foo ~` and use Vicinae `f` search. `du -sh ~/.cache/rclone/vfs` should barely grow: only files that were actually previewed.
- [ ] **Step 8: Check that unmounting keeps the Drive**
  1. Run `systemctl --user stop 'rclone-mount:@gdrive-study'`. Then `rclone lsf gdrive-study: | wc -l` should show the same count as before.
  2. Start the mount again.

### Task 10: Final review

- [ ] **Step 1: Search for leftovers**
  Run: `grep -rnE 'wofi|nm-applet|networkmanagerapplet|blueman|pavucontrol|nwg-displays|catppuccin|1e1e2e|monospace' home modules hosts`
  Expected: nothing for the vivobook. `home/latitude.nix` and `home/plasma.nix` may mention KDE.
- [ ] **Step 2: Check the Latitude**
  Run: `nix eval .#nixosConfigurations.latitude7490.config.system.build.toplevel.drvPath`
  Expected: succeeds.
- [ ] **Step 3: Walk the user through each spec Goal (1–8)** on the live system and record anything rejected as a follow-up.
- [ ] **Step 4: Commit any final fixes**
