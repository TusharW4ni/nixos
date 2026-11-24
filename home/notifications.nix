# Notifications: Quickshell banners that decay into a persistent pane
# (Super+N), manual DND, screenshot/media banners, and low-battery alerts.
{ pkgs, ... }:
let
  script = name: runtimeInputs: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    text = builtins.readFile ./scripts/${name}.sh;
  };
  notif = script "notif" (with pkgs; [ quickshell jq ]);
  dnd = script "dnd" ([ notif ] ++ (with pkgs; [ jq pulseaudio gnugrep ]));
  shot = script "shot" (with pkgs; [ grim slurp wl-clipboard jq libnotify satty util-linux coreutils ]);
  media = script "media" (with pkgs; [ playerctl libnotify coreutils ]);
in
{
  home.packages = [ notif dnd shot media pkgs.libnotify pkgs.playerctl ];

  # Banners, the pane and the notification server: ./quickshell/shell.qml.
  programs.quickshell = {
    enable = true;
    configs.shell = ./quickshell;
    activeConfig = "shell";
    systemd.enable = true;
  };
  systemd.user.services.quickshell.Unit.PartOf = [ "graphical-session.target" ];
  systemd.user.tmpfiles.rules = [ "d %h/.local/state/notifications/img - - - -" ];

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
