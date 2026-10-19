# Hyprland polish: design

Date: 2026-10-19. Host in scope: `nixos-vivobook` only.

## Why

The Hyprland session works, but it doesn't feel like a finished system. Concretely:

- During a Teams call in Chrome, Discord and Slack kept pinging and there was no way to silence them.
- KDE apps show up in the Hyprland launcher, even though the user never wants to use them there.
- Text looks thin and unrefined.
- The bar is navy, cluttered and text-heavy.
- System settings open mismatched GUI apps.

The goal is a polished, pure-black, keyboard- and terminal-first desktop. All of it must be declared in this repo and rebuild reproducibly with `nixos-switch`.

Supporting research for every section is in `docs/superpowers/specs/2026-10-19-hyprland-polish-research/`. Each file has a recommended Nix sketch, alternatives, risks and sources, checked against the pinned flake. Treat those sketches as starting points, not finished code. Where this document and the research disagree, this document wins.

## Goals

1. Pure black (`#000`) everywhere the user looks: bar, notification banners, launcher, Ghostty, herdr, yazi, TUIs, lock screen, login screen, Hyprland background and borders.
2. Excellent text rendering, with the Mac-like "crispness" the user asked for, rather than bigger text.
3. A minimal bar that shows numbers only where they matter.
4. A do-not-disturb mode the user controls by hand.
5. A smart Super+Space: apps, calculator, file search, clipboard history and "ask Claude".
6. Terminal UIs for system settings, reachable through one hub.
7. On-demand Google Drive for two accounts.
8. No KDE anywhere on the vivobook.

## Non-goals and anti-goals

- **No GUI file explorer.** The user said they will never open one again. Don't install Nautilus, Thunar or Dolphin.
- **No dark-mode propagation into GUI apps** (GTK/Qt themes, Chrome's dark mode). The user explicitly doesn't care. The one exception is the narrow fix in "Terminal theme detection" below.
- **No pop-up OSDs** for volume or brightness. Changes show in the bar instead.
- **Banners never auto-dismiss.** This applies to every banner, including screenshots and media. It's an existing behavior the user wants to keep.
- **No emoji or "tacky" icons**, and no wordy bar labels. Both were explicitly rejected.
- **Latitude7490 is out of scope.** It only needs to keep evaluating. Don't test or tune it.
  - **Gate everything new to the vivobook** (my call). The Latitude is an always-on Tailscale/SSH box that still runs Plasma. It must not get Drive tokens or mounts, idle-suspend, mako, a second polkit agent, or lose its plasma-manager config.
  - **How:** split the home config into a shared base plus per-host imports, e.g. a `home/vivobook.nix` imported only by the vivobook. Keep the `plasma-manager` input and `home/plasma.nix`, but import them only for the Latitude.
  - This replaces the instruction in section 1 to delete them.
- **No fractional scaling and no global size bump.** Both monitors stay at scale 1. The user asked for better rendering, not bigger.
- Failure looks like this, even if every feature technically works: anything that reads as mismatched (navy, catppuccin, white GTK dialogs in the user's own tools), any KDE app reachable from Hyprland, or any setting that only works because of a manual tweak outside the repo.

## Hardware and environment facts

- ASUS Vivobook 16 (X1603ZA). Internal eDP-1 is 1920×1200 at about 141 DPI. External HDMI-A-1 is 1920×1080 at about 102 DPI. Both run at scale 1.
- Hyprland 0.56.2, configured in hyprlang (`configType = "hyprlang"`). Hyprlang is deprecated in favor of Lua. Stay on hyprlang for this project, and run `hyprctl configerrors` after each switch.
- Chrome profile `Default` is the parone.com profile (tushar.wani@parone.com).
- The flake already pins everything needed: vicinae 0.29, yazi 26.9.1, wifitui, bluetui, wiremix, gum, hypridle/hyprlock/hyprsunset, batsignal, tuigreet, rclone 1.75.1 and the fonts. See the research files for versions.

## Decisions by area

### 1. Remove KDE (user decision: remove Plasma and its apps completely)

- Drop `modules/desktop/plasma.nix` from the vivobook host's imports. For the vivobook only, stop importing `home/plasma.nix` and plasma-manager, and drop `kdePackages.kate`. See the Latitude note in "Non-goals".
- **Builder's call:** `modules/desktop/plasma.nix` may stay in the repo for the Latitude, as long as the Latitude still evaluates.
- **Replace what Plasma provided implicitly** (see `power.md`, section "What disappears"):
  - fonts
  - upower, power-profiles-daemon, udisks2, fwupd
  - `programs.fuse.enable`
  - a secret store: gnome-keyring, unlocked by PAM at login and wired to the Secret portal
  - a polkit agent: `hyprpolkitagent`. None runs today.
- **Login screen:** greetd + tuigreet, all black, launching Hyprland. SDDM goes away.
- **Before the first boot without SDDM**, the plan must tell the user to keep the previous generation in the boot menu and how to reach a TTY.
- **Screen sharing (Teams in Chrome) must keep working** through xdg-desktop-portal-hyprland. Verify it after the switch.

### 2. Fonts and text rendering (user decisions: Atkinson Hyperlegible Next + JetBrains Mono)

- **UI font: Atkinson Hyperlegible Next** (`atkinson-hyperlegible-next`; TrueType; the fontconfig family name is exactly that). Use it for the bar, mako, Vicinae, tuigreet where possible, and hyprlock.
- **System-wide sans-serif:** Atkinson Hyperlegible Next is fontconfig's default `sansSerif`, with Noto Sans as the fallback (my call). Plasma's Noto Sans default goes away anyway. Websites with their own fonts are unaffected. Calibrate against Atkinson.
- **Terminal font: JetBrains Mono.** It's built into Ghostty. Also install it system-wide and make it fontconfig's `monospace`.
- **Rendering recipe:** take `render.md`, corrected version, section A:
  - hinting `slight`, grayscale (`rgba none`)
  - `useEmbeddedBitmaps = false`
  - FreeType stem darkening through `FREETYPE_PROPERTIES`, using the lucidglyph 0.16 autofitter curve plus `cff:no-stem-darkening=0`
  - explicit Noto and emoji fallbacks, plus `nerd-fonts.symbols-only`
- **Calibrate on the real screens after switching.** Light text on pure black reads heavier, so be ready to switch to the milder curve. `render.md` section E has the knobs. Measure it; don't eyeball it from memory.
- Chrome, Slack and Discord ignore darkening. That's accepted.
- Bar text is 15px. That's the size the user approved in the mockup.

### 3. Pure-black theming

- **Palette** (from `theming.md`): bg `#000000`, raised `#121212`/`#1c1c1c`, borders `#262626`/`#333333`, dim `#5c5c5c`, muted `#a0a0a0`, text `#e6e6e6`.
- **Status colors** (my call):
  - amber `#f5a524` for attention: DND on, low battery
  - red `#ff8080` for live or critical: recording, mic live, critical battery
- **Builder's call:** whether to keep Vesper's peach accent inside terminal TUIs (herdr and yazi) or go fully greyscale. Any accent must look deliberate and stay consistent across tools.
- **Ghostty:** manage it with `programs.ghostty` (black background, `window-theme = dark`). Delete the stray `~/.config/ghostty/config.ghostty`; that's a manual step, so list it in the plan.
- **herdr:** `home/herdr.toml`, theme `vesper` with `[theme.custom]` panels set to black. This replaces catppuccin.
- **Hyprland:** black background (`misc.background_color` plus the existing `swaybg -c 000000`), grey borders, no logo or splash.
- **Terminal theme detection:** after Plasma is gone, Ghostty and herdr may report "light" to TUIs, which would flip yazi to its light theme (`theming.md` risks). Prevent it, then verify with `printf '\e[?996n'` from a herdr pane. You want `?997;1`. If `window-theme = dark` isn't enough, set the minimum `color-scheme = prefer-dark` that fixes it. This isn't app-wide dark-mode work.

### 4. Status bar (waybar): user-approved mockup "C"

- **Mockup:** the approved mockup is saved as `docs/superpowers/specs/2026-10-19-hyprland-polish-research/bar-mockup.html`. Open it in a browser and use variant C.
- **Wifi and Bluetooth** are icon only; the network or device name goes in the tooltip.
- **Bar on every monitor:** one bar per monitor, as today. Workspaces stay global, as in Hyprland's default.
- **Look:** pure black, Atkinson Hyperlegible Next at 15px, thin grey Lucide line icons (`pkgs.lucide`, always wrapped in a Pango `font_family` span; never list Lucide as a fallback font).
- **Left:** workspace numbers. Active is white, others are dim.
- **Center:** clock with the month number and seconds, e.g. `Fri 10/16 · 14:32:07`. Month first is my call. It ticks every second.
- **Right, in order** (my call):
  1. recording indicator: only while recording
  2. DND bell: only while DND is on, amber, with a count of hidden notifications
  3. mic
  4. brightness
  5. volume
  6. Bluetooth: only while a device is connected
  7. wifi
  8. battery icon + percentage
- **Numbers:** battery always shows its percentage.
  - **Volume and brightness (my call):** show their percentage in dim grey, so changes are visible without a popup. The user asked for changes to appear "in the top status bar".
  - If the plan finds a clean way to show the value only for a few seconds after a change, that's acceptable instead.
- **Mic (my call):**
  - Always present as a dim mic icon, so the user can mute before a call.
  - Turns red while any app is capturing.
  - Shows mic-off while muted.
  - Click toggles mute on the default source.
  - The tooltip names the capturing app(s).
- **Low battery:** the icon and number turn amber below 20% and red below 10%.
- **Clicks:**
  - wifi, Bluetooth and volume open their hub sections (see 7)
  - brightness scroll changes brightness
  - DND click toggles DND
  - recording click stops recording
- **Remove the tray and nm-applet.** Nothing that needs a tray remains once the TUIs replace nm-applet and blueman.
- **Fix the existing CSS bug:** the `#clock` selector should be `#custom-clock`.

### 5. Notifications (mako)

- **Look:** black banner, 1px `#333` border, UI font.
- **Never auto-dismiss:** `default-timeout = 0` and `ignore-timeout = 1`, so apps can't override it.
- **History:** kept. Super+N restores the last dismissed banner, and Super+Shift+N dismisses all. Those binds are my call.
- **DND (user decision: manual only, never automatic on mic use):**
  - Super+D or a click on the bell toggles it.
  - While on, banners are hidden, except critical ones (low battery). Hidden banners reappear when DND turns off.
  - Slack's and Discord's notification sounds are muted per stream, but Chrome isn't, so Teams keeps working.
  - Discord's call audio (`WEBRTC VoiceEngine`) is never muted.
  - The WirePlumber rule from `theming.md` §4 is required, so mutes don't persist after DND ends.
- Remove `mako` from `exec-once`. The home-manager service starts it.

### 6. Screenshots (user decision)

- Keep the same keys: Super+Shift+S for a region, Super+S and Print for the focused monitor.
- **Each capture:**
  1. Copied to the clipboard immediately.
  2. Saved to `~/ss/pics/screenshot-%Y%m%d-%H%M%S.png`. Saving is my call, so the file exists for later editing.
  3. Shows a banner with a thumbnail.
- **Clicking the banner** opens satty on that file. Satty does not open otherwise.
- The banner follows the never-auto-dismiss rule.
- With DND on, the banner is hidden but the copy and save still happen.
- Screen recording (`screenrec`) is unchanged.

### 7. Super+Space launcher: Vicinae (my call; the user's requirements)

Configure it with home-manager `programs.vicinae` (see `launcher.md`). It replaces wofi.

- **Apps.** No KDE apps appear, because KDE is gone.
- **Calculator:** inline, Enter copies the result.
- **File search:** indexes `$HOME` and excludes `/home/tushar/gdrive` (absolute path). Alias `f`.
- **Clipboard history:** text and images, alias `v`, also bound to Super+Shift+V. Super+V stays as togglefloating.
- **Ask Claude:** typing `c <prompt>` opens `https://claude.ai/new?q=<encoded>` in Chrome with `--profile-directory=Default`.
  - It's a script command, because quicklinks aren't declarative.
  - Also make it the no-match fallback if that works.
  - Test once whether `?q=` auto-sends the prompt, and tell the user what happens.
- **Look:** pure-black theme, UI font, no blur, layer-shell.
- **Hub entries:** the hub sections (wifi, Bluetooth, audio, auto-lock, power…) also appear as Vicinae entries.

### 8. Settings hub and system TUIs (user asked for an "umbrella TUI")

- **`hub`:** a small gum-based script (see `umbrella.md`) in a floating, centered black Ghostty window with one shared app-id. Super+A opens it (my call). `hub <section>` jumps directly to a section.
- **Sections:**
  - wifi → `wifitui` (NetworkManager)
  - bluetooth → `bluetui`
  - audio → `wiremix`
  - auto-lock → timeouts, on/off, caffeine 1h, reset to Nix defaults
  - night light → a full settings screen (user request). See "Night light settings" below.
  - brightness
  - power
  - displays → `hyprmon` (see 9b)
  - services → `systemd-manager-tui`
- **Battery charge limit:** from `umbrella.md`. Optional, builder's call. Default is no limit unless the plan finds it trivial and safe on this ASUS.
- **Remove** `nm-applet`, `networkmanagerapplet`, `blueman`, `pavucontrol` and `nwg-displays`.
- **Night light settings:**
  - **Settings that persist:** on/off, start time, end time and temperature in K. They survive reboots and `nixos-switch`.
  - **Preview:** each temperature step is applied live through `hyprctl hyprsunset temperature` while you adjust it. Saving persists the value and restarts hyprsunset.
  - **Quick actions:** "off until tomorrow" and "warm now", which are temporary, plus "reset to Nix defaults".
  - **How it persists:** the same pattern as auto-lock. Nix owns the defaults (4000K, 20:30–07:00). The hub writes a mutable file under `~/.local/state/hyprsunset/`.
    - `source` support in hyprsunset is unverified. If it doesn't work, use a small wrapper as the service's ExecStart instead: it runs `hyprsunset -c <state file>` when that file exists, and the Nix-generated config otherwise.
  - **Validation:** times must be HH:MM, and the temperature must stay within 1000–6500K.
- **Runtime settings vs. Nix:**
  - Nix owns the defaults and structure.
  - The hub writes only under `~/.local/state/`:
    - `hypridle/{overrides.conf,off}`, which hypridle `source`s after the Nix defaults
    - `hyprsunset/`, the night light settings
  - "Reset" empties the overrides file.
  - Validate input: a non-integer value silently drops that listener.

### 9. Lock, idle, power

- **Idle defaults** (my call; changeable from the hub):
  - lock at 5 min
  - screen off at 5.5 min
  - suspend at 30 min, on battery only if that's easy, otherwise always
- **Lock before every suspend and on lid close.**
- **hyprlock:** pure black, a clock and a password field in the UI font, nothing else. My call.
- **Power button:**
  - logind ignores a short press (a long press still powers off).
  - A short press opens the power menu: a floating black single-key screen (`l` lock, `s` suspend, `e` log out, `r` reboot, `p` power off). Log out, reboot and power off ask y/N first.
  - The same menu is the hub's power section, and Super+Escape opens it too.
  - Check with `wev` whether the button sends duplicate events.
- **Low battery** (user approved): banner at 20%, critical banner at 10%, suspend at 5% (batsignal).
- **Night light:** hyprsunset, 4000K from 20:30 to 07:00 by default (my call). Changeable in the hub's night light screen (section 8).

### 9b. Lid and monitors (user decisions)

- **Lid closed, HDMI connected:** the laptop screen (eDP-1) turns off, and work continues on the external monitor. No lock, no suspend.
- **Lid closed, nothing connected:** lock, then suspend.
- **Lid opened:** eDP-1 comes back in its nwg-displays position.
- **Suggested wiring:**
  - logind's defaults already suspend undocked and ignore the lid when docked. Set `HandleLidSwitch = "suspend"` and `HandleLidSwitchDocked = "ignore"` explicitly anyway, since Plasma no longer covers it.
  - A Hyprland `bindl = , switch:on:Lid Switch` disables eDP-1. `switch:off` runs `hyprctl reload`, so the position comes from `monitors.conf` rather than being hard-coded.
  - hypridle's `before_sleep_cmd` provides the lock.
- **The monitor layout stays mutable** in `~/.config/hypr/monitors.conf`, sourced after the `,preferred,auto,1` wildcard. It's the one sanctioned piece of state outside the repo.
- **hyprmon replaces nwg-displays** as its editor (my call; the user asked for a TUI alternative). hyprmon is a TUI that shows the monitors as boxes you drag around, with live apply and profiles; nixpkgs has `hyprmon` 0.0.17.
  - **Write target:** hyprmon writes to `$HYPRLAND_CONFIG`, or by default to `hyprland.conf`. `hyprland.conf` is a read-only home-manager symlink, so wrap hyprmon with `HYPRLAND_CONFIG=$HOME/.config/hypr/monitors.conf`.
  - **Check before relying on it:** does hyprmon only rewrite the `monitor=` lines in that file, and does it cope with the file being sourced instead of being the main config? If it can't be pointed safely at `monitors.conf`, tell the user and keep nwg-displays.
  - **Hub:** add a "displays" section that opens hyprmon.
  - **Migration:** the current `monitors.conf` was written by nwg-displays and has an odd x=0 gap. hyprmon may rewrite it on first save. That's fine.

### 10. Media keys

- Play/pause/next/previous go through playerctl (playerctld picks the last active player) and work while locked.
- Each press updates one banner, which replaces itself (`notify-send -r`): app name, played or paused, title and artist.
- **Conflict for the builder:** the research suggested a 2.5s timeout, but that conflicts with "never auto-dismiss" and `ignore-timeout`. Resolve it by keeping a single self-replacing banner that never expires, unless the plan finds that annoying in testing. In that case, raise it with the user rather than silently adding a timeout.

### 11. yazi (the only file explorer)

- `programs.yazi` with a pure-black theme.
- Image, PDF and video previews in the preview pane. They already work in Ghostty, and inside herdr through kitty graphics (known issue: stretched aspect ratio inside herdr, herdr#4858; accepted).
- **Space opens a full-screen quick look:**
  - images in imv
  - PDFs in zathura (black, recolored)
  - video and audio in mpv
  - Space or `q` closes it.
- Selection moves to `i` (my call).
- **gdrive safeguards:**
  - mime-ext plugin
  - no preloaders under `~/gdrive`
  - `~/.ignore` containing `/gdrive/` so rg/fd/Vicinae don't crawl and download Drive

### 12. Google Drive (user decisions)

**Accounts:** `reachtusharwani@gmail.com` → `~/gdrive/personal`, and `tusharstudydocs@gmail.com` → `~/gdrive/study`. Folder names are my call.

**Semantics required by the user:**
- Files are listed, but nothing downloads until opened.
- Edits upload back.
- A delete on either side propagates, including for never-downloaded files. Local deletes go to Drive trash.
- Unmounting or removing an account never deletes anything on Drive.

**How:** rclone mount, `--vfs-cache-mode full`, through home-manager `programs.rclone` (see `gdrive.md`).
- Each account's tokens and the OAuth client secret are agenix-encrypted.
- Google Docs appear as `.link.html` files that open in the browser.

**The user has to do the one-time manual steps** in `gdrive.md`: create a Google Cloud OAuth client and publish it, run `rclone authorize` once per account, and create the agenix secrets. The plan must stop and hand these to the user, then continue.

Never point Syncthing or any backup or sync tool at `~/gdrive`.

### 13. Clipboard history

Provided by Vicinae (section 7). No separate cliphist.

## Order of work (builder may adjust)

1. Session plumbing and KDE removal: greetd, keyring, polkit agent, implicit services, fuse.
2. Fonts and rendering, then calibration.
3. Theming: Ghostty, herdr, Hyprland frame, mako look.
4. Waybar.
5. Vicinae.
6. Hub, TUIs, idle/lock/power, night light, battery.
7. DND, screenshots, media keys.
8. yazi.
9. Google Drive. This step is blocked on the user's manual OAuth steps.

Each step should be its own `nixos-switch` with a quick verification. `nixos-switch` commits and pushes automatically.

## Left to the builder

- Module and file layout. A new `home/` file per area (e.g. `home/waybar.nix`, `home/hub.nix`, `home/rclone.nix`) and `modules/desktop/session.nix` + `fonts.nix` fit the repo's style.
- Exact Lucide codepoints, spacing and padding, within the approved mockup's look.
- Exact gum/fzf menu styling in the hub.
- Whether hub sections focus an existing window or open a new one.
- How to verify each step (configerrors, `fc-match`, `systemctl --user status`, and so on).

## Known risks (details in the research files)

- **Removing Plasma:** the Chrome and Slack secret store may need a re-login. Export anything in kwallet first, if anything matters there.
- **Power button:** may send duplicate key events.
- **`hyprctl dispatch dpms` syntax:** may have changed under 0.56 (Lua era). Test it by hand.
- **Stem darkening strength:** needs on-screen tuning.
- **Vicinae:** script-symlink and fallback quirks.
- **rclone:** offline-at-login and resume behavior are untested.
