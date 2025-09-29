local wezterm = require("wezterm")

local module = {}

function module.apply_to_config(config)
	config.color_scheme = "Dracula"

	-- TODO: load fonts from "fonts" directory in wezterm.lua root
	-- config.font_dirs = { "fonts" }
	-- config.font_locator = "ConfigDirsOnly"
	config.font = wezterm.font_with_fallback({
		"UbuntuMono Nerd Font",
		"Fira Code",
		"Cascadia Code",
	})
	config.font_size = 12

	config.enable_tab_bar = false

	config.window_padding = {
		left = 8,
		right = 8,
		top = 0,
		bottom = 8,
	}
end

return module
