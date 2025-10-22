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

vim.api.nvim_create_user_command("OpencodeSend", function()
	opencode.send_prompt()
end, {
	desc = "Send prompt to opencode with placeholder support",
})

vim.api.nvim_create_user_command("OpencodeSwitchMode", function()
	opencode.toggle_mode()
end, {
	desc = "Toggle opencode between planning and build mode",
})

vim.api.nvim_create_user_command("OpencodePrompt", function()
	opencode.toggle_persistent_prompt()
end, {
	desc = "Toggle persistent opencode prompt window",
})

local function create_keymaps()
	vim.keymap.set("n", "<leader>oc", opencode.send_prompt, { desc = "Send prompt to opencode" })
	vim.keymap.set("v", "<leader>oc", opencode.send_prompt, { desc = "Send prompt to opencode" })
	vim.keymap.set("n", "<leader>ot", opencode.toggle_mode, { desc = "Toggle opencode mode" })
	vim.keymap.set("n", "<leader>op", opencode.toggle_persistent_prompt, { desc = "Toggle persistent opencode prompt" })
end

vim.api.nvim_create_autocmd("VimEnter", {
	callback = create_keymaps,
	once = true,
})
