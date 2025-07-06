local M = {}

function M.setup(keymap_config)
	-- Create <Plug> mappings for flexibility
	vim.keymap.set("n", "<Plug>(QOpenChat)", function()
		-- Safely require the module and call the function
		local ok, chat_module = pcall(require, "q.chat")
		if ok and chat_module then
			chat_module.open()
		else
			vim.notify("Failed to load chat module: " .. (chat_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Open Amazon Q chat" })

	vim.keymap.set("n", "<Plug>(QInlineChat)", function()
		-- Safely require the module and call the function
		local ok, inline_chat_module = pcall(require, "q.inline_chat")
		if ok and inline_chat_module then
			inline_chat_module.start({})
		else
			vim.notify("Failed to load inline chat module: " .. (inline_chat_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Start inline chat with Amazon Q" })

	vim.keymap.set("v", "<Plug>(QInlineChat)", function()
		-- Safely require the module and call the function
		local ok, inline_chat_module = pcall(require, "q.inline_chat")
		if ok and inline_chat_module then
			inline_chat_module.start({})
		else
			vim.notify("Failed to load inline chat module: " .. (inline_chat_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Start inline chat with selected code" })

	vim.keymap.set("n", "<Plug>(QAcceptSuggestion)", function()
		-- Safely require the module and call the function
		local ok, suggestions_module = pcall(require, "q.suggestions")
		if ok and suggestions_module then
			suggestions_module.accept()
		else
			vim.notify("Failed to load suggestions module: " .. (suggestions_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Accept Amazon Q suggestion" })

	vim.keymap.set("i", "<Plug>(QAcceptSuggestion)", function()
		-- Safely require the module and call the function
		local ok, suggestions_module = pcall(require, "q.suggestions")
		if ok and suggestions_module then
			suggestions_module.accept()
		else
			vim.notify("Failed to load suggestions module: " .. (suggestions_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Accept Amazon Q suggestion" })

	vim.keymap.set("n", "<Plug>(QDismissSuggestion)", function()
		-- Safely require the module and call the function
		local ok, suggestions_module = pcall(require, "q.suggestions")
		if ok and suggestions_module then
			suggestions_module.dismiss()
		else
			vim.notify("Failed to load suggestions module: " .. (suggestions_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Dismiss Amazon Q suggestion" })

	vim.keymap.set("i", "<Plug>(QDismissSuggestion)", function()
		-- Safely require the module and call the function
		local ok, suggestions_module = pcall(require, "q.suggestions")
		if ok and suggestions_module then
			suggestions_module.dismiss()
		else
			vim.notify("Failed to load suggestions module: " .. (suggestions_module or "unknown error"), vim.log.levels.ERROR)
		end
	end, { noremap = true, desc = "Dismiss Amazon Q suggestion" })

	vim.keymap.set("n", "<Plug>(QToggleSuggestions)", function()
		-- Safely require the module and call the function
		local ok, suggestions_module = pcall(require, "q.suggestions")
		if ok and suggestions_module then
			suggestions_module.toggle()
		else
			vim.notify("Failed to load suggestions module: " .. (suggestions_module or "unknown error"), vim.log.levels.ERROR)
		end
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
