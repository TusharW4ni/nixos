# fonts
## summary
Every finalist below was checked against the flake's pinned nixpkgs with nix eval/nix build, and its Google Fonts name was checked live with the fonts.googleapis.com/css2 API (HTTP 200 means it exists). Families not on Google Fonts were checked on the Fontsource and jsDelivr CDNs.

Recommended pairing:
- **UI: Inter.** It is the closest free match to SF Pro. Turn on tabular figures (tnum) so numbers in the bar don't jitter.
- **Terminal: JetBrains Mono.** It looks crisp at scale 1 on both the 141 and 102 DPI screens, and it is mature.

Alternatives:
- **Geist + Geist Mono** (Vercel). Sharper and more "designed", the most Mac/modern-looking pair. Both come from one package, `geist-font`.
- **Commit Mono or Monaspace.** Both use the `calt` OpenType feature to rebalance letter spacing ("smart kerning" / "texture healing"). That is the closest a monospace font gets to the kerning quality the user asked about.

Icons: use `nerd-fonts.symbols-only` as the base. Ghostty already has its own copy of these symbols built in. For a thinner, more minimal waybar look, use the Lucide icon font (`pkgs.lucide`, family name "lucide") through Pango `<span>` markup.

Watch the exact family names: Inter installs as "Inter Variable", not "Inter". Manrope was removed from nixpkgs.
## recommendation
## (a) UI / sans: 8 finalists
Fontconfig names come from running fc-scan on the built store paths.

1. **Inter.** nixpkgs `inter` 4.1, family **"Inter Variable"** (variable only; there is no family called "Inter"). Also `inter-nerdfont`. Google Fonts: "Inter" (and "Inter Tight").
   - Look: neutral neo-grotesque, tall x-height, built for screens. It is the default SF Pro substitute.
   - Why people like it: very broad language coverage, and many OpenType features: `tnum` (tabular figures), `cv11` (single-storey a), `ss03`, `zero`, `case`.
   - Downside: it is everywhere, so it looks generic. It is unhinted, so it relies on fontconfig `hintslight` at scale 1.
2. **Geist.** nixpkgs `geist-font` 1.7.0, family **"Geist"**. The same package also installs **"Geist Mono"**. Google Fonts: "Geist".
   - Look: Vercel's Swiss/grotesk with sharper terminals and tighter proportions. It reads as more "tech/Apple".
   - Downside: thin strokes can look light at 12–13px on the 102 DPI external monitor. Use weight 500 in the bar.
3. **IBM Plex Sans.** nixpkgs `ibm-plex` (unstable-2026-07-30), families "IBM Plex Sans" and "IBM Plex Sans Var" (plus Condensed and CJK). Google Fonts: "IBM Plex Sans".
   - Look: a grotesk with a bit of engineered personality (angled terminals). Well hinted and crisp at low DPI.
   - Pairs naturally with IBM Plex Mono.
4. **Mona Sans.** nixpkgs `mona-sans` 2.0.27, families "Mona Sans" and "Mona Sans VF" (plus Expanded/Condensed widths and "Mona Sans Mono"). Google Fonts: "Mona Sans".
   - Look: GitHub's grotesk, a little warmer and wider than Inter. The width axis makes for good bar and notification headings.
5. **Atkinson Hyperlegible Next.** nixpkgs `atkinson-hyperlegible-next` 2.001, family "Atkinson Hyperlegible Next". Google Fonts: "Atkinson Hyperlegible Next" (also "Atkinson Hyperlegible Mono").
   - Look: maximally distinct letterforms (Il1, 0O), built for low vision. Very readable small, but quirkier and less sleek.
6. **Figtree.** nixpkgs `figtree` 2.0.3. Google Fonts: "Figtree".
   - Look: a friendly, clean geometric sans, softer than Inter. Good for launcher and notifications. Downside: narrower feature set.
7. **Public Sans.** nixpkgs `public-sans` 2.001. Google Fonts: "Public Sans".
   - Look: a neutral US-government grotesk, sober and very even. A safe, boring-good choice.
8. **Manrope.** Google Fonts: "Manrope". It is **not in nixpkgs anymore**: `nix eval` returns "'manrope' has been removed". You can still get it with `(pkgs.google-fonts.override { fonts = [ "Manrope" ]; })`; the `fonts` argument was verified.
   - Look: a modern semi-geometric sans, stylish for headings, slightly wide for a dense bar.

Also available but not finalists:
- `sn-pro` 1.5.0 (Google Fonts "SN Pro"). A rounded SF-like font, worth a look on the specimen page.
- `plus-jakarta-sans` and `dm-sans` (both on Google Fonts).
- `rubik` (too chunky for a bar).
- "Onest" is on Google Fonts but not in nixpkgs.
- There is no SF Pro and no apple-fonts package in nixpkgs.

## (b) Monospace: 8 finalists
1. **JetBrains Mono.** nixpkgs `jetbrains-mono` 2.304 (families "JetBrains Mono" and "JetBrains Mono NL"). Also `nerd-fonts.jetbrains-mono`. Google Fonts: "JetBrains Mono".
   - Look: tall x-height, rectangular ovals, around 139 ligatures. A workhorse that renders crisp at 13–14px.
   - Downside: so common it feels default. It is also Ghostty's built-in fallback.
2. **Geist Mono.** From `geist-font` (variable "Geist Mono"). Also `nerd-fonts.geist-mono`. Google Fonts: "Geist Mono".
   - Look: compressed and sharp, the most "designed/modern" free mono. No coding ligatures. It matches Geist perfectly.
3. **Commit Mono.** nixpkgs `commit-mono` 1.143, family "CommitMono". Also `nerd-fonts.commit-mono`. Not on Google Fonts; CDN: https://cdn.jsdelivr.net/npm/@fontsource/commit-mono/index.css
   - Look: neutral and anonymous. Its "smart kerning" in `calt` shifts a letter toward a narrower neighbour (e.g. the o in "moi" moves 44 units), so monospace text reads more like proportional text.
4. **Monaspace** (GitHub Next). nixpkgs `monaspace` 1.400. It already ships Nerd Font versions: "Monaspace Neon/Argon/Xenon/Radon/Krypton" plus " NF", " Var" and " Frozen". Also `nerd-fonts.monaspace`. Not on Google Fonts; CDN: https://cdn.jsdelivr.net/npm/@fontsource/monaspace-neon/index.css (also `monaspace-argon`, `monaspace-xenon`).
   - The five styles: Neon = neo-grotesque, Argon = humanist, Xenon = slab serif, Radon = handwriting, Krypton = mechanical.
   - "Texture healing" (`calt`) swaps glyphs so wide letters borrow space from narrow ones. Neon and Argon are the beautiful ones; mixing in Radon for italics is the popular trick.
5. **Maple Mono.** nixpkgs `maple-mono.*` 7.9. Variants include `.truetype`, `.NF`, `.NF-unhinted` and `.NF-CN`; `.NF-unhinted` gives family "Maple Mono NF". Not on Google Fonts; CDN: https://cdn.jsdelivr.net/npm/@fontsource/maple-mono/index.css
   - Look: rounded corners, gorgeous cursive italics, built-in Nerd Font glyphs, many character variants. Soft and "cute-premium".
   - Use the hinted variant (`maple-mono.NF`) for the 102 DPI external monitor.
6. **IBM Plex Mono.** From `ibm-plex`. Also `nerd-fonts.blex-mono` (family "BlexMono Nerd Font"). Google Fonts: "IBM Plex Mono".
   - Look: typewriter warmth, excellent italics, very crisp. "Lilex" (Google Fonts, `lilex`) is Plex Mono with ligatures added.
7. **Iosevka.** Use nixpkgs **`iosevka-bin`** 34.9.0 (families "Iosevka", "Iosevka Term", "Iosevka Fixed"). Plain `iosevka` compiles from source and is slow. Also `nerd-fonts.iosevka` / `iosevka-term`, and `aporetic` / `iosevka-comfy` for curated builds. Not on Google Fonts; CDN: https://cdn.jsdelivr.net/npm/@fontsource/iosevka/index.css
   - Look: narrow and elegant; fits many columns, endlessly configurable. Downside: narrowness reads cramped at 1x.
8. **Cascadia Code.** nixpkgs `cascadia-code` 2407.24, which already includes "Cascadia Code NF" and "Cascadia Mono NF". Google Fonts: "Cascadia Code" / "Cascadia Mono".
   - Look: Microsoft's friendly, rounded mono, with a cursive italic (`ss01`).

Also verified:
- Martian Mono (`martian-mono`, Google Fonts "Martian Mono"): wide and technical.
- Intel One Mono (`intel-one-mono`, Google Fonts "Intel One Mono").
- Victor Mono (`victor-mono`, Google Fonts "Victor Mono").
- Fira Code (`fira-code`, Google Fonts "Fira Code").
- Recursive (`recursive`, Google Fonts "Recursive").
- Fragment Mono (`fragment-mono`, Google Fonts "Fragment Mono").
- 0xProto (`_0xproto`; not on Google Fonts or Fontsource).
- Departure Mono (`departure-mono`, a pixel font; not on Google Fonts or Fontsource).
- Zed Mono: only `nerd-fonts.zed-mono`; there is no plain `zed-mono`.
- Berkeley Mono: paid ($75), not in nixpkgs; it would need `requireFile` or a private input.

## Pairing
- **Primary: Inter (UI) + JetBrains Mono (terminal).** This is the most robust crisp pairing at scale 1.
- **Beauty alternative: Geist + Geist Mono.** One package and a coherent, Mac-like look.
- **For the "kerning" itch in the terminal:** Commit Mono or Monaspace Neon/Argon with `calt` on.

## Nix (NixOS module)
```nix
fonts = {
  packages = with pkgs; [ inter geist-font jetbrains-mono commit-mono monaspace nerd-fonts.symbols-only lucide noto-fonts-color-emoji ];
  fontconfig.defaultFonts = {
    sansSerif = [ "Inter Variable" "Symbols Nerd Font" ];
    monospace = [ "JetBrains Mono" "Symbols Nerd Font Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };
};
```

Ghostty: it already contains JetBrains Mono and Symbols Nerd Font, so no patched font is needed. `font-family` can be repeated to add fallbacks.
```
font-family = JetBrains Mono   # or: CommitMono / Monaspace Neon / Geist Mono
font-size = 12
font-feature = calt            # smart kerning / texture healing (Commit, Monaspace)
# font-feature = -liga         # if you dislike ligatures
```

Waybar (GTK3 supports `font-feature-settings` but not `font-variation-settings`):
```css
* { font-family: "Inter Variable", "Symbols Nerd Font"; font-size: 13px; font-weight: 500; font-feature-settings: "tnum"; }
```

## Icon approach (thin, minimal)
- **Base: `nerd-fonts.symbols-only`** (families "Symbols Nerd Font" and "Symbols Nerd Font Mono"). Use its `md-*` Material Design Icons glyphs; they are clean, not tacky. Avoid the Font Awesome glyphs, which are heavy and solid.
- **Thinner option: Lucide.** nixpkgs `lucide` 0.563.0 installs `Lucide.ttf` with family **"lucide"**. Its icons are thin line drawings (24-unit grid, 2-unit stroke), about a 1.1px line at 13–14px.
  - Use it through Pango markup in waybar formats, e.g. `"format": "<span font_family='lucide'></span> {volume}%"`.
  - Codepoints from lucide-static@0.563.0 `font/info.json`: mic E118, mic-off E119, sun E178, moon E11E, volume-2 E1AB, volume-x E1AC, wifi E1AE, wifi-off E1AF, battery E053, battery-charging E054, bluetooth E05C, lock E10B, power E140, play E13C, pause E12E, music E122.
- **Skip for the bar:**
  - Material Symbols (nixpkgs `material-symbols`: "Material Symbols Outlined/Rounded/Sharp"). It looks great, but its thin weight needs `font-variation-settings`, which GTK3 lacks.
  - Phosphor. It is not in nixpkgs.

Specimen page loading: use `https://fonts.googleapis.com/css2?family=Inter:wght@100..900&family=Geist:wght@100..900&family=Geist+Mono:wght@100..900&family=JetBrains+Mono:wght@100..800&family=IBM+Plex+Sans&family=IBM+Plex+Mono&family=Mona+Sans&family=Atkinson+Hyperlegible+Next&family=Figtree&family=Public+Sans&family=Manrope&family=SN+Pro&family=Cascadia+Code&family=Martian+Mono&family=Victor+Mono&family=Fira+Code&display=swap`, plus the Fontsource jsDelivr CSS links above for Commit Mono, Monaspace, Maple Mono and Iosevka. Lucide for the browser: https://cdn.jsdelivr.net/npm/lucide-static/font/lucide.css
## alternatives

## risks
- **Inter's family name.** The nixpkgs `inter` 4.1 ships only variable TTFs, family "Inter Variable". Configs that say "Inter" will silently fall back to DejaVu. Verified with fc-scan.
- **Hinting claims.** That JetBrains Mono, IBM Plex and Cascadia are hinted while Inter and Geist are unhinted is from general knowledge and was not verified per file. The page view at scale 1 on the 102 DPI HDMI monitor is the real test. Pair with the rendering research (hintslight, lcdfilter, subpixel).
- **Ghostty `font-thicken`.** The fetched Ghostty docs describe it as macOS-only, so don't rely on it on Linux. The claim that Ghostty bundles JetBrains Mono and Symbols Nerd Font comes from search summaries, not the official reference page.
- **Lucide codepoints.** They are not stable across Lucide versions; pin them to the nixpkgs `lucide` version (0.563.0) and recheck after upgrades. Some Lucide PUA codepoints (E0A0–E0D7) overlap Nerd Font powerline glyphs, so always scope Lucide with a Pango `font_family` span rather than putting it in the global font list.
- **GTK3 CSS.** `font-feature-settings` is listed in the GTK3 CSS docs, but the waybar `tnum` rule was not tested live. If it is ignored, use Pango `<span font_features='tnum'>` in formats.
- **Departure Mono and 0xProto** are not on Google Fonts or Fontsource. A browser specimen would need their GitHub release files (not checked).
- **Opinion sources.** The "why people love it" notes partly come from SEO-style roundup sites (fontalternatives.com, madegooddesigns.com). Treat them as community sentiment, not authority.
- **Monaspace NF families.** Monaspace 1.400 in nixpkgs already contains NF families; adding `nerd-fonts.monaspace` as well is redundant.
- **`ibm-plex`.** It defaults to all families, including CJK, which is large. `ibm-plex.override { families = [ "sans" "mono" ]; }` exists (the `families` argument was verified; the exact accepted values were not).
- **Not verified:** whether the Google Fonts versions of Geist Mono and Cascadia match the nixpkgs versions glyph-for-glyph. Minor differences are possible.
## sources
https://commitmono.com/ (smart kerning via calt)
https://monaspace.githubnext.com/ (texture healing via calt; Neon/Argon/Xenon/Radon/Krypton styles)
https://ghostty.org/docs/config/reference (font-family fallback, font-feature syntax, font-thicken macOS-only)
https://github.com/ghostty-org/ghostty/discussions/9257 (JetBrains Mono + Symbols Nerd Font built in)
https://docs.gtk.org/gtk3/css-properties.html (font-feature-settings supported, no font-variation-settings)
https://fontalternatives.com/alternatives/sf-pro-display/with/modern/ (Inter/Geist as SF Pro alternatives)
https://fontalternatives.com/blog/best-free-monospace-fonts-2026/
https://madegooddesigns.com/?p=3198 (2026 programming font roundup: JetBrains Mono, Geist Mono, Berkeley Mono $75)
https://ossinsight.io/analyze/subframe7536/maple-font (Maple Mono features/popularity)
https://cdn.jsdelivr.net/npm/lucide-static@0.563.0/font/info.json (Lucide codepoints)
https://fonts.googleapis.com/css2?family=<Name> (live existence checks, 200/400)
https://api.fontsource.org/v1/fonts/<id> (Fontsource checks for commit-mono, monaspace-*, maple-mono, iosevka)
nix eval/nix build against /home/tushar/nixos-config flake-pinned nixpkgs + fc-scan for family names