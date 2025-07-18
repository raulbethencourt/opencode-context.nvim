local M = {}

M.config = {
	-- Tmux settings
	tmux_target = nil, -- Manual override: "session:window.pane"
	auto_detect_pane = true, -- Auto-detect opencode pane in current window
}

local function get_current_file_path()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	-- Convert to relative path from cwd
	local relative_path = vim.fn.fnamemodify(filename, ":~:.")
	return relative_path
end

local function get_buffers_paths()
	local buffers = vim.api.nvim_list_bufs()
	local file_paths = {}

  for _, bufnr in ipairs(buffers) do
    if vim.bo[bufnr].buflisted then			local filename = vim.api.nvim_buf_get_name(bufnr)
			if filename and filename ~= "" then
				-- Convert to relative path from cwd
				local relative_path = vim.fn.fnamemodify(filename, ":~:.")
				table.insert(file_paths, relative_path)
			end
		end
	end

	if #file_paths == 0 then
		return "No buffers"
	end

	return table.concat(file_paths, ", ")
end

local function get_cursor_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor[1]
	local col_num = cursor[2] + 1
	return string.format("File: %s, Line: %d, Column: %d", filename, line_num, col_num)
end

local function get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	local start_line = start_pos[2] - 1
	local end_line = end_pos[2]
	local start_col = start_pos[3] - 1
	local end_col = end_pos[3]

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_col + 1, end_col)
	elseif #lines > 1 then
		lines[1] = string.sub(lines[1], start_col + 1)
		lines[#lines] = string.sub(lines[#lines], 1, end_col)
	end

	local selection = table.concat(lines, "\n")
	return string.format("File: %s (lines %d-%d)\n\n%s", filename, start_line + 1, end_line, selection)
end

local function get_diagnostics()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_line = cursor[1] - 1 -- Convert to 0-based indexing

	-- Get diagnostics for current line only
	local diagnostics = vim.diagnostic.get(bufnr, { lnum = current_line })

	if #diagnostics == 0 then
		return "No diagnostics found on current line"
	end

	local content_parts = {}

	for _, diagnostic in ipairs(diagnostics) do
		local severity = vim.diagnostic.severity[diagnostic.severity]
		local line = diagnostic.lnum + 1
		local col = diagnostic.col + 1

		local message = string.format("[%s] Line %d, Col %d: %s", severity, line, col, diagnostic.message)

		if diagnostic.source then
			message = message .. string.format(" (%s)", diagnostic.source)
		end

		table.insert(content_parts, message)
	end

	return table.concat(content_parts, ", ")
end

local function replace_placeholders(prompt)
	local replacements = {
		["@buffers"] = get_buffers_paths, -- Process @buffers FIRST
		["@file"] = get_current_file_path, -- Then @file
		["@selection"] = get_visual_selection,
		["@diagnostics"] = get_diagnostics,
		["@cursor"] = get_cursor_info,
	}

	for placeholder, func in pairs(replacements) do
		if prompt:find(placeholder, 1, true) then
			local replacement = func()
			prompt = prompt:gsub(placeholder:gsub("[@]", "%%@"), replacement)
		end
	end

	return prompt
end

local function find_opencode_pane()
	-- If manual target is set, use it
	if M.config.tmux_target then
		return M.config.tmux_target
	end

	if not M.config.auto_detect_pane then
		return nil
	end

	-- Get current session and window
	local current_session_cmd = "tmux display-message -p '#{session_name}'"
	local current_window_cmd = "tmux display-message -p '#{window_index}'"

	local session_handle = io.popen(current_session_cmd .. " 2>/dev/null")
	local window_handle = io.popen(current_window_cmd .. " 2>/dev/null")

	if not session_handle or not window_handle then
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
		local handle = io.popen(cmd .. " 2>/dev/null")
		if handle then
			local result = handle:read("*a"):gsub("\n", "")
			handle:close()
			if result and result ~= "" then
				return result
			end
		end
	end

	return nil
end

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

function M.send_prompt()
	vim.ui.input({
		prompt = "Enter prompt for opencode (use @file, @cursor, @selection, @diagnostics): ",
		default = "",
	}, function(input)
		if not input or input == "" then
			return
		end

		local processed_prompt = replace_placeholders(input)
		send_to_opencode(processed_prompt)
	end)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M

