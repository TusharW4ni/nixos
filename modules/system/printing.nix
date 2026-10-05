{ pkgs, ... }: {
  services.printing.enable = true;
  # HP-specific PPDs/plugins — CUPS' generic drivers don't cover most HP
  # printers, which is why adding one without this shows "driver not found".
  services.printing.drivers = [ pkgs.hplip ];
}
