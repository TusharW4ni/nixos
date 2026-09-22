{ config, ... }: {
  # The bootstrap identity: the ONE private key, generated once with
  # `age-keygen -o /etc/age/agenix-key.txt`, that decrypts every secret.
  # It lives outside git and is placed on the machine by hand.
  age.identityPaths = [ "/etc/age/agenix-key.txt" ];

  # Each secret points at its encrypted .age file (safe to commit) and is
  # decrypted at activation into config.age.secrets.<name>.path (/run/agenix/...).
  age.secrets.tushar-pw.file = ../../secrets/tushar-pw.age;

  # claude-sync reads credentials and its age identity from files under
  # ~/.claude-sync. Instead of decrypting into /run/agenix, we point each
  # secret's `path` straight at the home location the tool expects, owned by
  # tushar and 0600 so the tool (and only tushar) can read them.
  age.secrets.claude-sync-config = {
    file = ../../secrets/claude-sync-config.age;
    path = "/home/tushar/.claude-sync/config.yaml";
    owner = "tushar";
    group = "users";
    mode = "0600";
  };
  age.secrets.claude-sync-age-key = {
    file = ../../secrets/claude-sync-age-key.age;
    path = "/home/tushar/.claude-sync/age-key.txt";
    owner = "tushar";
    group = "users";
    mode = "0600";
  };
}
