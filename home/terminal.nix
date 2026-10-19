# Ghostty, pure black. JetBrains Mono, Nerd Font symbols and emoji are built
# into Ghostty, so no font-family is set.
{ ... }: {
  programs.ghostty = {
    enable = true;
    settings = {
      background = "#000000";
      foreground = "#e6e6e6";
      selection-background = "#262626";
      selection-foreground = "#ffffff";
      cursor-style-blink = false;
      # Report "dark" to TUIs (herdr, yazi) now that Plasma's portal is gone.
      window-theme = "dark";
      window-decoration = "none";
      window-padding-x = 8;
      window-padding-y = 6;
      window-padding-balance = true;
      window-padding-color = "background";
      confirm-close-surface = false;
    };
  };
}
