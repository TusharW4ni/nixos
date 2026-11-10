{ inputs, ... }: {
  imports = [ inputs.bootvine.nixosModules.default ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Systemd initrd is the default on 26.05+, so bootvine covers initrd too.
  services.bootvine.enable = true;
}
