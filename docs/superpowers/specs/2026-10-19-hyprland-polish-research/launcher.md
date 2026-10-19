# launcher
## summary
Use Vicinae as the Super+Space launcher. Everything you need is already in your pinned inputs, so no new flake input is required: nixpkgs has vicinae 0.29.0 (upstream is at 0.29.1), and your pinned home-manager has the `programs.vicinae` module with a systemd service, settings, themes and extensions. I built the binary, printed its default config, and read the source at commit cfa98be.

How each must-have is covered:
- **Apps:** built in. The KDE Settings source only loads when Plasma is the running desktop.
- **Calculator:** built in.
- **Clipboard history:** built in, text and images.
- **File search:** built in, and it has an "Excluded search paths" setting (`excludedIndexingPaths`) for `/home/tushar/gdrive`.
- **"c <query>" for Claude:** quicklinks are stored in a file Vicinae rewrites as you use them, so they can't be declarative. A script command can, and it calls Chrome with `--profile-directory=Default` directly. Give it the alias "c": typing `c` then space jumps to its input box.
- **Pure black:** done with a theme file in TOML.
- **Umbrella for system TUIs:** script commands open the TUIs in Ghostty. Vicinae also has built-in lock, suspend, reboot and power-off commands (lock goes through systemd's login service, which hypridle listens for), media controls, and a `vicinae dmenu` mode that can serve as the power menu.

Walker 2.x (with its elephant backend) also works, but it has fewer built-ins and no direct way to open a specific Chrome profile.
## recommendation
### 1. home/hyprland.nix: replace wofi with Vicinae

```nix
{ pkgs, lib, config, ... }:
let
  home = config.home.homeDirectory;
  chrome = "${pkgs.google-chrome}/bin/google-chrome-stable";
  setsid = "${pkgs.util-linux}/bin/setsid";
  # Open a TUI in its own Ghostty window. Hyprland floats it by window class (see below).
  tui = cmd: ''${setsid} -f ghostty --class=tui.float -e ${cmd} >/dev/null 2>&1'';

  # Each script is a real file in one store directory, not a symlink. That avoids issue #1331,
  # and Vicinae kills "silent" scripts after 10s, so everything launched uses setsid -f.
  scripts = {
    ask-claude = ''
      #!${pkgs.bash}/bin/bash
      # @vicinae.schemaVersion 1
      # @vicinae.title Ask Claude
      # @vicinae.mode silent
      # @vicinae.icon 🤖
      # @vicinae.keywords ["claude", "ai"]
      # @vicinae.argument1 { "type": "text", "placeholder": "prompt", "percentEncoded": true }
      ${setsid} -f ${chrome} --profile-directory=Default "https://claude.ai/new?q=$1" >/dev/null 2>&1
      echo "Asked Claude"
    '';
    wifi = ''
      #!${pkgs.bash}/bin/bash
      # @vicinae.schemaVersion 1
      # @vicinae.title Wi-Fi
      # @vicinae.mode silent
      # @vicinae.keywords ["network", "tui"]
      ${tui "${pkgs.wifitui}/bin/wifitui"}
    '';
    bluetooth = ''
      #!${pkgs.bash}/bin/bash
      # @vicinae.schemaVersion 1
      # @vicinae.title Bluetooth
      # @vicinae.mode silent
      # @vicinae.keywords ["bt", "tui"]
      ${tui "${pkgs.bluetui}/bin/bluetui"}
    '';
    audio = ''
      #!${pkgs.bash}/bin/bash
      # @vicinae.schemaVersion 1
      # @vicinae.title Audio Mixer
      # @vicinae.mode silent
      # @vicinae.keywords ["sound", "volume", "mic", "tui"]
      ${tui "${pkgs.wiremix}/bin/wiremix"}
    '';
    # Add a "lock-settings" script here once the auto-lock TUI exists.
  };
  scriptDir = pkgs.runCommandLocal "vicinae-scripts" { } (''
    mkdir -p $out
  '' + lib.concatStrings (lib.mapAttrsToList (n: t: ''
    install -m755 ${pkgs.writeText n t} $out/${n}
  '') scripts));
in {
  # Remove the old launcher: delete `programs.wofi.enable = true;`

  programs.vicinae = {
    enable = true;                 # package defaults to pkgs.vicinae (0.29.0)
    systemd.enable = true;         # user service `vicinae server`, starts with graphical-session.target
    enableMutableConfig = true;    # Nix settings go to home-manager.json via VICINAE_OVERRIDES;
                                   # settings.json stays writable so the settings window still works
    enableFirefoxIntegration = false;

    themes.pure-black = {
      meta = { version = 1; name = "Pure Black"; description = "#000 everything";
               variant = "dark"; inherits = "vicinae-dark"; };
      colors = {
        core = { background = "#000000"; foreground = "#E6E6E6"; secondary_background = "#000000";
                 border = "#1F1F1F"; accent = "#E6E6E6"; accent_foreground = "#000000"; };
        main_window = { border = "#262626"; footer.background = "#000000"; };
        settings_window.border = "#262626";
        text = { muted = "#8A8A8A"; placeholder = "#555555";
                 selection = { background = "#E6E6E6"; foreground = "#000000"; }; };
        input = { border = "#1F1F1F"; border_focus = "#555555"; };
        list.item.selection = { background = "#161616"; secondary_background = "#161616";
                                foreground = "#FFFFFF"; secondary_foreground = "#FFFFFF"; };
        grid.item.background = "#0A0A0A";
        scrollbars.background = "#1F1F1F";
        loading = { bar = "#E6E6E6"; spinner = "#E6E6E6"; };
      };
    };

    settings = {
      # Set light and dark to the same theme. Dark mode isn't being pushed to apps,
      # so Vicinae may decide the system is in "light" mode.
      theme = { light.name = "pure-black"; dark.name = "pure-black"; };
      font = {
        rendering = "native";      # Linux default is "qt" (distance-field). "native" renders through
                                   # fontconfig like every other app; safe because both screens are scale 1
        normal.family = "auto";    # bundled Inter; set to whatever the font research picks
      };
      launcher_window = {
        opacity = 1.0;
        material = "none";         # no blur or liquid glass, solid black
        rounding = 6;              # matches decoration.rounding
        client_side_decorations = { enabled = true; border_width = 1; shadow_size = 0; };
        layer_shell = { enabled = true; keyboard_interactivity = "exclusive"; layer = "top"; };
      };
      escape_key_behavior = "close_window";
      pop_to_root_on_close = true;
      tray.enabled = false;
      search_files_in_root = false;   # use the "f" alias for file search instead
      telemetry.system_info = false;
      favorites = [ "clipboard:history" ];
      fallbacks = [ "scripts:ask-claude" "files:search" ];  # no match found -> offer "Ask Claude"
      providers = {
        files.preferences = {
          autoIndexing = true;
          indexingPaths = [ home ];
          excludedIndexingPaths = [ "${home}/gdrive" ];  # absolute path; "~" is NOT expanded
        };
        files.entrypoints.search.alias = "f";
        clipboard.entrypoints.history.alias = "v";
        scripts.preferences.customDirs = [ "${scriptDir}" ];
        scripts.entrypoints."ask-claude".alias = "c";   # type "c", then space, then the prompt
        # To hide a leftover app: applications.entrypoints."<desktop-id-without-.desktop>".enabled = false;
      };
    };
  };

  wayland.windowManager.hyprland.settings = {
    bind = [
      "$mod, SPACE, exec, vicinae toggle"
      "$mod SHIFT, V, exec, vicinae deeplink vicinae://launch/clipboard/history"
    ];
    layerrule = [ "no_anim on, match:namespace vicinae" ];   # Hyprland 0.53+ rule syntax (you run 0.56.2)
    windowrule = [ "float on, size 1000 650, center on, match:class ^(tui\\.float)$" ];
  };
}
```

### 2. How it runs
- The home-manager user service starts `vicinae server` and is tied to graphical-session.target. Home-manager's Hyprland setup activates that target, so there is no `exec-once` to add.
- The service restarts whenever the settings, themes or extensions change.
- Your user session already exports `PATH` and `XDG_DATA_DIRS` to systemd (checked with `systemctl --user show-environment`), so app discovery works.
- Each home-manager activation runs `vicinae deeplink vicinae://launch/core/refresh-apps`, so the app list picks up packages that were added or removed.

### 3. Power menu / power button
Vicinae already has `power:lock`, `suspend`, `reboot`, `power-off` and `logout` commands. For the laptop's power button:
- Set `services.logind.settings.Login.HandlePowerKey = "ignore"`. Check the option name against your nixpkgs; older releases call it `services.logind.powerKey`.
- Bind `bindl = , XF86PowerOff, exec, powermenu`, where `powermenu` is a small script:

```sh
case "$(printf 'Lock\nSuspend\nReboot\nPower off' | vicinae dmenu -p Power)" in
  Lock) loginctl lock-session ;;
  Suspend) systemctl suspend ;;
  Reboot) systemctl reboot ;;
  "Power off") systemctl poweroff ;;
esac
```

### 4. Media keys
Vicinae has built-in play-pause, next, previous and now-playing commands. For the media keys themselves, playerctl bound in Hyprland is still the simpler choice.
## alternatives
**Walker 2.17.1 + elephant 2.22.0** (both in your nixpkgs; your home-manager has `services.walker` and `services.elephant`):
- Theming is GTK4 CSS, so pure black is easy.
- It has providers for apps, calculator, clipboard (text and images) and files. Files uses `fd`, and gdrive can be excluded with `ignored_dirs = ["/home/tushar/gdrive"]`.
- Its websearch uses `url = ".../?q=%TERM%"` entries with prefixes, but opens them in the default browser. A specific Chrome profile would need a custom Lua menu entry.
- elephant "menus" could also serve as the umbrella.
- It needs two daemons, has a smaller community (about 3k stars vs 10k), and lacks Vicinae's Raycast extension support, built-in power/media/window commands, and dmenu mode.

**Other ways to do "c <query>" in Vicinae:**
- A Shortcut (Vicinae's version of a Raycast quicklink) can open a URL with a `{argument}` placeholder in a chosen app. Add a custom desktop entry with `xdg.desktopEntries.chrome-default = { name = "Chrome (Default)"; exec = "google-chrome-stable --profile-directory=Default %U"; }`, then create the shortcut in the GUI. It can't be declarative because shortcuts live in `~/.local/share/vicinae/shortcuts/shortcuts.json`, which Vicinae rewrites to track opens.
- A Raycast-style TS extension through `config.lib.vicinae.mkExtension` would also work, but it's more than this needs.

**Scripts directory:** instead of `customDirs`, scripts could go in `xdg.dataFile."vicinae/scripts/<name>"` with `executable = true`. That's simpler, but those are symlinks and exposed to issue #1331.
## risks
- **claude.ai `?q=`:** only third-party pages document it (u2l.ai, getdrafts, popclip). I found no official Anthropic page. Reports say it pre-fills the prompt and, on most platforms, auto-sends it. Test once before relying on it, and keep in mind a stray "c ..." could send right away. Prompts over about 2000 characters may be truncated.
- **Script symlinks:** issue #1331 (still open) says Vicinae skips symlinked scripts, which is how home-manager links files. The 0.29 scanner code follows symlinks and a commenter says it works now, but I avoided the question by using `customDirs` pointing at a store directory of real executable files.
- **Silent scripts are killed after 10s** (`QTimer` in script-actions.cpp). Anything they launch must be detached, so I used `setsid -f`. Silent mode's small confirmation pop-up only works with layer shell, which is on by default.
- **`/bin/bash` doesn't exist on NixOS.** `vicinae script template` writes `@vicinae.exec ["/bin/bash"]`, so I used absolute store paths in the shebangs instead.
- **`c` + space depends on the aliased item being selected.** The code jumps into the argument field only when the alias exactly matches the query and that item is highlighted. Aliased items are ranked first, but a different item with alias "c" could compete.
- **Script fallback is unconfirmed.** Docs only promise fallback support for shortcuts with one argument. Putting `scripts:ask-claude` in `fallbacks` should work (the script appears in the fallback settings according to #1331), but I haven't tested it.
- **The gdrive exclusion is an exact path match** on the directory, and `~` is not expanded, so use the absolute path. Without the exclusion the indexer would crawl the rclone FUSE mount, because I found no "stay on one filesystem" check. The first full scan of $HOME uses a lot of CPU.
- **Preference key names come from source, not docs:** `excludedIndexingPaths`, `customDirs`, the `scripts`/`files`/`clipboard`/`applications` provider ids, and `font.rendering`. If a key is rejected, confirm it in the settings window (Ctrl+'), which writes the real keys to settings.json.
- **Theme selection:** Vicinae uses the light or dark theme depending on system appearance, which is why both point at pure-black. Any theme color I didn't set is inherited from vicinae-dark.
- **`keyboard_interactivity = "exclusive"`** is known to break mouse clicks on popups in Hyprland, and with it `close_on_focus_loss` does nothing. That's fine for keyboard use; switch to `on_demand` if mouse use matters.
- **Vicinae's own global shortcut** needs the ext-hotkey-v1 protocol, which mainline Hyprland lacks, so the Hyprland bind is required.
- **Terminal-mode scripts:** Vicinae picks the terminal from xdg-terminals.list, which it ignores when it's a symlink (#2062). It then falls back to the first installed terminal app. That's why the scripts call `ghostty --class=...` directly. The `--class` value must contain a dot to be a valid GTK app id.
- **The windowrule/layerrule syntax** is the 0.53+ anonymous form. Run `hyprctl configerrors` after switching.
- **wifitui and bluetui** are in nixpkgs (0.13.0 and 0.8.1). impala needs iwd and you run NetworkManager, so I left it out.
- **Other open issues:** #341 (startup exception under systemd on Hyprland, old), #1241 (app list stale until refresh; the activation hook handles it), and #2045 (soulver calculator crash; the default calculator backend is numen, so this doesn't apply).
- **Icons:** with no icon theme installed, app icons fall back to hicolor. That's harmless.
## sources
https://github.com/vicinaehq/vicinae (source read at commit cfa98be, 2026-10-18; src/server/src/builtins/file/file-extension.hpp, services/files-service/file-preferences.hpp, root-search/scripts/script-root-provider.hpp, script/script-actions.cpp, builtins/root/root-view-host.cpp, config/config.hpp, server.cpp)
https://github.com/vicinaehq/docs (src/app/scripts/directives, scripts/arguments, scripts/modes, file-search, shortcuts, config, nixos, quickstart/hyprland, theming/getting-started)
https://docs.vicinae.com/scripts/getting-started
https://docs.vicinae.com/quickstart/hyprland
https://docs.vicinae.com/nixos
https://github.com/vicinaehq/vicinae/issues/1331
https://github.com/vicinaehq/vicinae/issues/2062
https://github.com/vicinaehq/vicinae/issues/1241
https://github.com/vicinaehq/vicinae/issues/341
home-manager pinned source: /nix/store/40h4dglabpdbvbx535xgfz3ifiz49cz6-source/modules/programs/vicinae/default.nix (rev aa23f720)
Local: `vicinae config default`, `vicinae theme template`, `vicinae script check` on vicinae-0.29.0 from pinned nixpkgs
https://u2l.ai/tools/claude-prompt-link-generator (claude.ai/new?q= behaviour, unofficial)
https://github.com/abenz1267/elephant (websearch/files provider READMEs)
https://github.com/abenz1267/walker