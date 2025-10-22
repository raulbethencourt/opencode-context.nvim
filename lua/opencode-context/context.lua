local M = {}

--- Check if a window is floating (has relative positioning)
--- @param winid number: Window ID to check
--- @return boolean: true if window is floating, false otherwise
local function is_floating(winid)
	local config = vim.api.nvim_win_get_config(winid)
	return config.relative ~= ""
end

--- Get the current file path relative to the working directory
--- Handles floating windows by falling back to the previous window
--- @return string: Relative path of the current file
local function get_current_file_path()
	local current_win = vim.api.nvim_get_current_win()
	local target_win = current_win

	if is_floating(current_win) then
		local prev_winnr = vim.fn.winnr("#")
		local prev_winid = vim.fn.win_getid(prev_winnr)

		if prev_winid ~= 0 and vim.api.nvim_win_is_valid(prev_winid) then
			target_win = prev_winid
		end
	end

	local bufnr = vim.api.nvim_win_get_buf(target_win)
	local filename = vim.api.nvim_buf_get_name(bufnr)

	-- Convert to relative path from cwd
	local relative_path = vim.fn.fnamemodify(filename, ":~:.")
	return relative_path
end

--- Get paths of all listed buffers as a comma-separated string
--- @return string: Comma-separated list of buffer file paths, or "No buffers" if none found
local function get_buffers_paths()
	local buffers = vim.api.nvim_list_bufs()
	local file_paths = {}

	for _, bufnr in ipairs(buffers) do
		if vim.bo[bufnr].buflisted then
			local filename = vim.api.nvim_buf_get_name(bufnr)
			if filename and filename ~= "" then
				-- Convert to relative path from cwd
				local relative_path = vim.fn.fnamemodify(filename, ":~:.")
				if relative_path and relative_path ~= "" then
					table.insert(file_paths, relative_path)
				end
			end
		end
	end

	if #file_paths == 0 then
		return "No buffers"
	end

	return table.concat(file_paths, ", ")
end

--- Get cursor position information including buffer number, file path, and cursor coordinates
--- Handles floating windows by falling back to the previous window
--- @return number: Buffer number
--- @return string: Relative file path
--- @return table: Cursor position as {line, column}
local function get_cursor()
	local current_win = vim.api.nvim_get_current_win()
	local target_win = current_win

	if is_floating(current_win) then
		local prev_winnr = vim.fn.winnr("#")
		local prev_winid = vim.fn.win_getid(prev_winnr)

		if prev_winid ~= 0 and vim.api.nvim_win_is_valid(prev_winid) then
			target_win = prev_winid
		end
	end

	local bufnr = vim.api.nvim_win_get_buf(target_win)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local relative_path = vim.fn.fnamemodify(filename, ":~:.")
	local cursor = vim.api.nvim_win_get_cursor(target_win)
	return bufnr, relative_path, cursor
end

--- Get formatted cursor information as a human-readable string
--- @return string: Formatted string with file path, line number, and column number
local function get_cursor_info()
	local _, relative_path, cursor = get_cursor()
	local line_num = cursor[1]
	local col_num = cursor[2] + 1

	return string.format("%s, Line: %d, Column: %d", relative_path, line_num, col_num)
end

--- Get visual selection details including file path, line range, and selected text
--- Works with current visual selection or last visual selection marks
--- Handles floating windows by falling back to the previous window
--- @return string: Relative file path
--- @return number: Start line (0-based)
--- @return number: End line (0-based)
--- @return string: Selected text content
local function get_visual_selection()
	local current_win = vim.api.nvim_get_current_win()
	local target_win = current_win

	if is_floating(current_win) then
		local prev_winnr = vim.fn.winnr("#")
		local prev_winid = vim.fn.win_getid(prev_winnr)

		if prev_winid ~= 0 and vim.api.nvim_win_is_valid(prev_winid) then
			target_win = prev_winid
		end
	end

	local bufnr = vim.api.nvim_win_get_buf(target_win)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local relative_path = vim.fn.fnamemodify(filename, ":~:.")

	local start_pos, end_pos

	-- Check if we're currently in visual mode
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then -- \22 is visual block mode
		-- In visual mode, use current selection
		start_pos = vim.fn.getpos("v")
		end_pos = vim.fn.getpos(".")

		-- Ensure start comes before end
		if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
			start_pos, end_pos = end_pos, start_pos
		end
	else
		-- Not in visual mode, use marks from last visual selection
		start_pos = vim.fn.getpos("'<")
		end_pos = vim.fn.getpos("'>")
	end

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

	return relative_path, start_line, end_line, selection
end

--- Get formatted visual selection with file path, line range, and content
--- @return string: Formatted string with file path, line range, and selected content
local function get_selection()
	local relative_path, start_line, end_line, selection = get_visual_selection()

	return string.format("%s (lines %d-%d) - `%s`", relative_path, start_line + 1, end_line, selection)
end

--- Get visual selection range without the actual content
--- @return string: Formatted string with file path and line range only
local function get_visual_range()
	local relative_path, start_line, end_line, _ = get_visual_selection()

	return string.format("%s (lines %d-%d)", relative_path, start_line + 1, end_line)
end

--- Get LSP diagnostics for the current cursor line
--- @return string: Formatted diagnostics string with file context, or empty string if no diagnostics
local function get_diagnostics()
	local bufnr, relative_path, cursor = get_cursor()
	local current_line = cursor[1] - 1 -- Convert to 0-based indexing

	-- Get diagnostics for current line only
	local diagnostics = vim.diagnostic.get(bufnr, { lnum = current_line })

	if #diagnostics == 0 then
		return ""
	end

	local content_parts = {}

	-- Add file context at the beginning
	table.insert(content_parts, string.format("File: %s", relative_path))

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

	return table.concat(content_parts, "\n")
end

M.get_current_file_path = get_current_file_path
M.get_buffers_paths = get_buffers_paths
M.get_cursor = get_cursor
M.get_cursor_info = get_cursor_info
M.get_visual_selection = get_visual_selection
M.get_selection = get_selection
M.get_visual_range = get_visual_range
M.get_diagnostics = get_diagnostics

return M