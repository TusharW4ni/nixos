{ ... }: {
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--operator=tushar" ]; # tailscale up/down without sudo (bar + hub)
  };

  networking.firewall.allowedTCPPortRanges = [ { from = 3000; to = 3100; } ];
}
