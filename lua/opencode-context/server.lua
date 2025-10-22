local M = {}

local config = require("opencode-context.config")
local tmux = require("opencode-context.tmux")

--- Fetch list of opencode sessions from server
--- @return table|nil, string|nil: List of {id, title} or nil and error message
function M.fetch_sessions()
	local hostname = config.get().server_hostname
	local port = config.get().server_port
	local url = "http://" .. hostname .. ":" .. tostring(port) .. "/session"

	local output = vim.fn.system("curl -s " .. vim.fn.shellescape(url))
	if vim.v.shell_error ~= 0 then
		-- Try to start the server
		vim.notify("Opencode server not running, attempting to start...", vim.log.levels.INFO)
		vim.fn.system("opencode serve --hostname " .. hostname .. " --port " .. tostring(port) .. " &")
		vim.fn.system("sleep 3") -- Wait for server to start

		-- Retry fetching
		output = vim.fn.system("curl -s " .. vim.fn.shellescape(url))
		if vim.v.shell_error ~= 0 then
			return nil, "Cannot connect to opencode server"
		end
	end

	local ok, data = pcall(vim.json.decode, output)
	if not ok or not data then
		return nil, "Invalid JSON response from server"
	end

	local sessions
	if data.sessions then
		sessions = data.sessions
	elseif type(data) == "table" then
		sessions = data
	else
		return nil, "Unexpected response format from server"
	end

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
		table.insert(items, { text = session.title .. " (" .. session.id .. ")", value = session.id })
	end

	vim.ui.select(items, {
		prompt = "Select opencode session:",
		format_item = function(item)
			return item.text
		end,
	}, function(choice)
		if choice then
			tmux.open_session_pane(choice.value)
		end
	end)
end

return M