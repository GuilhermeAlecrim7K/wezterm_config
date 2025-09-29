local appearance = require("appearance")
local initialization = require("initialization")
local keymaps = require("keymaps")
local general_options = require("general_options")

local wezterm = require("wezterm")
local config = wezterm.config_builder()

appearance.apply_to_config(config)
initialization.apply_to_config(config)
keymaps.apply_to_config(config)
general_options.apply_to_config(config)

return config
