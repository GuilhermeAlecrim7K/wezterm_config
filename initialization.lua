local wezterm = require("wezterm")

local module = {}

function module.apply_to_config(config)
	local launch_menu = {}
	if wezterm.target_triple == "x86_64-pc-windows-msvc" then
		-- NOTE: I don't know what this does yet. What matters for initialization is `defaul_prog`
		table.insert(launch_menu, {
			label = "PowerShell",
			args = { "pwsh.exe", "-NoLogo" },
		})
		config.default_prog = { "pwsh.exe", "-NoLogo" }
	end
	config.launch_menu = launch_menu
end

return module
