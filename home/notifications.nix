# Notifications: black mako banners that never auto-dismiss, manual DND,
# screenshot/media banners, and low-battery alerts.
{ pkgs, ... }:
let
  script = name: runtimeInputs: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    text = builtins.readFile ./scripts/${name}.sh;
  };
  dnd = script "dnd" (with pkgs; [ mako jq pulseaudio procps gnugrep ]);
  shot = script "shot" (with pkgs; [ grim slurp wl-clipboard jq libnotify satty util-linux coreutils ]);
  media = script "media" (with pkgs; [ playerctl libnotify coreutils ]);
in
{
  home.packages = [ dnd shot media pkgs.libnotify pkgs.playerctl ];

  services.mako = {
    enable = true;
    settings = {
      font = "Atkinson Hyperlegible Next 11";
      background-color = "#000000";
      text-color = "#e6e6e6";
      border-color = "#333333";
      border-size = 1;
      border-radius = 0;
      padding = "10,14";
      margin = 8;
      width = 380;
      max-icon-size = 96;
      layer = "overlay";
      default-timeout = 0; # never auto-dismiss
      ignore-timeout = 1;  # ...even when the app asks for a timeout
      history = 1;
      max-history = 100;
      "urgency=critical" = { border-color = "#ff8080"; };
      # DND hides banners; they reappear when DND ends. Critical ones
      # (low battery) still show.
      "mode=dnd" = { invisible = 1; };
      "mode=dnd urgency=critical" = { invisible = 0; };
    };
  };

  # Keeps Slack/Discord streams muted while DND is on. Supervised, so it
  # comes back if pipewire-pulse restarts (`pactl subscribe` exits with it).
  systemd.user.services.dnd-watch = {
    Unit = {
      Description = "Mute Slack/Discord sounds while DND is on";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "pipewire-pulse.service" ];
    };
    Service = {
      ExecStart = "${dnd}/bin/dnd watch";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Media keys act on the most recently active player.
  services.playerctld.enable = true;

  # Warn at 20%, critical at 10%, suspend at 5%.
  services.batsignal = {
    enable = true;
    extraArgs = [ "-w" "20" "-c" "10" "-d" "5" "-D" "systemctl suspend" ];
  };
}
