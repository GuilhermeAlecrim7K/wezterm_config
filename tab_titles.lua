local wezterm = require("wezterm")

local module = {}

local TAB_MAX_WIDTH = 32
local SEPARATOR = " - "
local ELLIPSIS = "..."
local FALLBACK_TITLE = "shell"

local function basename(path)
	if not path or path == "" then
		return ""
	end
	path = path:gsub("[/\\]+$", "")
	return path:match("[^/\\]+$") or path
end

local function cwd_name(pane)
	local cwd = pane.current_working_dir
	if not cwd then
		return ""
	end
	local path
	if type(cwd) == "userdata" and cwd.file_path then
		path = cwd.file_path
	else
		path = tostring(cwd)
	end
	path = path:gsub("^file://[^/]*", "")
	return basename(path)
end

local function proc_name(pane)
	local proc = pane.foreground_process_name
	if not proc or proc == "" then
		return ""
	end
	local name = basename(proc)
	return (name:gsub("%.[eE][xX][eE]$", ""))
end

-- Title used for tabs the user never named explicitly.
local function auto_title(pane)
	local dir = cwd_name(pane)
	local proc = proc_name(pane)

	if dir ~= "" and proc ~= "" then
		return dir .. SEPARATOR .. proc
	end
	if dir ~= "" then
		return dir
	end
	if proc ~= "" then
		return proc
	end
	return FALLBACK_TITLE
end

local function truncate(text, max_width)
	if not max_width or max_width <= 0 then
		return text
	end
	if wezterm.column_width(text) <= max_width then
		return text
	end

	-- Reserve room for the ellipsis; drop it entirely if it would not fit.
	local ellipsis_width = wezterm.column_width(ELLIPSIS)
	if max_width <= ellipsis_width then
		return wezterm.truncate_right(text, max_width)
	end
	return wezterm.truncate_right(text, max_width - ellipsis_width) .. ELLIPSIS
end

-- Prompts for a name and applies it to the active tab.
-- An empty submission clears the name, restoring the automatic title.
function module.rename_tab(window, pane)
	window:perform_action(
		wezterm.action.PromptInputLine({
			description = "Enter new tab name (empty to restore the automatic title):",
			action = wezterm.action_callback(function(inner_window, _, line)
				if line == nil then
					-- User cancelled
					return
				end

				inner_window:active_tab():set_title(line)
			end),
		}),
		pane
	)
end

function module.clear_tab_name(window, _)
	window:active_tab():set_title("")
end

function module.apply_to_config(config)
	config.tab_max_width = TAB_MAX_WIDTH

	wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
		-- A manually assigned name always wins over the computed one.
		local title = tab.tab_title
		if not title or title == "" then
			title = auto_title(tab.active_pane)
		end

		return truncate(" " .. title .. " ", max_width)
	end)
end

return module
