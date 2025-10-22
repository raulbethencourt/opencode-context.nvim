local M = {}
local config = require("opencode-context.config")

--- Create a new opencode pane in the specified session and window
--- @param session string: Tmux session name
--- @param window string: Tmux window index
--- @param session_id string|nil: Optional opencode session ID to attach to
--- @return string|nil: Tmux pane target identifier or nil if creation failed
local function create_opencode_pane(session, window, session_id)
	local direction = config.get().split_direction == "vertical" and "-h" or "-v"
	local opencode_cmd
	if session_id then
		local hostname = config.get().server_hostname
		local port = config.get().server_port
		opencode_cmd = string.format("opencode attach http://%s:%d -s %s", hostname, port, session_id)
	else
		opencode_cmd = "opencode"
	end
	local cmd = string.format("tmux split-window -P -F '#{pane_index}' %s '%s'", direction, vim.fn.shellescape(opencode_cmd))

	local ok, handle = pcall(io.popen, cmd .. " 2>/dev/null")
	if not ok or not handle then
		return nil
	end

	local pane_index = handle:read("*a"):gsub("\n", "")
	handle:close()

  if pane_index and pane_index ~= "" and vim.v.shell_error == 0 then
    local target = string.format("%s:%s.%s", session, window, pane_index)
    vim.notify(string.format("Created new opencode pane (%s)", target), vim.log.levels.INFO)

    -- Wait for opencode to start
    vim.fn.system("sleep 3")

    -- Check if opencode is running in the pane
    local check_cmd = string.format("tmux display-message -p -t %s '#{pane_current_command}'", target)
    local ok, result = pcall(io.popen, check_cmd .. " 2>/dev/null")
    if ok and result then
      local command = result:read("*a"):gsub("\n", "")
      result:close()
      if command == "opencode" then
        return target
      else
        vim.notify("Opencode may not have started properly in the pane. Please check manually.", vim.log.levels.WARN)
        return target  -- Still return target since pane was created
      end
    else
      vim.notify("Could not verify opencode in pane, but pane was created.", vim.log.levels.WARN)
      return target
    end
  else
    vim.notify("Failed to create opencode pane", vim.log.levels.ERROR)
    return nil
  end
end

--- Open a new opencode pane
--- @return string|nil: Tmux pane target or nil if failed
local function open_opencode_pane()
	local current_session_cmd = "tmux display-message -p '#{session_name}'"
	local current_window_cmd = "tmux display-message -p '#{window_index}'"

	local session_ok, session_handle = pcall(io.popen, current_session_cmd .. " 2>/dev/null")
	local window_ok, window_handle = pcall(io.popen, current_window_cmd .. " 2>/dev/null")

	if not session_ok or not window_ok or not session_handle or not window_handle then
		return nil
	end

	local current_session = session_handle:read("*a"):gsub("\n", "")
	local current_window = window_handle:read("*a"):gsub("\n", "")
	session_handle:close()
	window_handle:close()

	if not current_session or current_session == "" or not current_window or current_window == "" then
		return nil
	end

	return create_opencode_pane(current_session, current_window, nil)
end

--- Open a new opencode pane attached to a specific session
--- @param session_id string: Opencode session ID to attach to
--- @return string|nil: Tmux pane target or nil if failed
local function open_session_pane(session_id)
	local current_session_cmd = "tmux display-message -p '#{session_name}'"
	local current_window_cmd = "tmux display-message -p '#{window_index}'"

	local session_ok, session_handle = pcall(io.popen, current_session_cmd .. " 2>/dev/null")
	local window_ok, window_handle = pcall(io.popen, current_window_cmd .. " 2>/dev/null")

	if not session_ok or not window_ok or not session_handle or not window_handle then
		return nil
	end

	local current_session = session_handle:read("*a"):gsub("\n", "")
	local current_window = window_handle:read("*a"):gsub("\n", "")
	session_handle:close()
	window_handle:close()

	if not current_session or current_session == "" or not current_window or current_window == "" then
		return nil
	end

	return create_opencode_pane(current_session, current_window, session_id)
end

--- Find the opencode pane in the current tmux session and window
--- Uses multiple strategies to detect the pane: current command, pane title, and command history
--- If not found and auto_create_pane is enabled, creates a new pane with opencode
--- @return string|nil, boolean: Tmux pane target identifier (e.g., "session:window.pane") or nil if not found or creation failed, and whether it was created
local function find_opencode_pane()
	-- If manual target is set, use it
	if config.get().tmux_target then
		return config.get().tmux_target, false
	end

	if not config.get().auto_detect_pane then
		return nil, false
	end

	-- Get current session and window
	local current_session_cmd = "tmux display-message -p '#{session_name}'"
	local current_window_cmd = "tmux display-message -p '#{window_index}'"

	local session_ok, session_handle = pcall(io.popen, current_session_cmd .. " 2>/dev/null")
	local window_ok, window_handle = pcall(io.popen, current_window_cmd .. " 2>/dev/null")

	if not session_ok or not window_ok or not session_handle or not window_handle then
		return nil, false
	end

	local current_session = session_handle:read("*a"):gsub("\n", "")
	local current_window = window_handle:read("*a"):gsub("\n", "")
	session_handle:close()
	window_handle:close()

	if not current_session or current_session == "" or not current_window or current_window == "" then
		return nil, false
	end

	-- Search for opencode pane in current window only
	local strategies = {
		-- Current command is opencode in current window
		string.format(
			"tmux list-panes -t %s:%s -F '#{session_name}:#{window_index}.#{pane_index}' -f '#{==:#{pane_current_command},opencode}'",
			current_session,
			current_window
		),

		-- Pane title contains opencode in current window
		string.format(
			"tmux list-panes -t %s:%s -F '#{session_name}:#{window_index}.#{pane_index}' -f '#{m:*opencode*,#{pane_title}}'",
			current_session,
			current_window
		),

		-- Recent command history contains opencode in current window
		string.format(
			"tmux list-panes -t %s:%s -F '#{session_name}:#{window_index}.#{pane_index} #{pane_start_command}' | grep opencode | head -1 | cut -d' ' -f1",
			current_session,
			current_window
		),
	}

	local pane = nil
	local was_created = false
	for _, cmd in ipairs(strategies) do
		local ok, handle = pcall(io.popen, cmd .. " 2>/dev/null")
		if ok and handle then
			local result = handle:read("*a"):gsub("\n", "")
			handle:close()
			if result and result ~= "" then
				pane = result
				break
			end
		end
	end

	if not pane and config.get().auto_create_pane then
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
		vim.notify(
			"No opencode pane found in current window. Make sure opencode is running in a pane in this tmux window.",
			vim.log.levels.ERROR
		)
		return false
	end

	-- Wait for opencode to start if pane was just created
	if was_created then
		vim.fn.system("sleep 2")
	end

	-- Send message directly to the pane
	local cmd = string.format("tmux send-keys -t %s %s Enter", pane, vim.fn.shellescape(message))
	vim.fn.system(cmd)

	if vim.v.shell_error == 0 then
		vim.notify(string.format("Sent prompt to opencode pane (%s)", pane), vim.log.levels.INFO)
		return true
	else
		vim.notify("Failed to send to opencode pane", vim.log.levels.ERROR)
		return false
	end
end

M.find_opencode_pane = find_opencode_pane
M.send_to_opencode = send_to_opencode
M.open_opencode_pane = open_opencode_pane
M.open_session_pane = open_session_pane

return M