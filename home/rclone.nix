# Google Drive, on demand: each account is a live rclone mount. Files are
# listed but only downloaded when opened; edits upload back; deletes go both
# ways (local deletes land in Drive's trash); unmounting never touches Drive.
# Research: docs/superpowers/specs/2026-10-19-hyprland-polish-research/gdrive.md
{ config, lib, osConfig, ... }:
let
  home = config.home.homeDirectory;
  accounts = {
    personal = "reachtusharwani@gmail.com";
    study = "tusharstudydocs@gmail.com";
  };
  secret = name: osConfig.age.secrets.${name}.path;
  forAccounts = f: lib.mapAttrs' (acct: _: f acct) accounts;
in
{
  programs.rclone = {
    enable = true;
    remotes = forAccounts (acct: lib.nameValuePair "gdrive-${acct}" {
      config = {
        type = "drive";
        scope = "drive";
        client_id = "865497463494-j3etfft05q30c7ut6vajtsj0ug6cckot.apps.googleusercontent.com";
        use_trash = true;             # local rm -> Drive trash (30-day undo)
        export_formats = "link.html"; # Google Docs show up as links that open in the browser
        skip_dangling_shortcuts = true;
      };
      secrets = {
        client_secret = secret "rclone-gdrive-client-secret";
        token = secret "rclone-gdrive-${acct}-token";
      };
      mounts."" = { # "" = all of My Drive
        enable = true;
        mountPoint = "${home}/gdrive/${acct}";
        options = { # vfs-cache-mode=full and cache-dir come from the module
          dir-cache-time = "1000h";   # safe: Drive change polling invalidates entries
          poll-interval = "15s";      # changes made on the web show up within ~15s
          # Opened files are cached locally and evicted automatically once
          # they have not been accessed for 90 days (or when the cache passes
          # 10G, oldest first). Eviction only frees local disk; Drive keeps
          # the file.
          vfs-cache-max-age = "2160h";
          vfs-cache-max-size = "10G";
          vfs-cache-min-free-space = "20G";
        };
      };
    });
  };

  # Keep retrying if offline at login, and clear a stale FUSE mount after a crash.
  systemd.user.services = forAccounts (acct: lib.nameValuePair "rclone-mount:@gdrive-${acct}" {
    Unit.StartLimitIntervalSec = 0;
    Service = {
      RestartSec = 15;
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${home}/gdrive/${acct}";
    };
  });

  # nvim: overwrite files in place so saves keep the same Drive file (history,
  # sharing), and keep backup files out of the synced folder.
  programs.nixvim.opts = {
    backupcopy = "yes";
    backupdir = [ "${config.xdg.stateHome}/nvim/backup//" ];
  };
}
