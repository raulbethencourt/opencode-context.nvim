local M = {}
local ui = require("opencode-context.ui")
local config = require("opencode-context.config")
local context = require("opencode-context.context")
local placeholders = require("opencode-context.placeholders")
local tmux = require("opencode-context.tmux")

--- Send an interactive prompt to opencode with placeholder support
--- Detects visual mode and pre-populates with @selection if applicable
--- Available placeholders: @file, @buffers, @cursor, @selection, @diagnostics
--- @return nil
function M.send_prompt()
	-- Check if we're in visual mode and pre-populate with @selection
	local mode = vim.api.nvim_get_mode().mode
	local default_text = ""
	if mode == "v" or mode == "V" or mode == "\22" then -- \22 is visual block mode
		default_text = "@selection "
	end

	vim.ui.input({
		prompt = "Enter prompt for opencode: ",
		default = default_text,
	}, function(input)
		if not input or input == "" then
			return
		end

		local processed_prompt = placeholders.replace_placeholders(input)
		tmux.send_to_opencode(processed_prompt)
	end)
end

--- Toggle opencode between planning and build mode
--- Sends a Tab key to the opencode pane to switch modes
--- @return boolean: true if toggle was successful, false otherwise
function M.toggle_mode()
	local pane = tmux.find_opencode_pane()
	if not pane then
		vim.notify(
			"No opencode pane found in current window. Make sure opencode is running in a pane in this tmux window.",
			vim.log.levels.ERROR
		)
		return false
	end

	-- Send tab key to toggle between planning/build mode
	local cmd = string.format("tmux send-keys -t %s Tab", pane)
	vim.fn.system(cmd)

	if vim.v.shell_error == 0 then
		vim.notify(string.format("Toggled opencode mode (%s)", pane), vim.log.levels.INFO)
		return true
	else
		vim.notify("Failed to toggle opencode mode", vim.log.levels.ERROR)
		return false
	end
end

--- Create a callback function that processes placeholders and sends to opencode
--- @return function: Callback function that takes a prompt string and sends it to opencode
local function create_send_callback()
	return function(prompt)
		local processed_prompt = placeholders.replace_placeholders(prompt)
		return tmux.send_to_opencode(processed_prompt)
	end
end

--- Show the persistent prompt window for opencode
--- Creates a floating or split window based on configuration
--- @return nil
function M.show_persistent_prompt()
	ui.show_persistent_prompt(create_send_callback())
end

--- Hide the persistent prompt window
--- @return nil
function M.hide_persistent_prompt()
	ui.hide_persistent_prompt()
end

--- Toggle the persistent prompt window visibility
--- Shows if hidden, hides if visible
--- @return nil
function M.toggle_persistent_prompt()
	ui.toggle_persistent_prompt(create_send_callback())
end

--- Setup the plugin with user configuration options
--- @param opts? table<string, any>: Configuration options to merge with defaults
--- @return nil
function M.setup(opts)
	config.setup(opts)
end

return M
