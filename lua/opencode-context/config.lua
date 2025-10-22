local M = {}

M.defaults = {
	-- Tmux settings
	tmux_target = nil, -- Manual override: "session:window.pane"
	auto_detect_pane = true, -- Auto-detect opencode pane in current window

	-- UI settings
	ui = {
		window_type = "float", -- "float" or "split"
		float = {
			width = 0.9, -- Percentage of editor width (0.0-1.0)
			height = 1, -- Number of lines
			border = "solid", -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
			position = "bottom", -- "top", "bottom", "center"
			margin = 2, -- Margin from edges
		},
		split = {
			position = "bottom", -- "top", "bottom", "left", "right"
			size = 8, -- Number of lines/columns for split
		},
	},
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

function M.get()
	return M.config or M.defaults
end

return M