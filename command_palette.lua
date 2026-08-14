local wezterm = require("wezterm")
local background_switcher = require("background_switcher")
local tab_titles = require("tab_titles")

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
			{
				brief = "Rename tab",
				icon = "md_rename_box",
				action = wezterm.action_callback(function(window, pane)
					tab_titles.rename_tab(window, pane)
				end),
			},
			{
				brief = "Clear tab name",
				icon = "md_backspace",
				action = wezterm.action_callback(function(window, pane)
					tab_titles.clear_tab_name(window, pane)
				end),
			},
		}
	end)
end

return module
