local M = {}

-- UI state
local prompt_win = nil
local prompt_buf = nil
local config_module = require("opencode-context.config")

--- Placeholder completion function for omnifunc
--- Provides completion for @placeholders when typing in the prompt
--- @param findstart number: 1 to find start position, 0 to return completion items
--- @param base string: The text to complete (when findstart is 0)
--- @return number|table: Start position when findstart=1, completion items when findstart=0
local function placeholder_complete(findstart, base)
	if findstart == 1 then
		-- Find the start of the word after '@'
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local start = col
		while start > 0 and line:sub(start, start) ~= "@" do
			start = start - 1
		end
		if start > 0 and line:sub(start, start) == "@" then
			return start + 1 -- start after @
		end
		return -1 -- no completion if no @
	else
		-- Return completion items
		local items = {}
		local placeholders = {
			{ word = "buffers", abbr = "@buffers", menu = "All buffer file paths" },
			{ word = "file", abbr = "@file", menu = "Current file path" },
			{ word = "selection", abbr = "@selection", menu = "Visual selection content" },
			{ word = "range", abbr = "@range", menu = "Visual selection range" },
			{ word = "diagnostics", abbr = "@diagnostics", menu = "LSP diagnostics" },
			{ word = "here", abbr = "@here", menu = "Cursor position info" },
			{ word = "cursor", abbr = "@cursor", menu = "Cursor position info" },
		}
		for _, ph in ipairs(placeholders) do
			if base == "" or ph.word:find(base, 1, true) then
				table.insert(items, ph)
			end
		end
		return items
	end
end

--- Get the current plugin configuration
--- Always fetches fresh config to handle setup() being called after initial load
--- @return table<string, any>: Current configuration table
local function get_config()
	-- Always get fresh config to handle setup() being called after initial load
	return config_module.get()
end

--- Create or reuse the prompt buffer with proper settings
--- @return number: Buffer number for the prompt buffer
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

--- Setup keymaps for the prompt buffer
--- Configures completion, sending, and navigation keybindings
--- @param bufnr number: Buffer number to set keymaps on
--- @param send_callback function: Callback function to send prompts
--- @return nil
local function setup_prompt_keymaps(bufnr, send_callback)
	local opts = { buffer = bufnr, silent = true }

	-- Set up completion
	vim.bo[bufnr].omnifunc = "v:lua.require'opencode-context.ui'.placeholder_complete"

	-- Auto-trigger completion when typing "@"
	vim.keymap.set("i", "@", function()
		return "@<C-x><C-o>"
	end, { buffer = bufnr, expr = true })

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

	-- Ctrl-Space to trigger completion
	vim.keymap.set("i", "<C-c>", "<C-x><C-o>", opts)

	-- Escape to return to normal mode
	vim.keymap.set("i", "<Esc>", function()
		vim.cmd("stopinsert")
	end, opts)

	-- Close prompt window with 'q' in normal mode
	vim.keymap.set("n", "q", function()
		M.hide_persistent_prompt()
	end, opts)
end

--- Create a floating window for the prompt buffer
--- Positions the window based on configuration settings
--- @param bufnr number: Buffer number to display in the window
--- @param send_callback function: Callback function for sending prompts
--- @return nil
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
		title = " OpenCode",
		title_pos = cfg.title_pos or "left",
	})

	-- Set window options
	vim.wo[prompt_win].wrap = true
	vim.wo[prompt_win].linebreak = true
end

--- Create a split window for the prompt buffer
--- Creates a horizontal or vertical split based on configuration
--- @param bufnr number: Buffer number to display in the window
--- @param send_callback function: Callback function for sending prompts
--- @return nil
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

--- Show the persistent prompt window
--- Creates a floating or split window based on configuration and sets up keymaps
--- @param send_callback function: Callback function to handle prompt submission
--- @return nil
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

--- Hide the persistent prompt window
--- Closes the window appropriately based on window type (float vs split)
--- @return nil
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

--- Toggle the persistent prompt window visibility
--- Shows the prompt if hidden, hides if visible
--- @param send_callback function: Callback function to handle prompt submission
--- @return nil
function M.toggle_persistent_prompt(send_callback)
	if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
		M.hide_persistent_prompt()
	else
		M.show_persistent_prompt(send_callback)
	end
end

--- Check if the prompt window is currently visible
--- @return nil|boolean: true if prompt window exists and is valid, false otherwise
function M.is_prompt_visible()
	return prompt_win and vim.api.nvim_win_is_valid(prompt_win)
end

-- Expose completion function for omnifunc
M.placeholder_complete = placeholder_complete

return M
