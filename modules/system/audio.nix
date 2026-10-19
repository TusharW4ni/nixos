{ ... }: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # The `dnd` script mutes Slack/Discord streams. Don't let WirePlumber
    # remember that mute, or they'd stay silent after DND ends.
    wireplumber.extraConfig."90-dnd-apps" = {
      "stream.rules" = [{
        matches = [
          { "application.process.binary" = "slack"; }
          { "application.process.binary" = ".Discord-wrapped"; }
        ];
        actions.update-props."state.restore-props" = false;
      }];
    };
  };
}
