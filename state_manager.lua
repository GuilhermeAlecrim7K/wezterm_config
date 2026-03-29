local wezterm = require("wezterm")

local module = {}

local STATE_FILE = wezterm.home_dir .. "/.config/wezterm/config_state.lua"

local DEFAULT_STATE = {}

local function load_state_file()
	local file = io.open(STATE_FILE, "r")
	if not file then
		return DEFAULT_STATE
	end

	local content = file:read("*all")
	file:close()

	-- Safely load the state
	local chunk, err = load("return " .. content)
	if not chunk then
		wezterm.log_error("Failed to parse state file: " .. tostring(err))
		return DEFAULT_STATE
	end

	local success, state = pcall(chunk)
	if not success then
		wezterm.log_error("Failed to load state: " .. tostring(state))
		return DEFAULT_STATE
	end

	return state or DEFAULT_STATE
end

local function save_state_file(state)
	local file = io.open(STATE_FILE, "w")
	if not file then
		wezterm.log_error("Failed to open state file for writing: " .. STATE_FILE)
		return false
	end

	-- Serialize state as Lua table
	local function serialize(tbl, indent)
		indent = indent or ""
		local lines = {}
		table.insert(lines, "{")

		for key, value in pairs(tbl) do
			local key_str = type(key) == "string" and string.format('%s["%s"] = ', indent .. "\t", key)
				or string.format("%s[%s] = ", indent .. "\t", tostring(key))

			if type(value) == "table" then
				table.insert(lines, key_str .. serialize(value, indent .. "\t") .. ",")
			elseif type(value) == "string" then
				table.insert(lines, string.format('%s"%s",', key_str, value))
			elseif type(value) == "boolean" or type(value) == "number" then
				table.insert(lines, string.format("%s%s,", key_str, tostring(value)))
			else
				-- Skip unsupported types
				wezterm.log_warn("Skipping unsupported type for key " .. tostring(key) .. ": " .. type(value))
			end
		end

		table.insert(lines, indent .. "}")
		return table.concat(lines, "\n")
	end

	local serialized = serialize(state)
	file:write(serialized)
	file:close()
	return true
end

function module.get(module_name, key)
	local state = load_state_file()
	if not state[module_name] then
		return nil
	end
	return state[module_name][key]
end

function module.set(module_name, key, value)
	local state = load_state_file()

	if not state[module_name] then
		state[module_name] = {}
	end

	state[module_name][key] = value

	return save_state_file(state)
end

function module.get_module_state(module_name)
	local state = load_state_file()
	return state[module_name] or {}
end

function module.set_module_state(module_name, module_state)
	local state = load_state_file()
	state[module_name] = module_state
	return save_state_file(state)
end

function module.get_all()
	return load_state_file()
end

function module.init()
	local file = io.open(STATE_FILE, "r")
	if not file then
		return save_state_file(DEFAULT_STATE)
	end
	file:close()
	return true
end

return module
