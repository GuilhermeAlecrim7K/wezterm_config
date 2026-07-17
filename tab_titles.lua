local wezterm = require("wezterm")

local module = {}

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

function module.apply_to_config(_)
	wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
		local pane = tab.active_pane
		local dir = cwd_name(pane)

		local title
		if dir ~= "" then
			title = dir
		else
			title = "shell"
		end

		local padded = " " .. title .. " "
		max_width = #padded
		return padded
	end)
end

return module
