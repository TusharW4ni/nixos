{ pkgs, ... }:
let
  nixos-switch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -e
    CONFIG_DIR="$HOME/nixos-config"

    cd "$CONFIG_DIR"
    git add -A

    sudo nixos-rebuild switch --flake "$CONFIG_DIR#nixos" "$@"

    if ! git diff --cached --quiet || ! git diff --quiet; then
      git add -A
    fi

    if ! git diff --staged --quiet; then
      GENERATION=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1 | awk '{print $1}')
      git commit -m "switch: generation $GENERATION ($(date '+%Y-%m-%d %H:%M'))"
    else
      echo "nixos-switch: nothing new to commit"
    fi
  '';
in
{
  home.username = "tushar";
  home.homeDirectory = "/home/tushar";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    kdePackages.kate
    nixos-switch
    gh
  ];

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user.name = "TusharW4ni";
    settings.user.email = "reachtusharwani@gmail.com";
  };

  programs.bash.enable = true;
  programs.bash.shellAliases = {
    ns = "nixos-switch";
  };
}
