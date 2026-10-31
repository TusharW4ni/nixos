{ pkgs, ... }:
let
  # Stop charging at this %. Plugged in above it, the laptop runs on wall
  # power and the battery sits idle; it only drains when unplugged. Also
  # shown in the bar tooltip (home/waybar.nix).
  limit = "80";
  set = "${pkgs.coreutils}/bin/echo ${limit} | ${pkgs.coreutils}/bin/tee /sys/class/power_supply/BAT*/charge_control_end_threshold";
in
{
  # asus-wmi adds the threshold file after the battery appears, so set it when
  # asus-nb-wmi loads. Battery change events (plug, unplug, resume) set it
  # again in case the firmware reset it to 100.
  services.udev.extraRules = ''
    ACTION=="add", KERNEL=="asus-nb-wmi", RUN+="${pkgs.bash}/bin/sh -c '${set}'"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="BAT[0-9]", ATTR{charge_control_end_threshold}="${limit}"
  '';
}
