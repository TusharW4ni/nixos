{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/boot.nix
    ../../modules/system/networking.nix
    ../../modules/system/locale.nix
    ../../modules/system/audio.nix
    ../../modules/system/printing.nix
    ../../modules/desktop/plasma.nix
  ];

  networking.hostName = "nixos";

  users.users.tushar = {
    isNormalUser = true;
    description = "tushar";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    tree
    google-chrome
    claude-code
    tailscale
  ];

  programs.firefox.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
