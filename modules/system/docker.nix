{ ... }: {
  virtualisation.docker.enable = true;

  # Weekly `docker system prune`: stopped containers, unused networks, and
  # images + build cache nothing has used for a week. Volumes are never touched.
  virtualisation.docker.autoPrune = {
    enable = true;
    flags = [ "--all" "--filter" "until=168h" ];
  };
}
