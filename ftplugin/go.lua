-- Go-specific Amazon Q integration
if vim.g.loaded_q_go then
	return
end
vim.g.loaded_q_go = true

local bufnr = vim.api.nvim_get_current_buf()

-- Go-specific keymaps
vim.keymap.set("n", "<Plug>(QGoExplain)", function()
	require("q.inline_chat").start("Explain this Go code")
end, { noremap = true, buffer = bufnr, desc = "Explain Go code with Amazon Q" })

vim.keymap.set("n", "<Plug>(QGoOptimize)", function()
	require("q.inline_chat").start("Optimize this Go code for performance")
end, { noremap = true, buffer = bufnr, desc = "Optimize Go code with Amazon Q" })

vim.keymap.set("n", "<Plug>(QGoTest)", function()
	require("q.inline_chat").start("Write unit tests for this Go function")
end, { noremap = true, buffer = bufnr, desc = "Generate Go tests with Amazon Q" })

vim.keymap.set("n", "<Plug>(QGoDoc)", function()
	require("q.inline_chat").start("Add Go documentation comments to this code")
end, { noremap = true, buffer = bufnr, desc = "Add Go documentation with Amazon Q" })

vim.keymap.set("n", "<Plug>(QGoError)", function()
	require("q.inline_chat").start("Add proper error handling to this Go code")
end, { noremap = true, buffer = bufnr, desc = "Add Go error handling with Amazon Q" })

-- Go-specific commands
vim.api.nvim_buf_create_user_command(bufnr, "QGoGenerate", function(opts)
	local what = opts.args or "struct"
	require("q.inline_chat").start("Generate a Go " .. what .. " based on this context")
end, {
	nargs = "?",
	desc = "Generate Go code with Amazon Q",
	complete = function()
		return {
			"struct",
			"interface",
			"method",
			"function",
			"test",
			"benchmark",
			"example",
		}
	end,
})

vim.api.nvim_buf_create_user_command(bufnr, "QGoRefactor", function(opts)
	local action = opts.args or "improve"
	require("q.inline_chat").start("Refactor this Go code to " .. action)
end, {
	nargs = "?",
	desc = "Refactor Go code with Amazon Q",
	complete = function()
		return {
			"improve readability",
			"reduce complexity",
			"follow Go idioms",
			"optimize performance",
			"add error handling",
			"extract function",
			"extract interface",
		}
	end,
})
