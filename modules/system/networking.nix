{ ... }: {
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--operator=tushar" ]; # tailscale up/down without sudo (bar + hub)
  };

  networking.firewall = {
    allowedTCPPortRanges = [ 
      { from = 27036; to = 27037; } 
    ];
    allowedUDPPortRanges = [
      { from = 27031; to = 27036; }
    ];
  };
}
