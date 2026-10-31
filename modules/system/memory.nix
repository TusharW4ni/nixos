{ ... }: {
  # Compressed swap in RAM. Cold pages (idle Node heaps, background Chrome
  # tabs) compress roughly 3:1, so swapping them here is far faster than the
  # disk swap partition, which stays as overflow at a lower priority.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # device size, uncompressed; real RAM used is ~1/3 of what lands there
    priority = 100;     # before the disk swap partition (-2)
  };

  # Tuning for zram from the kernel docs / Arch wiki: swapping to RAM is cheap,
  # so prefer it over dropping file cache, and read one page at a time.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };
}
