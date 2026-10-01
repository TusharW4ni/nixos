{ ... }: {
  # Hyprland Wayland compositor. SDDM (enabled in plasma.nix) will offer it
  # as a session alongside Plasma, so KDE stays available as a fallback.
  # This installs Hyprland and wires up its XDG portals and polkit bits; the
  # per-user config (keybinds, bar, etc.) lives in home/hyprland.nix.
  programs.hyprland.enable = true;

  # Make Electron/Chromium apps (Chrome, Slack, Discord, VS Code...) run as
  # native Wayland clients under Hyprland instead of blurry XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
