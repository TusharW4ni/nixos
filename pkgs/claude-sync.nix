{ lib, buildGoModule, fetchFromGitHub }:

# claude-sync: syncs Claude Code sessions across devices via S3-compatible
# storage (Cloudflare R2 here) with age end-to-end encryption.
# Upstream ships npm/prebuilt binaries; on NixOS we build from source so the
# result is reproducible and linked against the Nix toolchain.
buildGoModule rec {
  pname = "claude-sync";
  version = "1.17.1";

  src = fetchFromGitHub {
    owner = "tawanorg";
    repo = "claude-sync";
    rev = "v${version}";
    hash = "sha256-hsIski28Dr3k3+/0/+k6XySAeoQ6e5nTeLAGRtZ2kAQ=";
  };

  # Hash of the vendored Go dependency tree.
  vendorHash = "sha256-VLqVk5bhM+WoEbP+agFpm1LjzI2qFWlWQZB8yV2vbOU=";

  # Only build the CLI entrypoint, not every package in the module.
  subPackages = [ "cmd/claude-sync" ];

  # Trim binary size; harmless if upstream sets its own version via ldflags.
  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "Sync Claude Code sessions across devices with end-to-end encryption";
    homepage = "https://github.com/tawanorg/claude-sync";
    license = licenses.mit;
    mainProgram = "claude-sync";
    platforms = platforms.unix;
  };
}
