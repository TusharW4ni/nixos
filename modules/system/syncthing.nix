{ ... }: {
  services.syncthing = {
    enable = true;
    user = "tushar";
    dataDir = "/home/tushar/Sync";
    guiAddress = "0.0.0.0:8384";
    # Sync traffic (22000 tcp/udp + 21027 udp discovery) stays open to
    # LAN/internet — Syncthing authenticates peers with per-device certs
    # regardless of network path, so this is the normal/expected exposure.
    openDefaultPorts = true;
  };

  # The GUI has no auth by default, so don't expose it on LAN/internet like
  # the sync ports above — only allow it in over the tailnet.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8384 ];
}
