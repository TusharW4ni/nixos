# Super+Space launcher: apps, calculator, file search (f), clipboard
# history (v), and "ask Claude" (c <prompt>) in the parone Chrome profile.
# Research notes: docs/superpowers/specs/2026-10-19-hyprland-polish-research/launcher.md
{ pkgs, lib, config, ... }:
let
  home = config.home.homeDirectory;
  setsid = "${pkgs.util-linux}/bin/setsid";
  chrome = "${pkgs.google-chrome}/bin/google-chrome-stable";

  # Vicinae script commands. Built as real files in one store directory
  # (Vicinae has skipped symlinked scripts, issue #1331). "silent" scripts get
  # killed after 10s, so anything they start is detached with setsid.
  scripts = {
    ask-claude = ''
      #!${pkgs.bash}/bin/bash
      # @vicinae.schemaVersion 1
      # @vicinae.title Ask Claude
      # @vicinae.mode silent
      # @vicinae.keywords ["claude", "ai"]
      # @vicinae.argument1 { "type": "text", "placeholder": "prompt", "percentEncoded": true }
      ${setsid} -f ${chrome} --profile-directory=Default "https://claude.ai/new?q=$1" >/dev/null 2>&1
      echo "Asked Claude"
    '';
  } // config.vicinaeScripts;

  scriptDir = pkgs.runCommandLocal "vicinae-scripts" { } (''
    mkdir -p $out
  '' + lib.concatStrings (lib.mapAttrsToList (n: text: ''
    install -m755 ${pkgs.writeText n text} $out/${n}
  '') scripts));
in
{
  # Other modules (the settings hub) add their own script commands here.
  options.vicinaeScripts = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = "Extra Vicinae script commands, name -> script text.";
  };

  config = {
    programs.vicinae = {
      enable = true;
      systemd.enable = true;
      enableFirefoxIntegration = false;

      themes.pure-black = {
        meta = {
          version = 1;
          name = "Pure Black";
          description = "#000 everything";
          variant = "dark";
          inherits = "vicinae-dark";
        };
        colors = {
          core = {
            background = "#000000";
            foreground = "#E6E6E6";
            secondary_background = "#000000";
            border = "#1C1C1C";
            accent = "#E6E6E6";
            accent_foreground = "#000000";
          };
          main_window = { border = "#262626"; footer.background = "#000000"; };
          settings_window.border = "#262626";
          text = {
            muted = "#A0A0A0";
            placeholder = "#5C5C5C";
            selection = { background = "#E6E6E6"; foreground = "#000000"; };
          };
          input = { border = "#1C1C1C"; border_focus = "#5C5C5C"; };
          list.item.selection = {
            background = "#1C1C1C";
            secondary_background = "#1C1C1C";
            foreground = "#FFFFFF";
            secondary_foreground = "#FFFFFF";
          };
          grid.item.background = "#121212";
          scrollbars.background = "#262626";
          loading = { bar = "#E6E6E6"; spinner = "#E6E6E6"; };
        };
      };

      settings = {
        # Same theme for both: dark mode isn't propagated system-wide, so
        # Vicinae may think the system is "light".
        theme = { light.name = "pure-black"; dark.name = "pure-black"; };
        font = {
          rendering = "native"; # fontconfig rendering, like everything else
          normal.family = "Atkinson Hyperlegible Next";
        };
        launcher_window = {
          opacity = 1.0;
          material = "none";
          rounding = 6;
          client_side_decorations = { enabled = true; border_width = 1; shadow_size = 0; };
          layer_shell = { enabled = true; keyboard_interactivity = "exclusive"; layer = "top"; };
        };
        escape_key_behavior = "close_window";
        pop_to_root_on_close = true;
        tray.enabled = false;
        search_files_in_root = false; # file search lives behind the "f" alias
        telemetry.system_info = false;
        favorites = [ "clipboard:history" ];
        fallbacks = [ "scripts:ask-claude" "files:search" ];
        providers = {
          files.preferences = {
            autoIndexing = true;
            indexingPaths = [ home ];
            # rclone network mount: indexing it would download the whole Drive.
            excludedIndexingPaths = [ "${home}/gdrive" ];
          };
          files.entrypoints.search.alias = "f";
          clipboard.entrypoints.history.alias = "v";
          scripts.preferences.customDirs = [ "${scriptDir}" ];
          scripts.entrypoints."ask-claude".alias = "c";
        };
      };
    };

    # Keep rg/fd (and anything else honoring ~/.ignore) out of the Drive mount.
    home.file.".ignore".text = "/gdrive/\n";
  };
}
