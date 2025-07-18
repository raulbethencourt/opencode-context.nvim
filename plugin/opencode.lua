if vim.g.loaded_opencode then
  return
end
vim.g.loaded_opencode = 1

local opencode = require("opencode-context")

vim.api.nvim_create_user_command("OpencodeSend", function()
  opencode.send_prompt()
end, {
  desc = "Send prompt to opencode with placeholder support"
})

local function create_keymaps()
  vim.keymap.set("n", "<leader>oc", opencode.send_prompt, { desc = "Send prompt to opencode" })
  vim.keymap.set("v", "<leader>oc", opencode.send_prompt, { desc = "Send prompt to opencode" })
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = create_keymaps,
  once = true,
})