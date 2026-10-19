# Vivobook-only home config: the Hyprland desktop and everything around it.
{ ... }: {
  imports = [
    ./hyprland.nix
    ./terminal.nix
    ./waybar.nix
    ./notifications.nix
    ./vicinae.nix
    ./hub.nix
  ];

  # Polkit password prompts (none ran under Hyprland before).
  services.hyprpolkitagent.enable = true;
}
