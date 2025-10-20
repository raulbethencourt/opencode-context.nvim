# opencode-context.nvim

A Neovim plugin that enables seamless context sharing with running opencode sessions inside Tmux. Send your current buffer, all open buffers, visual selections, or diagnostics directly to opencode running in a Tmux pane for AI-assisted development.

## Features

- 💬 Interactive prompt input for opencode
- 🔄 Smart placeholder replacement system
- 📄 `@file` - Insert current file path (relative)
- 📁 `@buffers` - Insert all buffer file paths (relative)
- 📍 `@cursor`, `@here` - Insert cursor position info
- ✂️ `@selection`, `@range` - Insert visual selection
- 🔍 `@diagnostics` - Insert LSP diagnostics
- 🖥️ **Tmux integration** - Send directly to opencode pane in current window
- ⚡ LazyVim compatible with lazy loading

## Requirements

- Neovim >= 0.8.0
- `tmux` - Required for sending messages to running opencode sessions
- `opencode` running in a pane within the same tmux window as Neovim

## Installation

### lazy.nvim (LazyVim)

```lua
{
  "cousine/opencode-context.nvim",
  opts = {
    tmux_target = nil,  -- Manual override: "session:window.pane"
    auto_detect_pane = true,  -- Auto-detect opencode pane in current window
  },
  keys = {
    { "<leader>oc", "<cmd>OpencodeSend<cr>", desc = "Send prompt to opencode" },
    { "<leader>oc", "<cmd>OpencodeSend<cr>", mode = "v", desc = "Send prompt to opencode" },
    { "<leader>ot", "<cmd>OpencodeSwitchMode<cr>", desc = "Toggle opencode mode" },
    { "<leader>op", "<cmd>OpencodePrompt<cr>", desc = "Open opencode persistent prompt" },
  },
  cmd = { "OpencodeSend", "OpencodeSwitchMode" },
}
```

### packer.nvim

```lua
use {
  'cousine/opencode-context.nvim',
  config = function()
    require('opencode-context').setup({
      tmux_target = nil,
      auto_detect_pane = true,
    })
  end
}
```

### vim-plug

```vim
Plug 'cousine/opencode-context.nvim'

" Configuration in init.vim or init.lua
lua << EOF
require('opencode-context').setup({
  tmux_target = nil,
  auto_detect_pane = true,
})

-- Keymaps
vim.keymap.set("n", "<leader>oc", "<cmd>OpencodeSend<cr>", { desc = "Send prompt to opencode" })
vim.keymap.set("v", "<leader>oc", "<cmd>OpencodeSend<cr>", { desc = "Send prompt to opencode" })
vim.keymap.set("n", "<leader>ot", "<cmd>OpencodeSwitchMode<cr>", { desc = "Toggle opencode mode" })
vim.keymap.set("n", "<leader>op", "<cmd>OpencodePrompt<cr>", { desc = "Open opencode persistent prompt" })
EOF
```

### lazy.nvim with UI Configuration

For advanced UI customization with lazy.nvim:

```lua
{
  "cousine/opencode-context.nvim",
  opts = {
    -- Tmux settings
    tmux_target = nil,
    auto_detect_pane = true,

    -- UI settings (place ui inside opts, not at top level)
    ui = {
      window_type = "float",  -- "float" or "split"
      float = {
        width = 0.6,          -- 60% of editor width
        height = 1,           -- 1 line height
        border = "rounded",   -- Rounded border style
        position = "center",  -- Center the window
        margin = 2,           -- 2 line margin
      },
      split = {
        position = "bottom",  -- "top", "bottom", "left", "right"
        size = 8,             -- Split size
      },
    },
  },
  keys = {
    { "<leader>oc", "<cmd>OpencodeSend<cr>", mode = { "v", "n" }, desc = "Send prompt to opencode" },
    { "<leader>ot", "<cmd>OpencodeSwitchMode<cr>", desc = "Toggle opencode mode" },
    { "<leader>op", "<cmd>OpencodePrompt<cr>", desc = "Open opencode persistent prompt" },
  },
  cmd = { "OpencodeSend", "OpencodeSwitchMode", "OpencodePrompt" },
}
```

**Important**: The `ui` configuration must be placed inside the `opts` table, not at the top level of the lazy config.

### dein.vim

```vim
call dein#add('cousine/opencode-context.nvim')

" Configuration
lua << EOF
require('opencode-context').setup({
  tmux_target = nil,
  auto_detect_pane = true,
  ui = {
    window_type = "float",
    float = {
      width = 0.9,
      height = 1,
      border = "solid",
      position = "bottom",
      margin = 2,
    },
  },
})
EOF
```

### Manual Installation

1. Clone the repository to your Neovim configuration directory:

    ```bash
    git clone https://github.com/cousine/opencode-context.nvim ~/.config/nvim/pack/plugins/start/opencode-context.nvim
    ```

2. Add to your `init.lua`:

    ```lua
    require("opencode-context").setup({
      tmux_target = nil,
      auto_detect_pane = true,
      ui = {
        window_type = "float",
        float = {
          width = 0.9,
          height = 1,
          border = "solid",
          position = "bottom",
          margin = 2,
        },
      },
    })
    ```

## Usage

### Commands

- `:OpencodeSend` - Open prompt input for opencode with placeholder support
- `:OpencodeSwitchMode` - Toggle opencode between planning and build mode
- `:OpencodePrompt` - Open opencode persistent prompt

### Default Keymaps

- `<leader>oc` - Open prompt input (works in normal and visual mode)
- `<leader>om` - Toggle opencode mode (planning ↔ build)

### Placeholders

Use these placeholders in your prompts to include context:

- `@file` - Includes the current file path (relative to working directory)
- `@buffers` - Includes all buffer file paths (relative to working directory)
- `@cursor` - Includes cursor position (file, line, column)
- `@here` - Alias to @cursor
- `@selection` - Includes the current visual selection content
- `@range` - Includes the current visual selection range
- `@diagnostics` - Includes LSP diagnostics for current line

### Example Prompts

- `"Fix this error: @diagnostics"`
- `"Explain this code: @selection"` (select text first, then `<leader>oc`)
- `"What does @file do?"`
- `"Add tests for @file"`
- `"Review these buffers: @buffers"`
- `"How do these files work together: @buffers"`
- `"Help me at @cursor in @file"`

### Workflow Example

1. In tmux, split your window: `Ctrl-b %` or `Ctrl-b "`
2. Start opencode in one pane: `opencode`
3. Open Neovim in the other pane: `nvim`
4. From Neovim, press `<leader>oc` to open the prompt input
5. Enter your prompt with placeholders: `"Fix this error: @diagnostics"`
6. **See your prompt and response directly in the opencode pane!**

## Configuration

```lua
require("opencode-context").setup({
  -- Tmux settings
  tmux_target = nil,  -- Manual override: "main:1.0"
  auto_detect_pane = true,  -- Auto-find opencode pane in current window (default: true)

  -- UI settings
  ui = {
    window_type = "float",  -- "float" or "split"
    float = {
      width = 0.9,          -- Percentage of editor width (0.0-1.0)
      height = 1,           -- Number of lines (optional, default: 1)
      border = "solid",     -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
      position = "bottom",  -- "top", "bottom", "center"
      margin = 2,           -- Margin from edges (optional, default: 2)
    },
    split = {
      position = "bottom",  -- "top", "bottom", "left", "right"
      size = 8,             -- Number of lines/columns for split (optional, default: 8)
    },
  },
})
```

### UI Configuration Options

The `ui` configuration allows you to customize the appearance and behavior of the prompt window:

- **`window_type`**: Choose between `"float"` (floating window) or `"split"` (split window)
- **Float window options**:
  - `width`: Percentage of editor width (0.0-1.0)
  - `height`: Number of lines (default: 1)
  - `border`: Border style (`"none"`, `"single"`, `"double"`, `"rounded"`, `"solid"`, `"shadow"`)
  - `position`: Window position (`"top"`, `"bottom"`, `"center"`)
  - `margin`: Margin from screen edges (default: 2)
- **Split window options**:
  - `position`: Split position (`"top"`, `"bottom"`, `"left"`, `"right"`)
  - `size`: Number of lines/columns (default: 8)

All UI options are optional and will use sensible defaults if not specified.

## How It Works

The plugin integrates directly with tmux to send messages to your running opencode session:

1. **Auto-detects** running opencode pane in the current tmux window
2. **Sends keystrokes directly** to the opencode pane using `tmux send-keys`
3. **You see the conversation** in real-time in your opencode interface
4. **No new processes** - uses your existing opencode session

### Detection Strategy

The plugin searches for opencode panes **only in the current tmux window** using:

- Current command is `opencode`
- Pane title contains "opencode"
- Recent command history contains opencode

This ensures it finds the opencode instance you're actively working with, not some other session.

## Troubleshooting

### "No opencode pane found in current window"

- **Same window**: Ensure opencode is running in a pane in the **same tmux window** as Neovim
- **Split window**: Use `Ctrl-b %` or `Ctrl-b "` to split and run opencode in one pane
- **Manual target**: Set `tmux_target = "session:window.pane"` in config to override detection
- **Verify opencode is running**: Check that opencode is actually running in the current window

### "Failed to send to opencode pane"

- **Permissions**: Check tmux pane permissions
- **Target exists**: Verify the tmux target pane exists
- **Tmux session**: Ensure you're in the same tmux session or specify full target

### Debug Tips

```bash
# Check if opencode pane is detected in current window
tmux list-panes -F '#{session_name}:#{window_index}.#{pane_index}' -f '#{==:#{pane_current_command},opencode}'

# Test manual tmux send
tmux send-keys -t session:window.pane "test message" Enter

# List all panes in current window
tmux list-panes -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}'
```

## Documentation

Once installed, you can access the full documentation with: >
    :help opencode-context
<

## Contributing

Feel free to submit issues and pull requests to improve the plugin.

## License

MIT License
