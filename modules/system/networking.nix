{ ... }: {
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;

  networking.firewall.allowedTCPPortRanges = [ { from = 3000; to = 3100; } ];
}
