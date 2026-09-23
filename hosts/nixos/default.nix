{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/boot.nix
    ../../modules/system/networking.nix
    ../../modules/system/locale.nix
    ../../modules/system/keyd.nix
    ../../modules/system/audio.nix
    ../../modules/system/printing.nix
    ../../modules/system/bluetooth.nix
    ../../modules/system/secrets.nix
    ../../modules/system/docker.nix
    ../../modules/desktop/plasma.nix
  ];

  networking.hostName = "nixos";

  users.users.tushar = {
    isNormalUser = true;
    description = "tushar";
    extraGroups = [ "networkmanager" "wheel" "docker" ];

    # Decrypted from secrets/tushar-pw.age into /run/agenix/tushar-pw at
    # activation. Contains the output of `mkpasswd -m sha-512`.
    hashedPasswordFile = config.age.secrets.tushar-pw.path;
  };

  # Prevent silently-lockable accounts: fail the build if a normal user
  # has no declarative password set.
  users.mutableUsers = false;

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
