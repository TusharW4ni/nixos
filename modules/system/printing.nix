{ pkgs, ... }: {
  services.printing.enable = true;
  # HP-specific PPDs/plugins — CUPS' generic drivers don't cover most HP
  # printers, which is why adding one without this shows "driver not found".
  services.printing.drivers = [ pkgs.hplip ];
  # Default policy (stop-printer) disables the whole queue the first time the
  # printer is off/unplugged, and it stays disabled until cupsenable. Retry
  # the job instead: every 60s, up to 30 tries (~30 min), then abort the job.
  # Only applies to printers added after this; existing queues keep their own
  # policy in /var/lib/cups/printers.conf (set via lpadmin -o printer-error-policy).
  services.printing.extraConf = ''
    ErrorPolicy retry-job
    JobRetryInterval 60
    JobRetryLimit 30
  '';
}
