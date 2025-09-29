local wezterm = require("wezterm")

local module = {}

function module.apply_to_config(config)
	config.animation_fps = 1
	config.cursor_blink_ease_in = "Constant"
	config.cursor_blink_ease_out = "Constant"

	config.default_cursor_style = "BlinkingBar"
	config.window_close_confirmation = "AlwaysPrompt"

	config.exit_behavior = "Hold"
	config.exit_behavior_messaging = "Verbose"

	config.enable_tab_bar = true
	config.hide_tab_bar_if_only_one_tab = true

	config.enable_scroll_bar = true
end

return module
