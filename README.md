# q.nvim

A Neovim plugin that integrates Amazon Q CLI for seamless AI-powered coding assistance directly in your editor.

## Features

- **Inline Chat**: Start conversations with Amazon Q directly in your code editor
- **Chat Window**: Dedicated chat interface for extended conversations
- **Streaming Responses**: Real-time line-by-line streaming of Amazon Q responses for faster feedback
- **Language Support**: Optimized for Go, Python, and many other languages
- **Filetype-specific Commands**: Specialized commands for different programming languages

## Requirements

- Neovim 0.9+
- [Amazon Q CLI](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-getting-started-installing.html)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "dapc11/q.nvim",
    config = function()
        require("q").setup({
            enabled = true,
            debug_cli = false,
            chat_window = {
                width = 80,
                height = 20,
                position = "right", -- "right", "bottom", "float"
            },
            keymaps = {
                inline_chat = "<leader>qi",
                open_chat = "<leader>qc",
            },
        })
    end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "dapc11/q.nvim",
    config = function()
        require("q").setup({
            -- your configuration here
        })
    end
}
```

## Configuration

The plugin works out of the box with sensible defaults. You can customize it using the setup function:

```lua
require("q").setup({
    enabled = true,                    -- Enable/disable the plugin
    debug_cli = false,                 -- Show debug info for CLI commands (for troubleshooting)
    streaming = true,                  -- Enable streaming responses (default: true)
    chat_window = {
        width = 80,                    -- Chat window width
        height = 20,                   -- Chat window height
        position = "right",            -- "right", "bottom", "float"
    },
    keymaps = {
        inline_chat = "<leader>qi",    -- Start inline chat
        open_chat = "<leader>qc",      -- Open chat window
    },
    ghost_text = {
        enabled = true,                -- Enable ghost text prompts (default: true)
        chat_prompt = "Ask Amazon Q: ", -- Ghost text for chat window
        inline_prompt = "What would you like me to do with this code?", -- Ghost text for inline chat
        highlight = "Comment",         -- Highlight group for ghost text (default: "Comment")
    },
}
```

## Usage

### Environment Variables

Configure your Amazon Q login defaults using environment variables. Add these to your shell configuration file (e.g., `~/.zshrc`, `~/.bashrc`):

```bash
# Amazon Q CLI Configuration
export Q_NVIM_LICENSE="pro"
export Q_NVIM_IDENTITY_PROVIDER="awsprovider"
export Q_NVIM_REGION="region"
```

These environment variables will be used as defaults for the `:Q login` command. You can still override them by passing explicit arguments.

### Authentication

Before using Amazon Q features, you need to authenticate:

```vim
" Quick login using environment variable defaults
:Q login

" Or use the convenience command
:Q login-default

" Login with Builder ID (free) instead (overrides Q_NVIM_LICENSE)
:Q login --license=free

" Override specific settings
:Q login --region=us-east-1

" Use device flow for authentication (useful for remote/headless environments)
:Q login --use-device-flow

" Check authentication status
:Q status

" Logout (if supported)
:Q logout
```

**Environment Variable Defaults:**
- `Q_NVIM_LICENSE`: License type (default: "pro")
- `Q_NVIM_IDENTITY_PROVIDER`: Identity provider URL
- `Q_NVIM_REGION`: AWS region (default: "eu-west-1")

### Commands

- `:Q login [options]` - Login to Amazon Q (uses organization defaults)
- `:Q login-default` - Quick login with organization defaults
- `:Q logout` - Logout from Amazon Q  
- `:Q status` - Check authentication status
- `:Q chat [message]` - Open chat window or send a message
- `:Q reopen` - Reopen chat window with previous conversation history
- `:Q inline [prompt]` - Start inline chat

### Special Syntax

- Use `%` in any command or chat to reference the current file's absolute path
  ```vim
  " Example: Ask about the current file
  :Q chat explain the code in %
  
  " Example: Ask about a specific function in the current file
  :Q inline refactor the function in % to be more efficient
  ```
  
  **Note**: When using `%` in the chat window, it will refer to the file you were editing before opening the chat, not the chat buffer itself.

### Keymaps

The plugin provides `<Plug>` mappings for flexibility:

```lua
-- Basic mappings
vim.keymap.set("n", "<leader>qc", "<Plug>(QOpenChat)")
vim.keymap.set("n", "<leader>qi", "<Plug>(QInlineChat)")
vim.keymap.set("v", "<leader>qi", "<Plug>(QInlineChat)")
```

### Language-specific Features

#### Go

```lua
-- Available <Plug> mappings for Go files
"<Plug>(QGoExplain)"     -- Explain Go code
"<Plug>(QGoOptimize)"    -- Optimize Go code
"<Plug>(QGoTest)"        -- Generate tests
"<Plug>(QGoDoc)"         -- Add documentation
"<Plug>(QGoError)"       -- Add error handling

-- Commands
:QGoGenerate [struct|interface|method|function|test]
:QGoRefactor [action]
```

#### Python

```lua
-- Available <Plug> mappings for Python files
"<Plug>(QPythonExplain)"  -- Explain Python code
"<Plug>(QPythonOptimize)" -- Optimize Python code
"<Plug>(QPythonTest)"     -- Generate tests
"<Plug>(QPythonDoc)"      -- Add docstrings
"<Plug>(QPythonType)"     -- Add type hints
"<Plug>(QPythonAsync)"    -- Convert to async

-- Commands
:QPythonGenerate [class|function|decorator|etc]
:QPythonRefactor [action]
:QPythonLint
```

## Workflow Examples

### Inline Chat

1. Select code in visual mode
2. Press `<leader>qi` (or your configured keymap)
3. Type your request (e.g., "optimize this function")
4. Press Enter
5. Review the response and press 'a' to apply or 'q' to dismiss

### Chat Window

1. Press `<leader>qc` to open the chat window
2. Type your questions in the input area
3. Press Enter to send
4. Continue the conversation

## Health Check

Run `:checkhealth q` to verify your setup:

- Amazon Q CLI installation
- Plugin configuration
- Neovim version compatibility
- Current filetype support

## Troubleshooting

### Amazon Q CLI not found

Make sure the Amazon Q CLI is installed and available in your PATH:

```bash
# Install Amazon Q CLI
# Follow instructions at: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-getting-started-installing.html

# Verify installation
q --version
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Amazon Q team for the CLI tool
- Neovim community for the excellent plugin ecosystem
- Contributors and users of this plugin
