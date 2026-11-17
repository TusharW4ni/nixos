# Vivobook-only home config: the Hyprland desktop and everything around it.
{ ... }: {
  imports = [
    ./hyprland.nix
    ./terminal.nix
    ./waybar.nix
    ./notifications.nix
    ./vicinae.nix
    ./hub.nix
    ./yazi.nix
    ./rclone.nix
  ];

  # Polkit password prompts (none ran under Hyprland before).
  services.hyprpolkitagent.enable = true;

  # wayvr (desktop-in-VR, launched by WiVRn) defaults to wlr-screencopy here,
  # which hands it shm frames; its CPU upload path segfaults on them (26.8.0).
  # PipeWire goes through the xdph portal and passes GPU dmabufs instead.
  xdg.configFile."wayvr/conf.d/capture.yaml".text = ''
    capture_method: pipewire
  '';
}
