# Latitude-only home config. The Latitude still runs Plasma, so it keeps
# plasma-manager and Kate. The Hyprland user config is vivobook-only.
{ pkgs, inputs, ... }: {
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./plasma.nix
  ];

  home.packages = with pkgs; [ kdePackages.kate ghostty mpv ];
}
