local M = {}
local context = require("opencode-context.context")

local function replace_placeholders(prompt)
	local replacements = {
		["@buffers"] = context.get_buffers_paths, -- Process @buffers FIRST
		["@file"] = context.get_current_file_path, -- Then @file
		["@selection"] = context.get_selection,
		["@range"] = context.get_visual_range,
		["@diagnostics"] = context.get_diagnostics,
		["@here"] = context.get_cursor_info,
		["@cursor"] = context.get_cursor_info,
	}

	for placeholder, func in pairs(replacements) do
		if prompt:find(placeholder, 1, true) then
			local replacement = func()
			prompt = prompt:gsub(placeholder:gsub("[@]", "%%@"), replacement)
		end
	end

	return prompt
end

M.replace_placeholders = replace_placeholders

return M