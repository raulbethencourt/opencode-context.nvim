local M = {}

-- UI state
local prompt_win = nil
local prompt_buf = nil
local config = nil

local function get_config()
	-- Always get fresh config to handle setup() being called after initial load
	config = require("opencode-context").config
	return config
end

local function create_prompt_buffer()
	if prompt_buf and vim.api.nvim_buf_is_valid(prompt_buf) then
		return prompt_buf
	end

	prompt_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[prompt_buf].buftype = "nofile"
	vim.bo[prompt_buf].swapfile = false
	vim.bo[prompt_buf].filetype = "opencode-prompt"

	-- Set initial empty content
	vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { "" })

	return prompt_buf
end

local function setup_prompt_keymaps(bufnr, send_callback)
	local opts = { buffer = bufnr, silent = true }

	-- Enter to send prompt
	vim.keymap.set("i", "<CR>", function()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local prompt = table.concat(lines, "\n")

		-- Skip if empty
		if not prompt:match("%S") then
			return
		end

		if send_callback(prompt) then
			-- Clear the buffer after successful send
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
			-- Only set cursor if window is still valid
			if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
				vim.api.nvim_win_set_cursor(prompt_win, { 1, 0 })
			end
		end
	end, opts)

	-- Escape to return to normal mode
	vim.keymap.set("i", "<Esc>", function()
		vim.cmd("stopinsert")
	end, opts)

	-- Close prompt window with 'q' in normal mode
	vim.keymap.set("n", "q", function()
		M.hide_persistent_prompt()
	end, opts)
end

local function create_float_window(bufnr, send_callback)
	local cfg = get_config().ui.float
	local width = math.floor(vim.o.columns * (cfg.width or 0.9))
	local height = cfg.height or 1

	local row, col
	if cfg.position == "top" then
		row = cfg.margin or 2
		col = math.floor((vim.o.columns - width) / 2)
	elseif cfg.position == "bottom" then
		row = vim.o.lines - height - (cfg.margin or 2) - 1
		col = math.floor((vim.o.columns - width) / 2)
	else -- center
		row = math.floor((vim.o.lines - height) / 2)
		col = math.floor((vim.o.columns - width) / 2)
	end

	prompt_win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = cfg.border or "solid",
		title = " OpenCode - use @file, @buffers, @cursor, @selection, @diagnostics, @here",
		title_pos = "left",
	})

	-- Set window options
	vim.wo[prompt_win].wrap = true
	vim.wo[prompt_win].linebreak = true
end

local function create_split_window(bufnr, send_callback)
	local cfg = get_config().ui.split
	local position = cfg.position or "bottom"
	local size = cfg.size or 8

	-- Save current window
	local current_win = vim.api.nvim_get_current_win()

	if position == "top" then
		vim.cmd("topleft " .. size .. "split")
	elseif position == "bottom" then
		vim.cmd("botright " .. size .. "split")
	elseif position == "left" then
		vim.cmd("topleft " .. size .. "vsplit")
	else -- right
		vim.cmd("botright " .. size .. "vsplit")
	end

	prompt_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(prompt_win, bufnr)

	-- Return to original window
	vim.api.nvim_set_current_win(current_win)
end

function M.show_persistent_prompt(send_callback)
	if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
		vim.api.nvim_set_current_win(prompt_win)
		vim.cmd("startinsert")
		return
	end

	local bufnr = create_prompt_buffer()
	local cfg = get_config()

	if (cfg.ui and cfg.ui.window_type) == "split" then
		create_split_window(bufnr, send_callback)
	else
		create_float_window(bufnr, send_callback)
	end

	-- Setup keymaps for this buffer
	setup_prompt_keymaps(bufnr, send_callback)

	-- Start in insert mode
	vim.cmd("startinsert")

	-- Auto-hide on focus lost (only for float windows)
	if cfg.ui.window_type == "float" then
		vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
			buffer = bufnr,
			callback = function()
				vim.defer_fn(function()
					if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
						local current_win = vim.api.nvim_get_current_win()
						if current_win ~= prompt_win then
							M.hide_persistent_prompt()
						end
					end
				end, 100)
			end,
			once = false,
		})
	end
end

function M.hide_persistent_prompt()
	if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
		local cfg = get_config()
		if (cfg.ui and cfg.ui.window_type) == "split" then
			-- For split windows, close the split
			vim.api.nvim_win_close(prompt_win, false)
		else
			-- For float windows, close normally
			vim.api.nvim_win_close(prompt_win, false)
		end
		prompt_win = nil
	end
end

function M.toggle_persistent_prompt(send_callback)
	if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
		M.hide_persistent_prompt()
	else
		M.show_persistent_prompt(send_callback)
	end
end

function M.is_prompt_visible()
	return prompt_win and vim.api.nvim_win_is_valid(prompt_win)
end

return M
