# yazi: the file explorer. Space opens a full-screen quick look (ql);
# selection moves to `i`. Pure black, and careful not to download Drive
# files just by browsing ~/gdrive.
{ pkgs, config, ... }:
let
  gdrive = "${config.home.homeDirectory}/gdrive/**";
  ql = pkgs.writeShellApplication {
    name = "ql";
    runtimeInputs = with pkgs; [ file imv zathura mpv ];
    text = builtins.readFile ./scripts/ql.sh;
  };
in
{
  home.packages = [ ql ];

  # Auto-mount plugged-in drives at /run/media/<user>/<label> (`g m` in yazi).
  services.udiskie = { enable = true; tray = "never"; };

  programs.yazi = {
    enable = true; # shell wrapper `y` cds to the last directory on exit
    plugins.mime-ext = pkgs.yaziPlugins.mime-ext;
    # Guess file types from extensions instead of reading file contents,
    # which would partly download every file listed on the Drive mount.
    initLua = ''require("mime-ext"):setup()'';

    settings = {
      mgr = { show_hidden = true; sort_dir_first = true; };
      preview = { max_width = 1920; max_height = 1200; };
      # No background preloading (thumbnails etc.) on the Drive mount.
      plugin.prepend_preloaders = [{ url = gdrive; run = "noop"; }];
    };

    keymap.mgr.prepend_keymap = [
      { on = "<Space>"; run = "shell --orphan -- ql %h"; desc = "Quick look (full screen)"; }
      { on = "i"; run = [ "toggle" "arrow 1" ]; desc = "Toggle selection"; }
      { on = [ "g" "m" ]; run = "cd /run/media/${config.home.username}"; desc = "Go to mounted drives"; }
    ];

    theme = {
      app.overall.bg = "#000000";
      mgr = {
        cwd.fg = "#e6e6e6";
        border_style.fg = "#262626";
      };
      indicator = {
        current = { bg = "#1c1c1c"; bold = true; };
        parent.bg = "#121212";
      };
      tabs = {
        active = { fg = "#000000"; bg = "#e6e6e6"; bold = true; };
        inactive = { fg = "#a0a0a0"; bg = "#121212"; };
      };
      mode = {
        normal_main = { fg = "#000000"; bg = "#e6e6e6"; bold = true; };
        normal_alt = { fg = "#e6e6e6"; bg = "#121212"; };
        select_main = { fg = "#000000"; bg = "#f5a524"; bold = true; };
        select_alt = { fg = "#f5a524"; bg = "#121212"; };
        unset_main = { fg = "#000000"; bg = "#ff8080"; bold = true; };
        unset_alt = { fg = "#ff8080"; bg = "#121212"; };
      };
      status.progress_normal = { fg = "#e6e6e6"; bg = "#121212"; };
      which.border.fg = "#262626";
    };
  };

  # Quick-look viewers, black and closable with Space or q.
  programs.imv = {
    enable = true;
    settings.options.background = "000000";
    settings.binds."<space>" = "quit";
  };
  programs.zathura = {
    enable = true;
    options = {
      default-bg = "#000000";
      statusbar-bg = "#000000";
      inputbar-bg = "#000000";
      completion-bg = "#000000";
      recolor = true; # Ctrl+R toggles
      recolor-keephue = true;
      recolor-lightcolor = "#000000";
      recolor-darkcolor = "#e6e6e6";
    };
    mappings."<Space>" = "quit";
  };
  programs.mpv = {
    enable = true;
    bindings.SPACE = "cycle pause"; # keep Space as play/pause in video
  };
}
