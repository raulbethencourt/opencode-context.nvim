local M = {}

--- Default configuration options for the opencode-context plugin
--- @type table<string, any>
M.defaults = {
	-- Tmux settings
	tmux_target = nil, -- Manual override: "session:window.pane"
	auto_detect_pane = true, -- Auto-detect opencode pane in current window
	auto_create_pane = true, -- Auto-create opencode pane if not found
	split_direction = "vertical", -- "horizontal" or "vertical" for new pane

	-- Server settings
	server_hostname = "127.0.0.1", -- Opencode server hostname
	server_port = 4096, -- Opencode server port

	-- UI settings
	ui = {
		window_type = "float", -- "float" or "split"
		float = {
			width = 0.9, -- Percentage of editor width (0.0-1.0)
			height = 1, -- Number of lines
			border = "solid", -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
			position = "bottom", -- "top", "bottom", "center"
			margin = 2, -- Margin from edges
			title_pos = "left", -- Prompt window title position
		},
		split = {
			position = "bottom", -- "top", "bottom", "left", "right"
			size = 8, -- Number of lines/columns for split
		},
	},
}

--- Setup plugin configuration by merging user options with defaults
--- @param opts? table<string, any>: User configuration options to override defaults
--- @return nil
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Get the current plugin configuration
--- Returns the merged configuration if setup() was called, otherwise returns defaults
--- @return table<string, any>: Current configuration table
function M.get()
	return M.config or M.defaults
end

return M