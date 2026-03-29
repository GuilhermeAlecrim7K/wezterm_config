local state_manager = require("state_manager")
local appearance = require("appearance")
local background_switcher = require("background_switcher")
local initialization = require("initialization")
local keymaps = require("keymaps")
local command_palette = require("command_palette")
local general_options = require("general_options")

local wezterm = require("wezterm")
local config = wezterm.config_builder()

state_manager.init()
background_switcher.apply_to_config(config)
appearance.apply_to_config(config)
initialization.apply_to_config(config)
keymaps.apply_to_config(config)
command_palette.apply_to_config(config)
general_options.apply_to_config(config)

return config
