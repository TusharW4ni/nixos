{ lib, ... }: {
  # Google Drive via rclone (home/rclone.nix). The OAuth client secret and
  # one token per account are agenix secrets owned by tushar, decrypted at
  # activation before the user's rclone services start.
  programs.fuse.enable = true;

  age.secrets = lib.genAttrs
    [ "rclone-gdrive-client-secret" "rclone-gdrive-personal-token" "rclone-gdrive-study-token" ]
    (name: {
      file = ../../secrets/${name}.age;
      owner = "tushar";
      group = "users";
      mode = "0400";
    });
}
