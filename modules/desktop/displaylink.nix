{ ... }: {
  # DisplayLink (Dell D6000 dock, USB 17e9:6006). Loads the evdi kernel module
  # and runs DisplayLinkManager (dlm.service, started by udev on plug-in).
  # The driver zip is unfree and not downloadable by Nix; on a fresh machine
  # prefetch it once with the nix-prefetch-url command the build error prints.
  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];
}
