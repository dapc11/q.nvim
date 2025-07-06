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

	-- Set up default keymaps if provided
	if keymap_config.open_chat then
		vim.keymap.set("n", keymap_config.open_chat, "<Plug>(QOpenChat)")
	end

	if keymap_config.inline_chat then
		vim.keymap.set("n", keymap_config.inline_chat, "<Plug>(QInlineChat)")
		vim.keymap.set("v", keymap_config.inline_chat, "<Plug>(QInlineChat)")
	end
end

return M
