local M = {}

local chat = require("q.chat")
local inline_chat = require("q.inline_chat")
local suggestions = require("q.suggestions")

function M.setup(keymap_config)
	-- Create <Plug> mappings for flexibility
	vim.keymap.set("n", "<Plug>(QOpenChat)", function()
		chat.open()
	end, { noremap = true, desc = "Open Amazon Q chat" })

	vim.keymap.set("n", "<Plug>(QInlineChat)", function()
		inline_chat.start({})
	end, { noremap = true, desc = "Start inline chat with Amazon Q" })

	vim.keymap.set("v", "<Plug>(QInlineChat)", function()
		inline_chat.start({})
	end, { noremap = true, desc = "Start inline chat with selected code" })

	vim.keymap.set("n", "<Plug>(QAcceptSuggestion)", function()
		suggestions.accept()
	end, { noremap = true, desc = "Accept Amazon Q suggestion" })

	vim.keymap.set("i", "<Plug>(QAcceptSuggestion)", function()
		suggestions.accept()
	end, { noremap = true, desc = "Accept Amazon Q suggestion" })

	vim.keymap.set("n", "<Plug>(QDismissSuggestion)", function()
		suggestions.dismiss()
	end, { noremap = true, desc = "Dismiss Amazon Q suggestion" })

	vim.keymap.set("i", "<Plug>(QDismissSuggestion)", function()
		suggestions.dismiss()
	end, { noremap = true, desc = "Dismiss Amazon Q suggestion" })

	vim.keymap.set("n", "<Plug>(QToggleSuggestions)", function()
		suggestions.toggle()
	end, { noremap = true, desc = "Toggle Amazon Q suggestions" })

	-- Set up default keymaps if provided
	if keymap_config.open_chat then
		vim.keymap.set("n", keymap_config.open_chat, "<Plug>(QOpenChat)")
	end

	if keymap_config.inline_chat then
		vim.keymap.set("n", keymap_config.inline_chat, "<Plug>(QInlineChat)")
		vim.keymap.set("v", keymap_config.inline_chat, "<Plug>(QInlineChat)")
	end

	if keymap_config.accept_suggestion then
		vim.keymap.set("n", keymap_config.accept_suggestion, "<Plug>(QAcceptSuggestion)")
		vim.keymap.set("i", keymap_config.accept_suggestion, "<Plug>(QAcceptSuggestion)")
	end

	if keymap_config.dismiss_suggestion then
		vim.keymap.set("n", keymap_config.dismiss_suggestion, "<Plug>(QDismissSuggestion)")
		vim.keymap.set("i", keymap_config.dismiss_suggestion, "<Plug>(QDismissSuggestion)")
	end
end

return M
