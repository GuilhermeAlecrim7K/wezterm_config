local wezterm = require("wezterm")
local background_switcher = require("background_switcher")

local module = {}

function module.apply_to_config(config)
	-- TODO: Must create a \\ map to override leader and actually send a \
	-- config.leader = { key = "\\" }

	config.keys = {
		{
			key = "B",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(background_switcher.callback),
		},
		{
			key = "}",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function(_)
				background_switcher.adjust_brightness(0.001)
			end),
		},
		{
			key = "{",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function(_)
				background_switcher.adjust_brightness(-0.001)
			end),
		},
	}
end

return module
