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
    resize_on_border = true, -- drag any window edge to resize (floats too)
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
-- units started with graphical-session.target. Apps that belong on a fixed
-- workspace start here, once per session (hyprland.start does not fire on
-- reload). Slot 1 lives on the external display, slot 2 on the laptop panel;
-- without the external display both fall back to the panel.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "eDP-1", default = true })

hl.on("hyprland.start", function()
  hl.exec_cmd("ghostty -e herdr", { workspace = 1 })
  hl.exec_cmd("google-chrome-stable --profile-directory=Default", { workspace = 2 }) -- parone.com profile
  hl.exec_cmd("slack", { workspace = 3, float = true })
  hl.exec_cmd("discord", { workspace = 3, float = true })
  hl.exec_cmd("obsidian", { workspace = 4 })
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

-- Focus
for _, step in ipairs({ { "ALT + TAB", true, "Next" }, { "ALT + SHIFT + TAB", false, "Previous" } }) do
  bind(step[1], function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = step[2] }))
    hl.dispatch(hl.dsp.window.bring_to_top()) -- floats overlap; raise the focused one
  end, step[3] .. " window in this workspace")
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }), "Focus " .. dir)
end

-- Workspaces: 10 groups of 10. Super + `/1-9 picks a slot in the current
-- group, Super + Ctrl + `/1-9 switches group. Super + Shift + `/1-9 moves the
-- window to a slot in this group, Super + Ctrl + Shift + `/1-9 to another
-- group. id = group * 10 + slot, with ` as group 0 and slot 10: group ` is
-- 1-10 (the plain 1-9 stay put), group 1 is 11-20, group 9 is 91-100.
-- The numpad mirrors the row: KP_0 acts as `, KP_1-9 as 1-9. Bound by
-- keycode, so it works with NumLock on or off.
local function group_of(id) return math.floor((id - 1) / 10) end
local group_last = {} -- group -> workspace last active there; resets on reload
hl.on("workspace.active", function(ws)
  if ws and ws.id >= 1 then group_last[group_of(ws.id)] = ws.id end
end)

local function current_group()
  local ws = hl.get_active_workspace()
  return (ws and ws.id >= 1) and group_of(ws.id) or 0
end
local function group_target(n) return group_last[n] or n * 10 + 1 end

local keypad = { [0] = 90, 87, 88, 89, 83, 84, 85, 79, 80, 81 } -- KP_0-9 keycodes
for n = 0, 9 do
  local label = n == 0 and "`" or tostring(n)
  local slot = n == 0 and 10 or n
  for _, key in ipairs({ n == 0 and "grave" or tostring(n), "code:" .. keypad[n] }) do
    bind(mod .. " + " .. key, function()
      hl.dispatch(hl.dsp.focus({ workspace = current_group() * 10 + slot }))
    end, "Go to slot " .. label .. " in this group")
    bind(mod .. " + SHIFT + " .. key, function()
      hl.dispatch(hl.dsp.window.move({ workspace = current_group() * 10 + slot }))
    end, "Move window to slot " .. label .. " in this group")
    bind(mod .. " + CTRL + " .. key, function()
      hl.dispatch(hl.dsp.focus({ workspace = group_target(n) }))
    end, "Switch to workspace group " .. label)
    bind(mod .. " + CTRL + SHIFT + " .. key, function()
      if n ~= current_group() then hl.dispatch(hl.dsp.window.move({ workspace = group_target(n) })) end
    end, "Move window to workspace group " .. label)
  end
end

-- Step through the open workspaces of the current group, wrapping around.
local function cycle(step)
  return function()
    local cur = hl.get_active_workspace()
    if not cur or cur.id < 1 then return end
    local ids = {}
    for _, ws in ipairs(hl.get_workspaces()) do
      if ws.id >= 1 and group_of(ws.id) == group_of(cur.id) then ids[#ids + 1] = ws.id end
    end
    table.sort(ids)
    for i, id in ipairs(ids) do
      if id == cur.id then
        return hl.dispatch(hl.dsp.focus({ workspace = ids[(i - 1 + step) % #ids + 1] }))
      end
    end
  end
end

-- Float workspaces: Super + Shift + F toggles the current workspace between
-- tiling and float-only. Every window opened on or moved to a float workspace
-- floats. The set is kept in a mutable state file outside the repo so it
-- survives reloads.
local float_file = home .. "/.local/state/hypr/float-workspaces"
local float_ws = {} -- workspace id -> true
local f = io.open(float_file)
if f then
  for line in f:lines() do float_ws[tonumber(line) or 0] = true end
  f:close()
end

local function set_float(w, on)
  hl.dispatch(hl.dsp.window.float({ action = on and "enable" or "disable", window = "address:" .. w.address }))
end

local function float_all()
  for id in pairs(float_ws) do
    for _, w in ipairs(hl.get_workspace_windows(id)) do
      if not w.floating then set_float(w, true) end
    end
  end
end
hl.on("window.open", float_all)
hl.on("window.move_to_workspace", float_all)

bind(mod .. " + SHIFT + F", function()
  local ws = hl.get_active_workspace()
  if not ws then return end
  local on = not float_ws[ws.id]
  float_ws[ws.id] = on or nil
  for _, w in ipairs(hl.get_workspace_windows(ws.id)) do
    if w.floating ~= on then set_float(w, on) end
  end
  os.execute("mkdir -p '" .. home .. "/.local/state/hypr'")
  local out = io.open(float_file, "w")
  if out then
    for id in pairs(float_ws) do out:write(id, "\n") end
    out:close()
  end
end, "Toggle float-only mode for this workspace")

bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }), "Previous workspace (toggle)")
bind(mod .. " + bracketleft", cycle(-1), "Previous open workspace in this group")
bind(mod .. " + bracketright", cycle(1), "Next open workspace in this group")

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

-- Hex dictation (programs.hex in home/tushar.nix). Hyprland's GlobalShortcuts
-- portal grants Hex the shortcut without a key, so the key recorded in Hex's
-- Settings is ignored and the bind has to live here. Hex waits for the
-- shortcut's release before pasting, so the modifiers are up by then.
bind("SHIFT + SPACE", hl.dsp.global("anomaly.hex:dictation"), "Dictate (Hex)")
bind("CTRL + ALT + V", hl.dsp.global("anomaly.hex:paste-last"), "Paste last dictation (Hex)")
