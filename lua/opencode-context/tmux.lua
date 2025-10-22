local M = {}
local config = require("opencode-context.config")

--- Find the opencode pane in the current tmux session and window
--- Uses multiple strategies to detect the pane: current command, pane title, and command history
--- @return string|nil: Tmux pane target identifier (e.g., "session:window.pane") or nil if not found
local function find_opencode_pane()
	-- If manual target is set, use it
	if config.get().tmux_target then
		return config.get().tmux_target
	end

	if not config.get().auto_detect_pane then
		return nil
	end

	-- Get current session and window
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

	for _, cmd in ipairs(strategies) do
		local ok, handle = pcall(io.popen, cmd .. " 2>/dev/null")
		if ok and handle then
			local result = handle:read("*a"):gsub("\n", "")
			handle:close()
			if result and result ~= "" then
				return result
			end
		end
	end

	return nil
end

--- Send a message to the opencode pane
--- Automatically finds the opencode pane and sends the message via tmux send-keys
--- @param message string: The message to send to the opencode pane
--- @return boolean: true if message was sent successfully, false otherwise
local function send_to_opencode(message)
	local pane = find_opencode_pane()
	if not pane then
		vim.notify(
			"No opencode pane found in current window. Make sure opencode is running in a pane in this tmux window.",
			vim.log.levels.ERROR
		)
		return false
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

return M