# System-wide keyboard remap via keyd (kernel-level, works in tty + Wayland).
{ ... }: {
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        # Dual-role Caps Lock: tap = Esc, hold = Ctrl.
        # (Previous Mac-style Cmd remap lived here; see git history.)
        main = {
          capslock = "overload(control, esc)";
        };
      };
    };
  };
}
