{ ... }: {
  # Also enables 32-bit graphics (hardware.graphics.enable32Bit) and the
  # Steam controller udev rules.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };
}
