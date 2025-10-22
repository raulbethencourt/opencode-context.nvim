local M = {}

local config = require("opencode-context.config")

--- Fetch list of opencode sessions from server
--- @return table|nil, string|nil: List of {id, title} or nil and error message
function M.fetch_sessions()
	local cfg = config.get()
	--- @type string
	local hostname = cfg.server_hostname
	--- @type number
	local port = cfg.server_port
	local url = "http://" .. hostname .. ":" .. tostring(port) .. "/session"

	vim.notify("Fetching sessions from " .. url, vim.log.levels.DEBUG)
	local output = vim.fn.system("curl -s " .. vim.fn.shellescape(url))
	if vim.v.shell_error ~= 0 then
		vim.notify("Server unreachable at " .. url, vim.log.levels.DEBUG)
		-- Check if opencode command is available
		if not vim.fn.executable("opencode") then
			return nil, "opencode command not found. Please install opencode."
		end
		-- Try to start the server
		vim.notify("Opencode server not running, attempting to start...", vim.log.levels.INFO)
		vim.fn.system("opencode serve --hostname " .. hostname .. " --port " .. tostring(port) .. " &")
		vim.fn.system("sleep 2") -- Wait for server to start

		-- Retry fetching
		vim.notify("Retrying fetch after server start", vim.log.levels.DEBUG)
		output = vim.fn.system("curl -s " .. vim.fn.shellescape(url))
		if vim.v.shell_error ~= 0 then
			vim.notify("Server still unreachable after start attempt", vim.log.levels.DEBUG)
			return nil,
				"Failed to start opencode server. Please start it manually with 'opencode serve --hostname "
					.. hostname
					.. " --port "
					.. tostring(port)
					.. "'"
		end
	end

	local ok, data = pcall(vim.json.decode, output)
	if not ok or not data then
		return nil, "Invalid JSON response from server"
	end

	--- @type table[]
	local sessions = data

	if not sessions or #sessions == 0 then
		return nil, "No sessions available"
	end

	return sessions
end

--- Select and open an opencode session
--- @return nil
function M.select_session()
	local sessions, err = M.fetch_sessions()
	if not sessions then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	local items = {}
	for _, session in ipairs(sessions) do
		if
			session
			and type(session) == "table"
			and session.id
			and session.title
			and type(session.id) == "string"
			and type(session.title) == "string"
		then
			table.insert(items, { text = session.title .. " (" .. session.id .. ")", value = session.id })
		end
	end

	vim.ui.select(items, {
		prompt = "Select opencode session:",
		format_item = function(item)
			return item.text
		end,
	}, function(choice)
		if choice then
			require("opencode-context.tmux").open_session_pane(choice.value)
		end
	end)
end

return M