{ lib, buildGoModule, fetchFromGitHub, libX11 }:

# slk: keyboard-driven Slack TUI (bubbletea). Not in nixpkgs; upstream ships
# a flake pinned to its own nixpkgs, so we build from source against ours.
# Bump version + hashes to update. Auth: `slk --add-workspace` reads the
# session from the Slack desktop app (installed in home/tushar.nix).
buildGoModule rec {
  pname = "slk";
  version = "0.29.0";

  src = fetchFromGitHub {
    owner = "gammons";
    repo = "slk";
    rev = "v${version}";
    hash = "sha256-ac9tkq32lbip8glcdjaAGXW7Tap2N2vElEmODYDpRig=";
  };

  vendorHash = "sha256-VPmvgB8BkjI3DOdl4XMqT0nxXKdz/v0Hs06veKtfvoY=";

  # X11 clipboard backend (golang.design/x/clipboard); Wayland goes via wl-clipboard.
  buildInputs = [ libX11 ];

  subPackages = [ "cmd/slk" ];
  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "A blazingly fast Slack TUI";
    homepage = "https://github.com/gammons/slk";
    license = licenses.mit;
    mainProgram = "slk";
    platforms = platforms.unix;
  };
}
