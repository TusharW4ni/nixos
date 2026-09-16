{ config, ... }: {
  # The bootstrap identity: the ONE private key, generated once with
  # `age-keygen -o /etc/age/agenix-key.txt`, that decrypts every secret.
  # It lives outside git and is placed on the machine by hand.
  age.identityPaths = [ "/etc/age/agenix-key.txt" ];

  # Each secret points at its encrypted .age file (safe to commit) and is
  # decrypted at activation into config.age.secrets.<name>.path (/run/agenix/...).
  age.secrets.tushar-pw.file = ../../secrets/tushar-pw.age;
}
