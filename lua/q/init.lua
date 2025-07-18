---@class q.Config
---@field enabled? boolean Enable the plugin (default: true)
---@field debug_cli? boolean Show debug information for CLI commands (default: false)
---@field streaming? boolean Enable streaming responses (default: true)
---@field chat_window? q.ChatWindowConfig Chat window configuration
---@field keymaps? q.KeymapConfig Keymap configuration
---@field ghost_text? q.GhostTextConfig Ghost text configuration

---@class q.ChatWindowConfig
---@field width? number Chat window width (default: 80)
---@field height? number Chat window height (default: 20)
---@field position? "right" | "bottom" | "float" Window position (default: "right")

---@class q.KeymapConfig
---@field inline_chat? string Keymap for inline chat (default: "<leader>qi")
---@field open_chat? string Keymap for opening chat (default: "<leader>qc")

---@class q.GhostTextConfig
---@field enabled? boolean Enable ghost text (default: true)
---@field chat_prompt? string Ghost text for chat window (default: "Ask Amazon Q: ")
---@field inline_prompt? string Ghost text for inline chat (default: "What would you like me to do with this code?")
---@field highlight? string Highlight group for ghost text (default: "Comment")

local M = {}

-- Plugin state
local state = {
	initialized = false,
	chat_buf = nil,
	chat_win = nil,
}

-- Expose state for health checks
M.state = state

---@type q.Config
local default_config = {
	enabled = true,
	debug_cli = false,
	streaming = true,
	chat_window = {
		width = 80,
		height = 20,
		position = "right",
	},
	keymaps = {
		inline_chat = "<leader>qi",
		open_chat = "<leader>qc",
	},
	ghost_text = {
		enabled = true,
		chat_prompt = "Ask Amazon Q: ",
		inline_prompt = "What would you like me to do with this code?",
		highlight = "Comment",
	},
}

---@type q.Config
M.config = vim.deepcopy(default_config)

-- Initialize the plugin with the merged configuration
local function initialize()
	if state.initialized then
		return
	end

	-- Validate configuration
	local ok, err = pcall(vim.validate, {
		enabled = { M.config.enabled, "boolean" },
		debug_cli = { M.config.debug_cli, "boolean" },
		streaming = { M.config.streaming, "boolean" },
	})

	if not ok then
		vim.notify("q.nvim: Invalid configuration - " .. err, vim.log.levels.ERROR)
		return
	end

	if not M.config.enabled then
		return
	end

	-- Check if Amazon Q CLI is available
	if vim.fn.executable("q") == 0 then
		vim.notify("q.nvim: Amazon Q CLI not found. Please install it first.", vim.log.levels.WARN)
		return
	end

	-- Setup commands
	require("q.commands").setup()

	-- Setup keymaps
	require("q.keymaps").setup(M.config.keymaps)

	state.initialized = true
end

-- Setup function that accepts user configuration
---@param user_config? q.Config User configuration table
function M.setup(user_config)
	-- For backward compatibility, also check vim.g.q_nvim
	local config_from_g = vim.g.q_nvim or {}
	user_config = user_config or {}

	-- Merge configurations with priority: user_config > vim.g.q_nvim > default_config
	M.config = vim.tbl_deep_extend("force", default_config, config_from_g, user_config)

	-- Initialize the plugin
	vim.defer_fn(initialize, 0)
end

-- For backward compatibility, initialize with vim.g.q_nvim if setup() is not called
vim.defer_fn(function()
	if not state.initialized then
		M.setup()
	end
end, 100)

return M
