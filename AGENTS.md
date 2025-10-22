# AGENTS.md - Development Guidelines

## Build/Test Commands

This is a Neovim Lua plugin - no build system required. Test by loading in Neovim with `:source %` or restarting Neovim. No formal test suite exists - manual testing required.

## Code Style Guidelines

### Lua Conventions

- Use 2-space indentation consistently
- Local variables with `local` keyword
- Module pattern: `local M = {}` and `return M`
- Snake_case for variables and functions
- Use `vim.` APIs instead of deprecated `vim.fn` where possible
- No semicolons or unnecessary parentheses

### Imports/Requires

- Place all `require()` statements at top of file
- Use descriptive variable names for required modules
- Group related requires together

### Error Handling

- Use `vim.notify()` for user messages with appropriate log levels (`vim.log.levels.INFO/ERROR/WARN`)
- Check return values from system calls (`vim.v.shell_error`)
- Validate inputs before processing (file handles, buffer existence)
- Use `pcall()` for potentially failing operations

### Naming Conventions

- Functions: snake_case (`send_current_buffer`)
- Typing: use types in functions
  Exemple :

```lua
---Creates alias for keymaps
---@param mode string|string[]
---@param keys string
---@param func string|function
---@param desc? string?
---@return nil
---
M.keymap = function(mode, keys, func, desc)
    if not desc or string.len(desc) == 0 then
        desc = 'keymap'
    end

    vim.keymap.set(mode, keys, func, { noremap = true, silent = true, desc = desc })
end
```

- Config keys: snake_case (`auto_detect_pane`)
- Commands: PascalCase with plugin prefix (`OpencodeSend`)
- Variables: snake_case, descriptive names
- Constants: UPPER_SNAKE_CASE

### Plugin Structure

- Main logic in `lua/opencode-context/init.lua`
- UI components in `lua/opencode-context/ui.lua`
- Commands and keymaps in `plugin/opencode.lua`
- Use guard clause pattern for plugin loading
- Follow Neovim plugin best practices