{ config, pkgs, ... }: {
  # Session plumbing for the Hyprland-only desktop. Replaces plasma.nix on the
  # vivobook and re-adds what Plasma used to turn on implicitly.

  # Login: greetd + tuigreet, a black text login on tty1 that starts Hyprland.
  services.greetd = {
    enable = true;
    useTextGreeter = true; # keep boot messages from drawing over the greeter
    settings.default_session.command = builtins.concatStringsSep " " [
      "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks"
      "--cmd ${config.programs.hyprland.package}/bin/start-hyprland"
      "--theme 'border=darkgray;text=white;prompt=white;time=darkgray;action=darkgray;button=white;container=black;input=white'"
    ];
  };

  # Secret store (replaces kwallet). PAM unlocks it at login, since greetd's
  # stack includes `login`.
  services.gnome.gnome-keyring.enable = true;
  # Setting this overrides Hyprland's own portal config, so keep `default`.
  xdg.portal.config.hyprland = {
    default = [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
  };

  # PAM service for the lock screen; without it hyprlock can't unlock.
  programs.hyprlock.enable = true;

  # Services Plasma turned on implicitly.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.udisks2.enable = true;
  services.fwupd.enable = true;
  programs.fuse.enable = true; # fusermount wrappers (rclone mounts)

  # Power key and lid. A short power-key press goes to Hyprland (power menu);
  # holding it still powers off. Lid: suspend when undocked, ignore when an
  # external monitor is connected (Hyprland turns eDP-1 off instead).
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
