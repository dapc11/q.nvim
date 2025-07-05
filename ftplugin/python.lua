-- Python-specific Amazon Q integration
if vim.g.loaded_q_python then
	return
end
vim.g.loaded_q_python = true

local bufnr = vim.api.nvim_get_current_buf()

-- Python-specific keymaps
vim.keymap.set("n", "<Plug>(QPythonExplain)", function()
	require("q.inline_chat").start("Explain this Python code")
end, { noremap = true, buffer = bufnr, desc = "Explain Python code with Amazon Q" })

vim.keymap.set("n", "<Plug>(QPythonOptimize)", function()
	require("q.inline_chat").start("Optimize this Python code for performance")
end, { noremap = true, buffer = bufnr, desc = "Optimize Python code with Amazon Q" })

vim.keymap.set("n", "<Plug>(QPythonTest)", function()
	require("q.inline_chat").start("Write unit tests for this Python function using pytest")
end, { noremap = true, buffer = bufnr, desc = "Generate Python tests with Amazon Q" })

vim.keymap.set("n", "<Plug>(QPythonDoc)", function()
	require("q.inline_chat").start("Add Python docstrings to this code following Google style")
end, { noremap = true, buffer = bufnr, desc = "Add Python documentation with Amazon Q" })

vim.keymap.set("n", "<Plug>(QPythonType)", function()
	require("q.inline_chat").start("Add type hints to this Python code")
end, { noremap = true, buffer = bufnr, desc = "Add Python type hints with Amazon Q" })

vim.keymap.set("n", "<Plug>(QPythonAsync)", function()
	require("q.inline_chat").start("Convert this Python code to use async/await")
end, { noremap = true, buffer = bufnr, desc = "Convert to async Python with Amazon Q" })

-- Python-specific commands
vim.api.nvim_buf_create_user_command(bufnr, "QPythonGenerate", function(opts)
	local what = opts.args or "class"
	require("q.inline_chat").start("Generate a Python " .. what .. " based on this context")
end, {
	nargs = "?",
	desc = "Generate Python code with Amazon Q",
	complete = function()
		return {
			"class",
			"function",
			"method",
			"decorator",
			"context manager",
			"dataclass",
			"enum",
			"exception",
			"test",
		}
	end,
})

vim.api.nvim_buf_create_user_command(bufnr, "QPythonRefactor", function(opts)
	local action = opts.args or "improve"
	require("q.inline_chat").start("Refactor this Python code to " .. action)
end, {
	nargs = "?",
	desc = "Refactor Python code with Amazon Q",
	complete = function()
		return {
			"improve readability",
			"follow PEP 8",
			"use list comprehensions",
			"optimize performance",
			"add error handling",
			"extract function",
			"extract class",
			"use dataclasses",
			"make it more pythonic",
		}
	end,
})

vim.api.nvim_buf_create_user_command(bufnr, "QPythonLint", function()
	require("q.inline_chat").start("Fix Python linting issues and improve code quality")
end, {
	desc = "Fix Python linting with Amazon Q",
})
