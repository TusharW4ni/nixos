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
-- Every monitor at its preferred mode. The layout editor (hyprmon, hub >
-- displays) writes per-output overrides to ~/.local/state/hyprmon/hyprmon.lua,
-- a mutable file outside the repo; it's optional, hence pcall.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
pcall(dofile, home .. "/.local/state/hyprmon/hyprmon.lua")

------------------------------------------------------------------------------
-- Look and input
------------------------------------------------------------------------------
hl.env("NIXOS_OZONE_WL", "1")
hl.env("XCURSOR_THEME", "capitaine-cursors-white") -- matches home.pointerCursor
hl.env("XCURSOR_SIZE", "24")

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
  -- Capitaine is an XCursor theme; with hyprcursor on, Hyprland falls back
  -- to its own default cursor instead.
  cursor = { enable_hyprcursor = false },
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
-- Session services (bar, notifications, DND watcher, ...) are systemd user
-- units started with graphical-session.target; nothing to start here.

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

-- Focus
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }), "Focus " .. dir)
end

-- Workspaces: 10 groups of 10. Super + `/1-9 picks a slot in the current
-- group, Super + Shift + `/1-9 switches group, Super + Ctrl + `/1-9 moves the
-- window to a slot. id = group * 10 + slot, with ` as group 0 and slot 10:
-- group ` is 1-10 (the plain 1-9 stay put), group 1 is 11-20, group 9 91-100.
local group_last = {} -- group -> workspace last left there; resets on reload

local function group_of(id) return math.floor((id - 1) / 10) end
local function current_group()
  local ws = hl.get_active_workspace()
  return (ws and ws.id >= 1) and group_of(ws.id) or 0
end

for n = 0, 9 do
  local key = n == 0 and "grave" or tostring(n)
  local label = n == 0 and "`" or key
  local slot = n == 0 and 10 or n
  bind(mod .. " + " .. key, function()
    hl.dispatch(hl.dsp.focus({ workspace = current_group() * 10 + slot }))
  end, "Go to slot " .. label .. " in this group")
  bind(mod .. " + CTRL + " .. key, function()
    hl.dispatch(hl.dsp.window.move({ workspace = current_group() * 10 + slot }))
  end, "Move window to slot " .. label .. " in this group")
  bind(mod .. " + SHIFT + " .. key, function()
    local ws = hl.get_active_workspace()
    if ws and ws.id >= 1 then group_last[group_of(ws.id)] = ws.id end
    hl.dispatch(hl.dsp.focus({ workspace = group_last[n] or n * 10 + 1 }))
  end, "Switch to workspace group " .. label)
end

bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }), "Previous workspace (toggle)")
bind(mod .. " + bracketleft", hl.dsp.focus({ workspace = "e-1" }), "Previous open workspace")
bind(mod .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }), "Next open workspace")

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
