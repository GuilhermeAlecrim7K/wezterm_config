local wezterm = require("wezterm")
local background_switcher = require("background_switcher")

local module = {}

function module.apply_to_config(config)
	config.command_palette_font_size = 14.0
	wezterm.on("augment-command-palette", function()
		return {
			{
				brief = "Switch background image",
				icon = "md_image_multiple",
				action = wezterm.action_callback(function(window, pane)
					background_switcher.callback(window, pane)
				end),
			},
		}
	end)
end

return module
