-- OpenCode Context Neovim Plugin
-- Provides integration between Neovim and opencode via tmux
-- Author: opencode-context.nvim contributors

-- Prevent double loading of plugin
if vim.g.loaded_opencode then
	return
end
vim.g.loaded_opencode = 1

-- Add doc directory to runtimepath for help
local plugin_dir = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p:h:h"), ":p")
vim.opt.runtimepath:append(plugin_dir .. "/doc")

-- Generate helptags
vim.cmd("silent! helptags " .. plugin_dir .. "/doc")

local opencode = require("opencode-context")
local tmux = require("opencode-context.tmux")
local server = require("opencode-context.server")

--- Create user command to send prompts to opencode with placeholder support
--- Usage: :OpencodeSend
vim.api.nvim_create_user_command("OpencodeSend", function()
	opencode.send_prompt()
end, {
	desc = "Send prompt to opencode with placeholder support",
})

--- Create user command to toggle opencode between planning and build mode
--- Usage: :OpencodeSwitchMode
vim.api.nvim_create_user_command("OpencodeSwitchMode", function()
	opencode.toggle_mode()
end, {
	desc = "Toggle opencode between planning and build mode",
})

--- Create user command to toggle the persistent opencode prompt window
--- Usage: :OpencodePrompt
vim.api.nvim_create_user_command("OpencodePrompt", function()
	opencode.toggle_persistent_prompt()
end, {
	desc = "Toggle persistent opencode prompt window",
})

--- Create user command to open a new opencode pane
--- Usage: :OpencodePane
vim.api.nvim_create_user_command("OpencodePane", function()
	tmux.open_opencode_pane()
end, {
	desc = "Open a new opencode pane in tmux",
})

--- Create user command to select and open an opencode session
--- Usage: :OpencodeSessions
vim.api.nvim_create_user_command("OpencodeSessions", function()
	server.select_session()
end, {
	desc = "Select and open an opencode session",
})

--- Create default keymaps for opencode functionality
--- Sets up <leader>oc, <leader>ot, <leader>op, and <space>os keymaps
--- @return nil
local function create_keymaps()
	vim.keymap.set({ "n", "v" }, "<leader>oc", opencode.send_prompt, { desc = "Send prompt to opencode" })
	vim.keymap.set("n", "<leader>ot", opencode.toggle_mode, { desc = "Toggle opencode mode" })
	vim.keymap.set(
		{ "n", "v" },
		"<leader>op",
		opencode.toggle_persistent_prompt,
		{ desc = "Toggle persistent opencode prompt" }
	)
	vim.keymap.set("n", "<space>on", tmux.open_opencode_pane, { desc = "Open new Opencode pane" })
	vim.keymap.set("n", "<space>os", server.select_session, { desc = "Select opencode session" })
end

--- Setup keymaps after Vim has fully started to avoid conflicts
vim.api.nvim_create_autocmd("VimEnter", {
	callback = create_keymaps,
	once = true,
})
