# render
## summary
Most of the recipe holds, and I tested the core of it. With Pango/cairo on the pinned freetype 2.14.3, the darkening variable adds about 13% ink to Inter at 13–20px and about 28% to Noto Sans at 13px. It does nothing at all with hinting set to "none" or "full", because FreeType only darkens in the "light" (slight) mode. Several claims are wrong or need correcting:
(1) NixOS's useEmbeddedBitmaps default is true, not false. Setting it false is still correct, and color emoji keep working.
(2) Slight hinting does send TrueType fonts through the autofitter (checked in the FreeType source). The "unverified" risk and the autohint fallback can be removed.
(3) Two of the "too soft" fixes (Ghostty no-light, hintstyle full) quietly switch darkening off.
(4) The "alpha-blending=native" fix is close to a no-op, because Ghostty's docs say linear-corrected already looks almost the same as native.
(5) The "stronger 500 curve" is the one lucidglyph removed because it broke some fonts.
(6) The jetbrains-mono package ships CFF .otf files and fontconfig picks them. JetBrains Mono therefore gets darkened by the CFF engine with a different curve (+25% ink at 13px). Inter in nixpkgs is TrueType, not CFF.
(7) Ghostty already has JetBrains Mono, the Nerd Font symbols and Noto emoji built in, so the Ghostty block can be just the background.
(8) The Hyprland env fallback isn't needed, because sessionVariables already reach the systemd user environment.
(9) Chrome moved system fonts to Fontations around version 136, not 133.
## recommendation
## Corrected recipe

### A. New file `modules/desktop/fonts.nix` (import it from hosts/nixos-vivobook/default.nix)
```nix
{ pkgs, ... }: {
  fonts = {
    packages = with pkgs; [
      inter                    # TrueType (Inter.ttc + InterVariable.ttf) -> autofitter path
      jetbrains-mono           # fontconfig picks the CFF .otf -> CFF/Adobe path
      noto-fonts               # currently probably pulled in by Plasma; pin it before removing Plasma
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.symbols-only  # families: "Symbols Nerd Font" and "Symbols Nerd Font Mono"
    ];
    fontconfig = {
      # Defaults, pinned on purpose: darkening only runs in the LIGHT hinting mode
      # (freetype src/autofit/afloader.c:366). If this ever changes to none/medium/full, darkening stops.
      hinting.style = "slight";
      subpixel.rgba = "none";
      # NOT a default (pinned nixpkgs defaults to true). Safe for Noto Color Emoji:
      # bitmap-only fonts ignore FT_LOAD_NO_BITMAP.
      useEmbeddedBitmaps = false;
      defaultFonts = {
        sansSerif = [ "Inter" "Noto Sans" ];
        serif     = [ "Noto Serif" ];
        monospace = [ "JetBrains Mono" "Symbols Nerd Font Mono" ];
        emoji     = [ "Noto Color Emoji" ];
      };
    };
  };

  # lucidglyph 0.16 values. type1/t1cid are left out because NixOS rejects
  # Type 1 fonts by default (fonts.fontconfig.allowType1 = false).
  environment.sessionVariables.FREETYPE_PROPERTIES =
    "autofitter:no-stem-darkening=0 autofitter:darkening-parameters=500,400,1000,400,2500,400,4000,0 cff:no-stem-darkening=0";
}
```
Leave out the Hyprland `env` copy. I checked `systemctl --user show-environment`: it already contains `NIXOS_OZONE_WL=1`, which comes from the same sessionVariables/PAM path. So waybar, mako, the Ghostty user service and a future hyprlock/hypridle will all inherit the variable. It takes effect after you log out and back in.

### B. Ghostty (home/tushar.nix): remove `ghostty` from home.packages and add
```nix
programs.ghostty = {
  enable = true;
  settings.background = "000000";
  # No font-family: Ghostty 1.3.1 has JetBrains Mono (TrueType), Symbols Nerd Font and Noto Color Emoji built in.
  # The defaults (alpha-blending=linear-corrected,
  # freetype-load-flags=hinting,no-force-autohint,no-monochrome,autohint,light) are already right.
  # Built-in TTF + 'light' -> autofitter -> darkening applies (FT_Init_FreeType reads the env var).
  # Optional: font-family = "Geist Mono";  (also install pkgs.geist-font)
};
```
One manual step outside the repo: delete the empty `~/.config/ghostty/config.ghostty`. Ghostty 1.3 loads `config` (the one home-manager writes) and then `config.ghostty`, and logs a warning when both exist. Anything written into `config.ghostty` would silently override the home-manager settings.

Also note that programs.ghostty.systemd.enable defaults to true on Linux, so Ghostty runs as a single-instance user service. After you change fonts or the env, restart it with `systemctl --user restart app-com.mitchellh.ghostty`, or log out and back in.

### C. Waybar CSS (home/hyprland.nix)
`font-family: "Inter", "Symbols Nerd Font"; font-size: 13px;` Waybar (GTK3) and mako (Pango + cairo, not GTK) both get the slight hinting and the darkening.

### D. Verify
- `fc-match -v sans-serif | grep -E 'family:|hintstyle|antialias|rgba|embeddedbitmap'` should show Inter, hintstyle 1, rgba 5, embeddedbitmap False. Before the change it currently shows True.
- `tr '\0' '\n' </proc/$(pgrep -x waybar)/environ | grep FREETYPE`
- Measured A/B test, no display needed. pango-view is in the `pango.bin` output: `FREETYPE_PROPERTIES= pango-view -q --backend=cairo --font='Inter 9.75' --hinting=slight -o off.png --text='The quick brown fox'`, then run the same command with the variable set and compare the two PNGs. Ghostty A/B test: run `FREETYPE_PROPERTIES= ghostty` from inside a Ghostty window. TERM_PROGRAM is set there, so it opens a separate process. Launching from a keybind reuses the running instance.

### E. Calibration (corrected; change one knob at a time)
**Too bold** (likely with light text on pure black):
1. Milder autofitter curve: `autofitter:darkening-parameters=500,400,1000,275,1667,275,2333,0` (Adobe's). On Inter it measured +9% ink instead of +13%.
2. JetBrains Mono outside Ghostty (CFF path, +25% at 13px): add `cff:darkening-parameters=500,300,1000,200,1500,100,2000,0` (the example from FreeType's docs).
3. Remove `cff:no-stem-darkening=0` or the autofitter entries.
Do NOT use `alpha-blending=native` for this. Ghostty documents linear-corrected as looking "nearly or completely identical to native".

**Too thin:**
1. Ghostty `alpha-blending = linear`. Its docs say this makes light text "much thicker".
2. Ghostty `font-style = Medium`.
3. Y values in the curve must be ≤500, must decrease monotonically, and each segment's slope must be shallower than -1. Keep them ≤~450: lucidglyph dropped 500 to 400 because 500 broke some fonts.
4. lucidglyph's fontconfig `embolden` rule for pixelsize < 14 is a last resort. It would apply synthetic bold to all of your 13px waybar text.

**Too soft:** `freetype-load-flags = ...,no-light` (Ghostty) and `hinting.style = "full"` both give crisper stems, but both turn darkening off completely. That's a choice between crisp and full, not a small adjustment. Avoid `rgba = "rgb"`.
## alternatives
- Forcing the autofitter for everything (`fonts.fontconfig.hinting.autohint = true`, or Ghostty `force-autohint`): unnecessary for TrueType fonts, since slight hinting already uses the autofitter. For CFF fonts like JetBrains Mono .otf it would replace Adobe's light hinter with the autofitter. Use it only if you want all fonts darkened by the same curve.
- Hint style none: darkening stops completely (measured identical ink with and without the env var). Not recommended at 141/102 DPI.
- Geist / Geist Mono (`geist-font` 1.7.0, TrueType) is a good alternative to Inter / JetBrains Mono. With it the UI and the mono text both use the autofitter path and the same curve.
- If you prefer one curve for everything, you could leave out `jetbrains-mono` entirely: Ghostty already has it built in. Then use Geist Mono or Inter for waybar and Hack/Noto Mono as the system monospace.
## risks
- Verified in source or by measurement: TrueType + LIGHT -> autofitter (only the CFF driver has FT_MODULE_DRIVER_HINTS_LIGHTLY, ftobjs.c:1009). Autofitter darkening runs only in LIGHT mode (afloader.c:366). Darkening is off by default for af/cff/type1. Ghostty calls FT_Init_FreeType (pkg/freetype/Library.zig:16), so it reads FREETYPE_PROPERTIES. Ghostty maps `light` to FT_LOAD_TARGET_LIGHT (src/font/face/freetype.zig glyphLoadFlags). Measured with pango-view at hinting slight/none/full: darkening changes slight only.
- Not visually checked on the real screens. The numbers are ink sums, not appearance. Light-on-black text already looks heavier, so the milder curve may end up being the better choice.
- Ghostty draws resized ("constrained") icon glyphs without hinting, so Nerd Font icons in Ghostty are not darkened, which is fine. Waybar icons are darkened, and lucidglyph's icon-font rule exists in case they look too heavy.
- Correction on "darkening leaves large text alone": with the lucidglyph curve, Inter still gets +13% at 20px. The taper only starts once stems are wider than 2.5px.
- GTK4 (Ghostty's tabs): the automatic mode reportedly uses slight hinting below 200 DPI (from a search summary pointing to GTK MR 7157; I didn't read the code), so darkening should apply there too.
- Chrome/Electron: Fontations is used for system fonts on Linux from about Chrome 136, and the FreeType fallback was removed after 139 (fontations PR 1496 comment). They don't darken, so Chrome, Slack, Discord and Obsidian will look thinner than everything else.
- sessionVariables values can't contain a `"` character (PAM limitation). This one doesn't.
- Darkening is set once for the whole session and can't differ per monitor.
## sources
FreeType 2.14.3 source (pinned): src/base/ftobjs.c lines 976-1016 (autohint routing, HINTS_LIGHTLY only in src/cff/cffdrivr.c:1188)
FreeType 2.14.3 source: src/autofit/afloader.c:366 (stem darkening only when render_mode == FT_RENDER_MODE_LIGHT); src/autofit/afmodule.c:404, src/cff/cffobjs.c:1141 (darkening default off)
FreeType 2.14.3 include/freetype/ftdriver.h lines 512-517 (darkening-parameters constraints: y<=500, decreasing, slope shallower than -1)
FreeType include/freetype/freetype.h:3349 (FT_LOAD_NO_BITMAP ignored by bitmap-only fonts)
https://freetype.org/freetype2/docs/reference/ft2-properties.html
Ghostty 1.3.1 `ghostty +show-config --default --docs` (font-thicken macOS-only; alpha-blending linear-corrected ~= native; freetype-load-flags defaults; gtk-single-instance=detect)
Ghostty source (nixpkgs ghostty.src): pkg/freetype/Library.zig:16, src/font/face/freetype.zig glyphLoadFlags, src/font/embedded.zig, src/config/Config.zig loadDefaultFiles (loads config then config.ghostty)
Pinned nixpkgs nixos/modules/config/fonts/fontconfig.nix (useEmbeddedBitmaps default = true; hinting.style default slight; rgba default none; allowType1 default false)
home-manager source modules/programs/ghostty.nix (writes ghostty/config; systemd.enable defaults true on Linux)
https://github.com/maximilionus/lucidglyph (README Details + CHANGELOG 0.16.0: autofitter Y reduced 500->400; 20-lucidglyph-embolden.conf pixelsize<14)
https://github.com/googlefonts/fontations/pull/1496#issuecomment-3004330901
https://docs.gtk.org/gtk4/enum.FontRendering.html
https://gitlab.gnome.org/GNOME/gtk/-/merge_requests/7157.diff
Local measurement: pango-view 1.57.1 + cairo, ink sums with/without FREETYPE_PROPERTIES for Noto Sans, Hack, Inter 4.1, JetBrains Mono 2.304 at 13/16/20px under hinting slight/none/full
Local: `systemctl --user show-environment` shows sessionVariables (NIXOS_OZONE_WL=1) reach the systemd user env