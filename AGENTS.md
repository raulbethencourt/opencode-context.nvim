# AGENTS.md - Development Guidelines

## Build/Test Commands
This is a Neovim Lua plugin - no build system required. Test by loading in Neovim.

## Code Style Guidelines

### Lua Conventions
- Use 2-space indentation
- Local variables with `local` keyword
- Module pattern: `local M = {}` and `return M`
- Snake_case for variables and functions
- Use `vim.` APIs instead of deprecated `vim.fn` where possible

### Imports/Requires
- Place all `require()` statements at top of file
- Use descriptive variable names for required modules

### Error Handling
- Use `vim.notify()` for user messages with appropriate log levels
- Check return values from system calls (`vim.v.shell_error`)
- Validate inputs before processing (file handles, buffer existence)

### Naming Conventions
- Functions: snake_case (`send_current_buffer`)
- Config keys: snake_case (`auto_detect_socket`)
- Commands: PascalCase with plugin prefix (`OpencodeSendBuffer`)

### Plugin Structure
- Main logic in `lua/opencode/init.lua`
- Commands and keymaps in `plugin/opencode.lua`
- Use guard clause pattern for plugin loading