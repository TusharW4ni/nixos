# Status bar: pure black, Atkinson Hyperlegible Next, thin Lucide line icons.
# Approved look: docs/superpowers/specs/2026-10-19-hyprland-polish-research/bar-mockup.html (variant C).
# Signals: 8 = DND (dnd toggle refreshes it), 9 = mic.
{ pkgs, ... }:
let
  # Lucide maps letters and digits to icons too, so it's only ever used
  # inside a span, never in the font-family list. Codepoints: lucide 0.563.0.
  ic = cp: "<span font_family='lucide'>&#x${cp};</span>";
  # Battery glyphs are short and wide, so they sit visibly above the digits
  # next to them; nudge them down (rise is in Pango units, 1024 = 1pt).
  icLow = cp: "<span font_family='lucide' rise='-1600'>&#x${cp};</span>";
  dim = text: "<span color='#5c5c5c'>${text}</span>";

  mic = pkgs.writeShellApplication {
    name = "mic";
    runtimeInputs = with pkgs; [ pipewire wireplumber jq procps gnugrep ];
    text = builtins.readFile ./scripts/mic.sh;
  };
in
{
  home.packages = [ mic pkgs.brightnessctl ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "custom/clock" ];
      modules-right = [
        "custom/recording"
        "custom/dnd"
        "custom/mic"
        "backlight"
        "pulseaudio"
        "bluetooth"
        "network"
        "battery"
      ];

      # e.g. "Fri 10/16 · 14:32:07"
      "custom/clock" = {
        exec = "date '+%a %m/%d · %H:%M:%S'";
        interval = 1;
        tooltip = false;
      };
      # "● REC 0:42" while recording, hidden otherwise. Click to stop.
      "custom/recording" = {
        exec = "screenrec status";
        interval = 1;
        on-click = "screenrec";
      };
      # Amber bell-off + hidden count while DND is on, hidden otherwise.
      "custom/dnd" = {
        exec = "dnd status";
        return-type = "json";
        interval = 2; # keeps the hidden count fresh
        signal = 8;
        on-click = "dnd";
      };
      # Always visible: dim when idle, red while an app is capturing, mic-off when muted.
      "custom/mic" = {
        exec = "mic";
        return-type = "json";
        interval = 1;
        signal = 9;
        on-click = "mic toggle";
      };
      backlight = {
        device = "intel_backlight";
        format = "${ic "e178"}  ${dim "{percent}%"}";
        tooltip = false;
        on-click = "hub brightness";
        on-scroll-up = "brightnessctl -q set 5%+";
        on-scroll-down = "brightnessctl -q set 5%-";
      };
      pulseaudio = {
        format = "${ic "e1ab"}  ${dim "{volume}%"}";
        format-muted = ic "e1ac";
        tooltip-format = "{desc}";
        on-click = "hub audio";
      };
      # Shown only while a device is connected.
      bluetooth = {
        format = "";
        format-disabled = "";
        format-off = "";
        format-connected = ic "e1b8";
        tooltip-format-connected = "{device_alias}";
        on-click = "hub bluetooth";
      };
      network = {
        format-wifi = ic "e1ae";
        format-ethernet = ic "e620";
        format-disconnected = ic "e1af";
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
        tooltip-format-ethernet = "{ifname}";
        tooltip-format-disconnected = "offline";
        on-click = "hub wifi";
      };
      battery = {
        states = { warning = 20; critical = 10; };
        format = "{icon}  {capacity}%";
        format-charging = "${icLow "e054"}  {capacity}%";
        format-icons = [ (icLow "e056") (icLow "e057") (icLow "e055") ]; # low, medium, full
        tooltip-format = "{timeTo}";
      };
    };

    style = ''
      * {
        font-family: "Atkinson Hyperlegible Next";
        font-size: 15px;
        font-feature-settings: "tnum";
        border: none;
        border-radius: 0;
        min-height: 0;
        box-shadow: none;
      }
      window#waybar {
        background: #000000;
        color: #e6e6e6;
      }
      tooltip {
        background: #000000;
        border: 1px solid #333333;
      }
      tooltip label {
        color: #e6e6e6;
      }
      #workspaces button {
        padding: 0 7px;
        color: #5c5c5c;
        background: transparent;
      }
      #workspaces button:hover {
        background: #121212;
        color: #e6e6e6;
      }
      #workspaces button.active {
        color: #ffffff;
      }
      #workspaces button.urgent {
        color: #ff8080;
      }
      #custom-recording,
      #custom-mic.live,
      #battery.critical:not(.charging) {
        color: #ff8080;
      }
      #custom-dnd,
      #battery.warning:not(.charging) {
        color: #f5a524;
      }
      #custom-mic.idle,
      #custom-mic.muted,
      #pulseaudio.muted,
      #network.disconnected {
        color: #5c5c5c;
      }
      #custom-recording, #custom-dnd, #custom-mic, #backlight,
      #pulseaudio, #bluetooth, #network, #battery {
        padding: 0 9px;
      }
      #workspaces {
        padding-left: 6px;
      }
      #battery {
        padding-right: 14px;
      }
    '';
  };
}
