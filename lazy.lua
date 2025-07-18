return {
  "opencode-context.nvim",
  dev = true,
  opts = {
    -- Tmux settings
    tmux_target = nil,  -- Manual override: "session:window.pane"
    auto_detect_pane = true,  -- Auto-detect opencode pane in current window
  },
  keys = {
    { "<leader>oc", "<cmd>OpencodeSend<cr>", desc = "Send prompt to opencode" },
    { "<leader>oc", "<cmd>OpencodeSend<cr>", mode = "v", desc = "Send prompt to opencode" },
  },
  cmd = {
    "OpencodeSend",
  },
  config = function(_, opts)
    require("opencode-context").setup(opts)
  end,
}