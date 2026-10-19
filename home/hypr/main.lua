-- Hyprland config (Lua). home/hyprland.nix installs this as
-- ~/.config/hypr/main.lua, and the home-manager-generated hyprland.lua
-- require()s it. Every bind carries a description: `keys` (Super+/) lists
-- them live from `hyprctl binds -j`, so this file is the cheat sheet's source.

local mod = "SUPER"
local home = os.getenv("HOME")

-- bind(keys, dispatcher, description[, opts]) with the description folded into opts.
local function bind(keys, dispatcher, description, opts)
  opts = opts or {}
  opts.description = description
  hl.bind(keys, dispatcher, opts)
end
local run = hl.dsp.exec_cmd

------------------------------------------------------------------------------
-- Monitors
------------------------------------------------------------------------------
-- Every monitor at its preferred mode. The layout editor (hyprmon) writes
-- per-output overrides to ~/.config/hypr/hyprmon.lua, a mutable file outside
-- the repo; it's optional, hence pcall.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
pcall(dofile, home .. "/.config/hypr/hyprmon.lua")

------------------------------------------------------------------------------
-- Look and input
------------------------------------------------------------------------------
hl.env("NIXOS_OZONE_WL", "1")

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    natural_scroll = false,
    touchpad = { natural_scroll = false },
  },
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    col = {
      active_border = "rgb(5c5c5c)",
      inactive_border = "rgb(1c1c1c)",
    },
  },
  decoration = { rounding = 6 },
  misc = {
    background_color = 0xff000000,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})

hl.layer_rule({ name = "vicinae-no-anim", match = { namespace = "vicinae" }, no_anim = true })

------------------------------------------------------------------------------
-- Autostart
------------------------------------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("dnd watch") -- keeps Slack/Discord muted while DND is on
end)

------------------------------------------------------------------------------
-- Binds
------------------------------------------------------------------------------
-- Apps and windows
bind(mod .. " + Q", run("ghostty"), "Terminal")
bind(mod .. " + SPACE", run("vicinae toggle"), "Launcher (apps, calc, f files, v clipboard, c Claude)")
bind(mod .. " + SHIFT + V", run("vicinae deeplink vicinae://launch/clipboard/history"), "Clipboard history")
bind(mod .. " + C", hl.dsp.window.close(), "Close window")
bind(mod .. " + F", hl.dsp.window.fullscreen(), "Fullscreen")
bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + SHIFT + M", hl.dsp.exit(), "Exit Hyprland")

-- Focus
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }), "Focus " .. dir)
end

-- Workspaces 1-9
for i = 1, 9 do
  bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), "Go to workspace " .. i)
  bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end

-- Super + drag to move / resize windows
bind(mod .. " + mouse:272", hl.dsp.window.drag(), "Move window (drag)", { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window (drag)", { mouse = true })

-- Screenshots: copied + saved to ~/ss/pics; click the banner to edit in satty
bind(mod .. " + SHIFT + S", run("shot region"), "Screenshot region")
bind("Print", run("shot monitor"), "Screenshot monitor")
bind(mod .. " + S", run("shot monitor"), "Screenshot monitor")

-- Screen recording (press again to stop, then it opens in Shotcut)
bind(mod .. " + SHIFT + R", run("screenrec region"), "Record region")
bind(mod .. " + R", run("screenrec monitor"), "Record monitor")

-- Notifications
bind(mod .. " + D", run("dnd"), "Toggle do not disturb")
bind(mod .. " + N", run("makoctl restore"), "Restore last notification")
bind(mod .. " + SHIFT + N", run("makoctl dismiss -a"), "Dismiss all notifications")

-- Media keys (also on the lock screen)
bind("XF86AudioPlay", run("media play-pause"), "Play / pause", { locked = true })
bind("XF86AudioPause", run("media play-pause"), "Play / pause", { locked = true })
bind("XF86AudioNext", run("media next"), "Next track", { locked = true })
bind("XF86AudioPrev", run("media previous"), "Previous track", { locked = true })

-- Volume / brightness (repeat while held, also on the lock screen)
local held = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up", held)
bind("XF86AudioLowerVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Volume down", held)
bind("XF86AudioMute", run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute", { locked = true })
bind("XF86MonBrightnessUp", run("brightnessctl set 5%+"), "Brightness up", held)
bind("XF86MonBrightnessDown", run("brightnessctl set 5%-"), "Brightness down", held)
