local M = {}
local config = require("opencode-context.config")

--- Get current tmux session and window names
--- @return string|nil, string|nil: Current session name and window index, or nil if failed
local function get_current_session_window()
	local current_session_cmd = "tmux display-message -p '#{session_name}'"
	local current_window_cmd = "tmux display-message -p '#{window_index}'"

	local session_ok, session_handle = pcall(io.popen, current_session_cmd .. " 2>/dev/null")
	local window_ok, window_handle = pcall(io.popen, current_window_cmd .. " 2>/dev/null")

	if not session_ok or not window_ok or not session_handle or not window_handle then
		return nil, nil
	end

	--- @type string
	local current_session = session_handle:read("*a"):gsub("\n", "")
	--- @type string
	local current_window = window_handle:read("*a"):gsub("\n", "")
	session_handle:close()
	window_handle:close()

	return current_session, current_window
end

--- Create a new opencode pane in the specified session and window
--- @param session string: Tmux session name
--- @param window string: Tmux window index
--- @param session_id string|nil: Optional opencode session ID to attach to
--- @return string|nil: Tmux pane target identifier or nil if creation failed
local function create_opencode_pane(session, window, session_id)
	local cfg = config.get()
	local direction = cfg.split_direction == "vertical" and "-h" or "-v"
	local opencode_cmd
	if session_id then
		local hostname = cfg.server_hostname
		local port = cfg.server_port
		opencode_cmd = string.format("opencode attach http://%s:%d -s %s", hostname, port, session_id)
	else
		opencode_cmd = "opencode"
	end
	local cmd =
		string.format("tmux split-window -P -F '#{pane_index}' %s '%s'", direction, vim.fn.shellescape(opencode_cmd))

	local ok, handle = pcall(io.popen, cmd .. " 2>/dev/null")
	if not ok or not handle then
		return nil
	end

	local pane_index = handle:read("*a"):gsub("\n", "")
	handle:close()

	if pane_index and pane_index ~= "" and vim.v.shell_error == 0 then
		local target = string.format("%s:%s.%s", session, window, pane_index)
		vim.notify(string.format("Created new opencode pane (%s)", target), vim.log.levels.INFO)
		return target
	else
		vim.notify("Failed to create opencode pane", vim.log.levels.ERROR)
		return nil
	end
end

--- Open a new opencode pane
--- @return string|nil: Tmux pane target or nil if failed
local function open_opencode_pane()
	local current_session, current_window = get_current_session_window()
	if not current_session or current_session == "" or not current_window or current_window == "" then
		return nil
	end

	return create_opencode_pane(current_session, current_window, nil)
end

--- Open a new opencode pane attached to a specific session
--- @param session_id string: Opencode session ID to attach to
--- @return string|nil: Tmux pane target or nil if failed
local function open_session_pane(session_id)
	local current_session, current_window = get_current_session_window()
	if not current_session or current_session == "" or not current_window or current_window == "" then
		return nil
	end

	return create_opencode_pane(current_session, current_window, session_id)
end

--- Find the opencode pane in the current tmux session
--- Uses multiple strategies to detect the pane: current command, pane title, and command history
--- If not found and auto_create_pane is enabled, creates a new pane with opencode
--- @return string|nil, boolean: Tmux pane target identifier (e.g., "session:window.pane") or nil if not found or creation failed, and whether it was created
local function find_opencode_pane()
	local cfg = config.get()
	-- If manual target is set, use it
	if cfg.tmux_target then
		return cfg.tmux_target, false
	end

	if not cfg.auto_detect_pane then
		return nil, false
	end

	-- Get current session and window
	local current_session, current_window = get_current_session_window()
	if not current_session or current_session == "" or not current_window or current_window == "" then
		return nil, false
	end

	vim.notify("Searching for opencode pane in current tmux session", vim.log.levels.DEBUG)

	-- Search for opencode pane in current session
	local cmd = "tmux list-panes -sF '"
		.. "#{session_name}:#{window_index}.#{pane_index}|"
		.. "#{pane_current_command}|#{pane_start_command}|"
		.. "#{pane_title}|#{pane_current_path}'"

	local pane = nil
	local was_created = false
	local ok, handle = pcall(io.popen, cmd .. " 2>/dev/null")
	if ok and handle then
		local output = handle:read("*a")
		handle:close()
		for line in output:gmatch("[^\r\n]+") do
			local parts = {}
			for part in line:gmatch("[^|]+") do
				table.insert(parts, part)
			end
			if #parts >= 5 then
				local pane_id = parts[1]
				local current_cmd = parts[2]
				local start_cmd = parts[3]
				local title = parts[4]
				local path = parts[5]
				if
					(current_cmd:find("opencode") or start_cmd:find("opencode") or title:find("opencode"))
					and not (current_cmd:find("vim") or current_cmd:find("nvim"))
				then
					pane = pane_id
					vim.notify("Found opencode pane: " .. pane_id, vim.log.levels.DEBUG)
					break
				end
			end
		end
	end

	if not pane and cfg.auto_create_pane then
		pane = create_opencode_pane(current_session, current_window, nil)
		if pane then
			was_created = true
		end
	end

	return pane, was_created
end

--- Send a message to the opencode pane
--- Automatically finds the opencode pane and sends the message via tmux send-keys
--- @param message string: The message to send to the opencode pane
--- @return boolean: true if message was sent successfully, false otherwise
local function send_to_opencode(message)
	local pane, was_created = find_opencode_pane()
	if not pane then
		local current_session, _ = get_current_session_window()
		vim.notify(
			string.format(
				"No opencode pane found in session '%s'. Make sure opencode is running in a pane in this session.",
				current_session or "unknown"
			),
			vim.log.levels.ERROR
		)
		return false
	end

	vim.notify(string.format("Found opencode pane: %s", pane), vim.log.levels.DEBUG)

	-- Send message directly to the pane
	local function do_send()
		local cmd = string.format("tmux send-keys -t %s %s Enter", pane, vim.fn.shellescape(message))
		vim.notify(string.format("Running command: %s", cmd), vim.log.levels.DEBUG)
		local result = vim.fn.system(cmd)

		if vim.v.shell_error == 0 then
			vim.notify(string.format("Sent prompt to opencode pane (%s)", pane), vim.log.levels.INFO)
		else
			vim.notify(
				string.format("Failed to send to opencode pane, error: %d, output: %s", vim.v.shell_error, result),
				vim.log.levels.ERROR
			)
		end
	end

	if was_created then
		-- Wait for opencode to start, then send asynchronously
		vim.defer_fn(do_send, 2000)
		return true
	else
		do_send()
		return vim.v.shell_error == 0
	end
end

M.find_opencode_pane = find_opencode_pane
M.send_to_opencode = send_to_opencode
M.open_opencode_pane = open_opencode_pane
M.open_session_pane = open_session_pane

return M