local wezterm = require("wezterm")
local state_manager = require("state_manager")

local module = {}

local MODULE_NAME = "session"
local MAX_HISTORY = 5
local SNAPSHOT_INTERVAL_SECONDS = 30
local PATH_SEPARATOR = package.config:sub(1, 1)

-- WezTerm exposes no window-closed or application-exit event, so the layout is sampled
-- periodically instead of being captured on the way out. Keeping a short history is what
-- makes that safe: a snapshot taken while windows are being torn down one by one cannot
-- destroy the good layout, it only pushes it one slot down.

local function is_enabled()
	local enabled = state_manager.get(MODULE_NAME, "enabled")
	if enabled == nil then
		return true
	end
	return enabled
end

local function get_history()
	return state_manager.get(MODULE_NAME, "history") or {}
end

-- On Windows a cwd URL resolves to "/C:/Projetos/". Turn it into "C:\Projetos", which is
-- what the spawn APIs expect.
local function normalize_path(path)
	if not path or path == "" then
		return nil
	end

	if PATH_SEPARATOR == "\\" then
		path = path:gsub("^/(%a:)", "%1")
		path = path:gsub("/", "\\")
	end

	-- Trim a trailing separator, but never shorten a root such as "C:\" or "/".
	if #path > 3 then
		path = path:gsub("[/\\]+$", "")
	end

	return path
end

local function pane_cwd(pane)
	local ok, cwd = pcall(function()
		return pane:get_current_working_dir()
	end)
	if not ok or not cwd then
		return nil
	end

	local path
	if type(cwd) == "userdata" and cwd.file_path then
		path = cwd.file_path
	else
		path = (tostring(cwd):gsub("^file://[^/]*", ""))
	end

	return normalize_path(path)
end

local function active_tab_index(mux_window, tabs)
	local ok, active = pcall(function()
		return mux_window:active_tab()
	end)
	if not ok or not active then
		return 1
	end

	for index, tab in ipairs(tabs) do
		if tab:tab_id() == active:tab_id() then
			return index
		end
	end

	return 1
end

-- Reads the live layout. Returns nil when there is nothing worth persisting, so a
-- degenerate snapshot never reaches the history.
local function capture()
	local mux_windows = wezterm.mux.all_windows()
	table.sort(mux_windows, function(left, right)
		return left:window_id() < right:window_id()
	end)

	local windows = {}
	for _, mux_window in ipairs(mux_windows) do
		local mux_tabs = mux_window:tabs()
		local tabs = {}

		for _, tab in ipairs(mux_tabs) do
			local pane = tab:active_pane()
			table.insert(tabs, {
				cwd = (pane and pane_cwd(pane)) or "",
				-- Empty for tabs the user never renamed, so the automatic title computed
				-- by tab_titles.lua keeps working after a restore.
				tab_title = tab:get_title() or "",
			})
		end

		if #tabs > 0 then
			table.insert(windows, {
				workspace = mux_window:get_workspace(),
				active_tab = active_tab_index(mux_window, mux_tabs),
				tabs = tabs,
			})
		end
	end

	if #windows == 0 then
		return nil
	end

	return {
		saved_at = wezterm.time.now():format("%Y-%m-%d %H:%M:%S"),
		windows = windows,
	}
end

-- Identifies a layout by its windows and tabs only. Switching the active tab must not be
-- enough to push a new history entry.
local function fingerprint(snapshot)
	local parts = {}

	for _, window in ipairs(snapshot.windows or {}) do
		table.insert(parts, "window:" .. tostring(window.workspace))
		for _, tab in ipairs(window.tabs or {}) do
			table.insert(parts, tostring(tab.cwd) .. "|" .. tostring(tab.tab_title))
		end
	end

	return table.concat(parts, "\n")
end

function module.latest()
	return get_history()[1]
end

-- Returns true when a new history entry was written.
function module.save()
	local snapshot = capture()
	if not snapshot then
		return false
	end

	local history = get_history()
	if history[1] and fingerprint(history[1]) == fingerprint(snapshot) then
		return false
	end

	table.insert(history, 1, snapshot)
	while #history > MAX_HISTORY do
		table.remove(history)
	end

	state_manager.set(MODULE_NAME, "history", history)
	return true
end

-- A stored path may be gone (deleted project, unmounted drive). Retry without a cwd so a
-- single stale entry cannot abort the whole restore.
local function spawn_with_fallback(spawner, cwd)
	local ok, tab, pane, window = pcall(spawner, cwd)
	if ok and tab then
		return tab, pane, window
	end

	if cwd then
		wezterm.log_warn("session_manager: could not spawn in " .. cwd .. ", using the default cwd")
		ok, tab, pane, window = pcall(spawner, nil)
		if ok and tab then
			return tab, pane, window
		end
	end

	wezterm.log_error("session_manager: failed to spawn: " .. tostring(tab))
	return nil
end

local function tab_cwd(tab_state)
	local cwd = tab_state and tab_state.cwd
	if not cwd or cwd == "" then
		return nil
	end
	return cwd
end

local function restore_window(window_state)
	local tabs_state = window_state.tabs or {}
	if #tabs_state == 0 then
		return nil
	end

	local first_tab, _, mux_window = spawn_with_fallback(function(cwd)
		return wezterm.mux.spawn_window({ cwd = cwd, workspace = window_state.workspace })
	end, tab_cwd(tabs_state[1]))

	if not mux_window then
		return nil
	end

	local tabs = { first_tab }
	for index = 2, #tabs_state do
		tabs[index] = spawn_with_fallback(function(cwd)
			return mux_window:spawn_tab({ cwd = cwd })
		end, tab_cwd(tabs_state[index]))
	end

	for index, tab in pairs(tabs) do
		local title = tabs_state[index] and tabs_state[index].tab_title
		if title and title ~= "" then
			tab:set_title(title)
		end
	end

	local active = tabs[window_state.active_tab or 1]
	if active then
		active:activate()
	end

	return mux_window
end

function module.restore(snapshot)
	if not snapshot or not snapshot.windows then
		return false
	end

	wezterm.GLOBAL.session_restoring = true

	-- This runs from gui-startup, so an error escaping here would leave the user with no
	-- window at all. Contain it, and make sure the flag is cleared either way, otherwise
	-- snapshots would stay suppressed for the rest of the session.
	local restored = 0
	local ok, err = pcall(function()
		for _, window_state in ipairs(snapshot.windows) do
			if restore_window(window_state) then
				restored = restored + 1
			end
		end
	end)

	wezterm.GLOBAL.session_restoring = false

	if not ok then
		wezterm.log_error("session_manager: restore interrupted: " .. tostring(err))
	end

	return restored > 0
end

-- Config reloads re-run this file and start a fresh loop. Older loops have to die,
-- otherwise every background image change (which calls wezterm.reload_configuration)
-- would stack another timer on top of the previous ones.
local function schedule_snapshot(generation)
	wezterm.time.call_after(SNAPSHOT_INTERVAL_SECONDS, function()
		if wezterm.GLOBAL.session_timer_generation ~= generation then
			return
		end

		if not wezterm.GLOBAL.session_restoring then
			pcall(module.save)
		end

		schedule_snapshot(generation)
	end)
end

local function startup(cmd)
	-- An explicit `wezterm start -- <prog>` or `--cwd` means the user asked for something
	-- specific; do not reopen a session on top of it.
	local explicit = cmd ~= nil and ((cmd.args and #cmd.args > 0) or cmd.cwd ~= nil)

	if explicit or not is_enabled() or not module.restore(module.latest()) then
		wezterm.mux.spawn_window(cmd or {})
	end
end

function module.save_now(window, _)
	local saved = module.save()
	window:toast_notification("WezTerm", saved and "Session saved" or "Session unchanged", nil)
end

function module.restore_menu(window, pane)
	local history = get_history()
	if #history == 0 then
		window:toast_notification("WezTerm", "No saved sessions yet", nil)
		return
	end

	local choices = {}
	for index, snapshot in ipairs(history) do
		local windows = snapshot.windows or {}
		local tab_count = 0
		for _, window_state in ipairs(windows) do
			tab_count = tab_count + #(window_state.tabs or {})
		end

		table.insert(choices, {
			id = tostring(index),
			label = string.format("%s - %d window(s), %d tab(s)", snapshot.saved_at or "unknown", #windows, tab_count),
		})
	end

	window:perform_action(
		wezterm.action.InputSelector({
			title = "Restore Session",
			description = "Choose a saved session to reopen:",
			fuzzy = true,
			choices = choices,
			---@diagnostic disable-next-line: unused-local
			action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
				if not id then
					-- User cancelled
					return
				end

				module.restore(history[tonumber(id)])
			end),
		}),
		pane
	)
end

function module.toggle_startup_restore(window, _)
	local enabled = not is_enabled()
	state_manager.set(MODULE_NAME, "enabled", enabled)
	window:toast_notification("WezTerm", "Session restore on startup: " .. (enabled and "ON" or "OFF"), nil)
end

---@diagnostic disable-next-line: unused-local
function module.apply_to_config(config)
	local generation = (wezterm.GLOBAL.session_timer_generation or 0) + 1
	wezterm.GLOBAL.session_timer_generation = generation

	wezterm.on("gui-startup", startup)

	schedule_snapshot(generation)
end

return module
