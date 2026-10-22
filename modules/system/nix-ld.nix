{ pkgs, ... }: {
  # nix-ld provides a stand-in dynamic linker (/lib64/ld-linux-*) plus a
  # library search path, so prebuilt (non-Nix) dynamically-linked binaries
  # run unpatched. Needed for things installed via upstream `curl | bash`
  # scripts that ship their own ELF binaries — e.g. terminal-browser, an
  # Electron app dropped into ~/.local/share/terminal-browser/app.
  programs.nix-ld = {
    enable = true;

    # Electron / Chromium runtime deps. The terminal-browser installer only
    # warns about libnss3/libgtk-3-0/libasound2t64/libgbm1, but Electron needs
    # the full X/GTK/graphics stack at runtime.
    libraries = with pkgs; [
      nss nspr
      atk at-spi2-atk at-spi2-core
      cups dbus expat glib
      gtk3 pango cairo gdk-pixbuf
      alsa-lib mesa libGL libdrm libgbm
      libx11 libxcb libxcomposite libxdamage
      libxext libxfixes libxrandr libxrender
      libxtst libxshmfence libxkbcommon
    ];
  };
}
