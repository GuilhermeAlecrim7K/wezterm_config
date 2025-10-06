local wezterm = require("wezterm")

local module = {}

function module.apply_to_config(config)
	config.color_scheme = "Catppuccin Mocha"

	config.font_dirs = { "fonts" }
	config.font_locator = "ConfigDirsOnly"
	-- [
	-- Reference
	-- abcdefghijklmnopqrstuvwxyz
	-- ABCDEFGHIJKLMNOPQRSTUVWXYZ
	-- oO08 iIlL1 {} [] g9qCGQ ~-+=>
	-- ]
	config.font = wezterm.font_with_fallback({
		"Iosevka Nerd Font",
		"UbuntuMono Nerd Font",
		"Hack",
		"Hasklig",
		"Lilex Nerd Font",
		"Fira Code",
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
