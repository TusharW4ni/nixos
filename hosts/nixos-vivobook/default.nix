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
    ../../modules/system/syncthing.nix
    ../../modules/system/nix-ld.nix
    ../../modules/system/battery.nix
    ../../modules/system/memory.nix
    ../../modules/desktop/session.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/gdrive.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/steam.nix
    ../../modules/desktop/wivrn.nix
  ];

  networking.hostName = "nixos-vivobook";

  # SSH reachable over Tailscale only, not on LAN/public Wi-Fi.
  services.openssh = {
    enable = true;
    openFirewall = false;
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];

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
  # Hard-link identical files in the store (weekly). Saves space without
  # slowing every build the way auto-optimise-store does.
  nix.optimise.automatic = true;

  # Hardware video decode/encode (VA-API) on the Alder Lake iGPU. Without it,
  # Chrome, Slack and Discord decode video calls on the CPU.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Mac-formatted (APFS) drives. Out-of-tree driver; mounts read-only unless
  # given the `readwrite` option, which upstream calls experimental.
  boot.supportedFilesystems.apfs = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
