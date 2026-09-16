{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/boot.nix
    ../../modules/system/networking.nix
    ../../modules/system/locale.nix
    ../../modules/system/keyd.nix
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
    btop
    tree
    google-chrome
    claude-code
    tailscale
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
