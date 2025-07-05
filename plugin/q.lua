-- q.nvim - Amazon Q CLI integration for Neovim
-- Prevent loading twice
if vim.g.loaded_q_nvim then
	return
end

-- Check Neovim version
if vim.fn.has("nvim-0.9") == 0 then
	vim.notify("q.nvim requires Neovim 0.9+", vim.log.levels.ERROR)
	return
end

-- Mark as loaded
vim.g.loaded_q_nvim = true

-- Initialize the plugin
require("q")
