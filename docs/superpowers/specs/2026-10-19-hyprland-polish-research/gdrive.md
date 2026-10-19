# gdrive
## summary
Use `rclone mount` with `--vfs-cache-mode full`, one mount per account (~/gdrive/personal and ~/gdrive/study), through home-manager's `programs.rclone.remotes.<name>.mounts`. This works with the pinned home-manager and rclone 1.75.1: I evaluated the snippet below against your flake and the units render. It covers what you asked for:
- Files are listed but only downloaded when opened, then kept in a local cache.
- Edits upload about 5s after the file is closed.
- `rm` on the mount moves the file to Drive's trash (`use_trash=true`, the default), even for files never downloaded.
- Deletes on Drive's website show up locally within the poll interval (15s).
- A mount is a live view, not a sync, so unmounting, stopping the service or removing an account can never delete anything on Drive.

You have to create your own Google OAuth client. The pinned rclone docs say rclone's shared client "is being retired and will stop working during 2026". Set the client to "In production" (it can stay unverified) so the login doesn't expire after 7 days.

Tokens: each account's token JSON is stored with agenix (owner tushar). home-manager's `rclone-config` service rebuilds a writable `~/.config/rclone/rclone.conf` from it at every login. rclone refreshes the access token in that file while running; the stored refresh token is long-lived, so overwriting the file at login is harmless. I tested the secret injection locally with rclone 1.75.1: it exits 0 and makes no network calls.

Google Docs are shown as small `.link.html` files that open the doc in your browser. The normal docx export shows as 0 bytes on a mount and often fails to open.

The real risks are tools that read every file and so download your whole Drive: yazi previews and type detection, and `rg`/`fd` run from ~. Settings to stop that are below.
## recommendation
## 1. secrets/secrets.nix (add)
```nix
  "rclone-gdrive-client-secret.age".publicKeys = [ tushar ];
  "rclone-gdrive-personal-token.age".publicKeys = [ tushar ];  # reachtusharwani@gmail.com
  "rclone-gdrive-study-token.age".publicKeys    = [ tushar ];  # tusharstudydocs@gmail.com
```

## 2. modules/system/secrets.nix (add; change the args to `{ config, lib, ... }`)
```nix
  # rclone reads these as tushar from the rclone-config user service (home/rclone.nix).
  age.secrets = lib.genAttrs
    [ "rclone-gdrive-client-secret" "rclone-gdrive-personal-token" "rclone-gdrive-study-token" ]
    (n: { file = ../../secrets/${n}.age; owner = "tushar"; group = "users"; mode = "0400"; });
```
Note: if you already have `age.secrets.tushar-pw...` as dotted attrs in the same file, Nix merges them fine.

## 3. NixOS: FUSE
Right now the fusermount/fusermount3 setuid wrappers only exist because plasma6.nix and xdg portal turn on `programs.fuse.enable`. Set it yourself so removing Plasma can't break the mounts:
```nix
programs.fuse.enable = true;   # userAllowOther NOT needed (we don't use --allow-other)
```

## 4. home/rclone.nix (new; add `./rclone.nix` to imports in home/tushar.nix). I evaluated this against the pinned flake.
```nix
{ config, lib, osConfig, ... }:
let
  home = config.home.homeDirectory;
  accounts = [ "personal" "study" ];
  secret = n: osConfig.age.secrets.${n}.path;
  forAccounts = f: lib.listToAttrs (map f accounts);
in
{
  programs.rclone = {
    enable = true;
    remotes = forAccounts (acct: lib.nameValuePair "gdrive-${acct}" {
      config = {
        type = "drive";
        scope = "drive";
        client_id = "REPLACE.apps.googleusercontent.com"; # not secret
        use_trash = true;              # local rm -> Drive trash (30-day undo). Default, set explicitly.
        export_formats = "link.html";  # gdocs appear as Doc.link.html -> xdg-open opens browser
        skip_dangling_shortcuts = true;
      };
      secrets = {                      # injected via `rclone config update` at rclone-config start
        client_secret = secret "rclone-gdrive-client-secret";
        token = secret "rclone-gdrive-${acct}-token";
      };
      mounts."" = {                    # "" = whole My Drive -> `gdrive-${acct}:`
        enable = true;
        mountPoint = "${home}/gdrive/${acct}";
        options = {                    # HM already adds vfs-cache-mode=full, cache-dir=%C/rclone
          dir-cache-time = "1000h";    # safe because Drive change-polling invalidates entries
          poll-interval = "15s";       # web-side changes appear within ~15s
          vfs-cache-max-age = "720h";  # keep opened files ~30 days since last access
          vfs-cache-max-size = "10G";  # per account (209G free on /)
          vfs-cache-min-free-space = "20G";
        };
      };
    });
  };

  # Offline at login would otherwise hit systemd's start-limit and give up; also clear stale FUSE
  # endpoints after a crash so ExecStartPre's mkdir -p doesn't fail with ENOTCONN.
  systemd.user.services = forAccounts (acct: lib.nameValuePair "rclone-mount:@gdrive-${acct}" {
    Unit.StartLimitIntervalSec = 0;
    Service = {
      RestartSec = 15;
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${home}/gdrive/${acct}";
    };
  });

  # Keep rg/fd/telescope from crawling (= downloading) Drive when run from ~.
  home.file.".ignore".text = "/gdrive/\n";
}
```
Unit names it generates: `rclone-config.service`, `rclone-mount:@gdrive-personal.service`, `rclone-mount:@gdrive-study.service`. Checks: `systemctl --user status 'rclone-mount:@gdrive-personal'`, `journalctl --user -u 'rclone-mount:@gdrive-study' -f`.

## 5. yazi (when you set up programs.yazi; yazi 26.9.1 / yaziPlugins.mime-ext are both in nixpkgs)
```nix
programs.yazi = {
  plugins.mime-ext = pkgs.yaziPlugins.mime-ext;
  # Swap file(1)-based type detection for one based on file extensions. Otherwise every file listed on the mount is read, so it gets partly downloaded.
  initLua = ''require("mime-ext"):setup()'';
  settings.plugin.prepend_preloaders = [
    { url = "${config.home.homeDirectory}/gdrive/**"; run = "noop"; }  # no background image/pdf/video preloading
  ];
  # Optional, no previews at all on Drive (hovering downloads that file):
  # settings.plugin.prepend_previewers = [ { url = "${config.home.homeDirectory}/gdrive/**"; run = "noop"; } ];
};
```

## 6. nixvim (recommended)
```nix
opts.backupcopy = "yes";                                  # overwrite in place -> same Drive file ID/history/sharing
opts.backupdir = [ "${config.xdg.stateHome}/nvim/backup//" ]; # drop "." so no file~ churn on Drive
```

## One-time manual steps
1. Go to console.cloud.google.com and sign in with either account. Create a project, then enable the Google Drive API.
2. Set up Google Auth Platform:
   - Branding: app name "rclone" and your email.
   - Audience: External, and add both gmail addresses as test users.
   - Data access: add the scopes `https://www.googleapis.com/auth/drive` and `https://www.googleapis.com/auth/docs`.
3. Under Clients, create an OAuth client of type "Desktop app" and copy its ID and secret.
4. Under Audience, click PUBLISH APP so the status is "In production". It can stay unverified; you will click through the "unverified app" warning once per account. If you skip this, the login expires after 7 days. One client is enough for both accounts.
5. Create the secrets (the age key at /etc/age/agenix-key.txt is owned by tushar):
   - `cd ~/nixos-config/secrets`
   - `nix run github:ryantm/agenix -- -i /etc/age/agenix-key.txt -e rclone-gdrive-client-secret.age` and paste the client secret.
6. For each account:
   - Run `nix run nixpkgs#rclone -- authorize drive '<client_id>' '<client_secret>'`. Sign in with the right account in the browser.
   - Copy the JSON between `--->` and `<---End paste`.
   - Run `agenix -e rclone-gdrive-personal-token.age` (or `-study-`) and paste the JSON.
7. Replace `client_id` in rclone.nix, run `nixos-switch`, then `ls ~/gdrive/personal`.

To re-authorize later (an `invalid_grant` error in the journal), repeat step 6 for that account and run `nixos-switch`. Running `rclone config reconnect` alone does not stick, because the next login overwrites rclone.conf from agenix.

To remove an account:
1. `systemctl --user stop 'rclone-mount:@gdrive-X'`.
2. Check the journal for "queued for upload" or pending items and let them finish.
3. Remove the account from `accounts` and its secret, then switch.
4. Delete the cache: `rm -rf ~/.cache/rclone/vfs/gdrive-X ~/.cache/rclone/vfsMeta/gdrive-X`.
5. Optionally revoke access at myaccount.google.com/permissions.

Nothing on Drive is touched by any of these steps.
## alternatives
- Google Docs: `export_formats = "docx,xlsx,pptx,svg"` (rclone's default) gives real files you can open in LibreOffice. On a mount they show as 0 bytes and often fail to open (per rclone's docs). `skip_gdocs = true` hides them completely. I recommend link.html for a keyboard-first setup.
- `--vfs-refresh` (mount option `vfs-refresh = true;`): reads the whole folder tree in the background at startup. Browsing gets instant and already-listed folders work offline, but it costs API calls on every start. Add it if listings feel slow.
- `use_trash = false`: deletes become permanent. Not recommended. Keep the trash as your undo, and empty it with `rclone cleanup gdrive-personal:`.
- Copy-the-config-once pattern: write rclone.conf only if it's missing, with your own unit, so refreshed tokens survive across logins. Not needed, because Google refresh tokens are long-lived and the home-manager module already handles ordering, atomic writes and restarts.
- rclone bisync or a full local copy (Insync, or google-drive-ocamlfuse with full caching): these can work offline, but a sync engine is exactly what can spread a mass delete, and it doesn't download on demand. A mount fits your requirements better.
- Using `allow-other` and `programs.fuse.userAllowOther = true` is only needed if root, Docker or another user must see the mount.
- Two OAuth clients (one per account) give each its own project quota. Unnecessary at personal scale.
## risks
Verified:
- I evaluated the home-manager module and the snippet against the pinned flake (HM aa23f72, nixpkgs c0a89c3, rclone 1.75.1); unit names and ExecStart render.
- `rclone config update ... config_refresh_token=false token=<json> --non-interactive` exits 0 with no network calls (tested locally with a dummy token).
- `requiresUnit` resolves to null: agenix is a NixOS module here, not a home-manager one. That's fine because system agenix decrypts at activation, before you log in.
- The fusermount wrappers currently exist only through plasma6 and xdg-portal, so set `programs.fuse.enable` explicitly.

Unverified or caveats:
1. I assumed Drive mounts fail when offline at login and added RestartSec=15 and StartLimitIntervalSec=0 as a precaution. I didn't confirm whether startup makes an API call.
2. Sleep/resume and offline use: I believe polling just logs errors and resumes, and the access token refreshes after wake. Opening already-cached files offline should work only if their folder listing is still cached (with dir-cache-time 1000h it usually is). Listing a folder that isn't cached returns I/O errors offline. Writes made offline sit in the cache and retry; pending uploads survive restarts (per rclone's docs). I didn't test any of this live.
3. yazi and other file managers won't refresh by themselves when something changes on Drive's website. inotify doesn't report remote changes on FUSE, so re-enter the folder or reload. I assumed this and didn't test it.
4. Programs that save by writing a temp file and renaming it (LibreOffice, some editors, and nvim unless `backupcopy=yes`) create a NEW Drive file each save. That loses revision history and share links, and the old file goes to the trash. I'm confident about nvim's default backupdir ("." first), but double-check it.
5. `rm -rf ~/gdrive` while it's mounted trashes everything, at about 2 files/s because of rate limits. It can be restored from Drive's trash for 30 days. Never point Syncthing (its folders are set in its GUI, not in Nix), restic, or any sync/backup tool at ~/gdrive.
6. Excluding /gdrive/ in ~/.ignore applies when rg/fd start from ~. When you search inside ~/gdrive, ripgrep may still apply the parent ignore file and skip everything; use `rg -u` / `fd -u` or `--no-ignore-parent` there. I didn't test this.
7. yazi url globs: I read the pinned source. Patterns containing "/" are matched against the full path, so `/home/tushar/gdrive/**` should match, but I didn't run it. mime-ext guesses file types from the extension only, which is slightly less accurate everywhere.
8. Google Docs `.link.html`: their size is known (rclone builds them from a template). I didn't verify what renaming or moving one does. Deleting one trashes the Google Doc.
9. Google can still invalidate a refresh token if it goes unused for 6 months, if you revoke access, or after more than 100 tokens for the same client and account. Fix it by repeating step 6. Leaving the app in "Testing" means it expires every 7 days.
10. Restarting rclone-config during a switch (when the rclone config changed) also restarts both mounts because of Requires=. Files open at that moment may hit I/O errors.
11. Drive allows duplicate file names, and the mount shows only one; fix with `rclone dedupe`. "Shared with me" files are not shown (add a shortcut in My Drive to see them).
## sources
https://rclone.org/drive/ (pinned v1.75.1 man page: 'Making your own client_id' - shared client_id retired during 2026, publish to avoid weekly expiry; 'Limitations of Google Docs' - size 0 in VFS; link.html export; use_trash default true)
https://rclone.org/commands/rclone_mount/ (VFS cache modes, dir-cache-time/poll-interval, write-back, pending uploads resume, systemd notes)
https://rclone.org/commands/rclone_config_update/ (config_refresh_token=false)
https://github.com/rclone/rclone/blob/master/backend/drive/drive.go (newLinkObject sets size from rendered template)
https://github.com/nix-community/home-manager/blob/master/modules/programs/rclone.nix (remotes.<name>.config/secrets/mounts, rclone-config service, requiresUnit auto-detects agenix only in HM)
https://developers.google.com/identity/protocols/oauth2#expiration (7-day refresh token expiry for External+Testing apps; 6-month inactivity; 100-token limit)
https://support.google.com/cloud/answer/13464323 (personal-use apps exempt from verification)
https://www.unipile.com/google-oauth-refresh-token/
https://github.com/yazi-rs/plugins/tree/main/mime-ext.yazi
https://yazi-rs.github.io/docs/tips#make-yazi-even-faster
https://yazi-rs.github.io/docs/configuration/yazi
nixpkgs c0a89c3 nixos/modules/programs/fuse.nix (programs.fuse.enable, userAllowOther)