local wezterm = require("wezterm")
local state_manager = require("state_manager")

local module = {}

local IMAGES_DIR = wezterm.home_dir .. "/.config/wezterm/images"

-- Scan images directory for available backgrounds
local function get_available_images()
	local images = {}
	local success, files = pcall(wezterm.read_dir, IMAGES_DIR)

	if not success then
		wezterm.log_error("Failed to read images directory: " .. IMAGES_DIR)
		return images
	end

	for _, filepath in ipairs(files) do
		-- Extract just the filename from the full path
		local filename = filepath:match("([^/]+)$")
		local lower_file = filename:lower()
		if lower_file:match("%.png$") or lower_file:match("%.jpg$") or lower_file:match("%.jpeg$") then
			table.insert(images, filename)
		end
	end

	table.sort(images)
	return images
end

local function get_current_background()
	return state_manager.get("background", "current_image") or "none"
end

local function save_background(background)
	return state_manager.set("background", "current_image", background or "none")
end

local function apply_background(config, background)
	if not background or background == "none" then
		config.background = nil
		return
	end

	local image_path = IMAGES_DIR .. "/" .. background
	config.background = config.background
		or {
			{
				source = { File = image_path },
				hsb = { brightness = 0.006 },
			},
		}
end

function module.apply_to_config(config)
	apply_background(config, get_current_background())
end

function module.callback(window, pane)
	local images = get_available_images()
	local choices = {}

	table.insert(choices, {
		id = "none",
		label = "None (Disable Background)",
	})

	-- Add each image as a choice
	for _, image in ipairs(images) do
		table.insert(choices, {
			id = image,
			label = image,
		})
	end

	window:perform_action(
		wezterm.action.InputSelector({
			title = "Select Background Image",
			description = "Choose a background image or None to disable:",
			fuzzy = true,
			choices = choices,
			---@diagnostic disable-next-line: unused-local
			action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
				if not id and not label then
					-- User cancelled
					return
				end

				save_background(id)
				wezterm.reload_configuration()
			end),
		}),
		pane
	)
end

return module
