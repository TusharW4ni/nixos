{ pkgs, ... }: {
  # Font stack and Mac-like text rendering. Research and calibration notes:
  # docs/superpowers/specs/2026-10-19-hyprland-polish-research/render.md
  fonts = {
    packages = with pkgs; [
      atkinson-hyperlegible-next # UI font (bar, banners, launcher, lock screen)
      jetbrains-mono             # terminal / code
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      lucide                     # thin line icons; only ever used via a Pango font_family span
    ];
    fontconfig = {
      # Stem darkening only runs in FreeType's LIGHT mode, which is what
      # "slight" selects. Changing this to none/medium/full turns it off.
      hinting.style = "slight";
      subpixel.rgba = "none"; # grayscale AA, like macOS
      useEmbeddedBitmaps = false;
      defaultFonts = {
        sansSerif = [ "Atkinson Hyperlegible Next" "Noto Sans" ];
        serif = [ "Noto Serif" ];
        monospace = [ "JetBrains Mono" "Symbols Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # FreeType stem darkening (lucidglyph 0.16 curve): thickens thin strokes at
  # small sizes, the main reason Linux text looks spindly next to macOS.
  # Too bold? Use Adobe's curve: 500,400,1000,275,1667,275,2333,0.
  # Chrome/Electron ignore this (they render with Fontations).
  environment.sessionVariables.FREETYPE_PROPERTIES =
    "autofitter:no-stem-darkening=0 autofitter:darkening-parameters=500,400,1000,400,2500,400,4000,0 cff:no-stem-darkening=0";
}
