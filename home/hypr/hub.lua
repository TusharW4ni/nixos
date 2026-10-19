-- Settings hub, power menu, keybind cheat sheet and lid handling.
-- The hub itself is the `hub` script (home/hub/), shown in a floating Ghostty
-- window with class dev.tushar.hub.

local mod = "SUPER"
local class = "dev.tushar.hub"

hl.window_rule({
  name = "hub",
  match = { class = "^(dev\\.tushar\\.hub)$" },
  float = true,
  center = true,
  size = "900 600",
})

-- Open the hub (optionally at a section). If a hub window is already open,
-- focus it instead; this also absorbs a power key that fires twice.
local function hub(section)
  return function()
    local open = hl.get_windows({ class = class })
    if open and #open > 0 then
      hl.dispatch(hl.dsp.focus({ window = "class:^(dev\\.tushar\\.hub)$" }))
    else
      hl.exec_cmd("ghostty --class=" .. class .. " -e hub " .. (section or ""))
    end
  end
end

hl.bind(mod .. " + A", hub(), { description = "Settings hub" })
hl.bind(mod .. " + slash", hub("keys"), { description = "Keybind cheat sheet" })
hl.bind(mod .. " + Escape", hub("power"), { description = "Power menu" })
hl.bind("XF86PowerOff", hub("power"), { description = "Power menu" })

-- Lid: docked (more than one monitor) -> just turn the laptop screen off;
-- undocked -> logind suspends and hypridle locks first. Opening the lid
-- reloads the config, which brings eDP-1 back at its hyprmon position.
hl.bind("switch:on:Lid Switch", function()
  if #hl.get_monitors() > 1 then
    hl.monitor({ output = "eDP-1", disabled = true })
  end
end, { locked = true, description = "Lid closed: laptop screen off when docked" })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"),
  { locked = true, description = "Lid opened: restore laptop screen" })
