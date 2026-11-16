{ ... }: {
  # OpenXR streaming server for the Quest 3. Enables avahi so the headset
  # discovers this machine on the LAN; openFirewall opens 9757 TCP/UDP.
  services.wivrn = {
    enable = true;
    openFirewall = true;
    autoStart = true;
    highPriority = true; # async reprojection; smooths frame drops on the iGPU
    steam.importOXRRuntimes = true; # Steam games find WiVRn without launch options
  };
}
