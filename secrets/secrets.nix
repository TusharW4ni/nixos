let
  tushar = "age1ek64j52lglr2y9j02plfthcdtqcya02mwu0xyrtpjcslyfhh49zq05k5yt";
in
{
  "tushar-pw.age".publicKeys = [ tushar ];
  "claude-sync-config.age".publicKeys = [ tushar ];
  "claude-sync-age-key.age".publicKeys = [ tushar ];
  # Google Drive (rclone): OAuth client secret + one token per account.
  "rclone-gdrive-client-secret.age".publicKeys = [ tushar ];
  "rclone-gdrive-personal-token.age".publicKeys = [ tushar ]; # reachtusharwani@gmail.com
  "rclone-gdrive-study-token.age".publicKeys = [ tushar ];    # tusharstudydocs@gmail.com
}
