-- Ghost text utility module for q.nvim
local M = {}

-- Create a ghost text manager for a buffer
---@param bufnr number Buffer number
---@param namespace_name string Namespace name for the ghost text
---@param prompt string Ghost text prompt
---@param highlight? string Highlight group (default: "Comment")
---@return table Ghost text manager
function M.create_manager(bufnr, namespace_name, prompt, highlight)
	highlight = highlight or "Comment"
	local ns_id = vim.api.nvim_create_namespace(namespace_name)

	local manager = {
		bufnr = bufnr,
		ns_id = ns_id,
		prompt = prompt,
		highlight = highlight,
		enabled = true,
	}

	-- Update ghost text visibility based on buffer content
	function manager:update()
		if not self.enabled then
			return
		end

		-- Check if buffer is still valid
		if not vim.api.nvim_buf_is_valid(self.bufnr) then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
		local content = table.concat(lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")

		-- Clear existing ghost text
		vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)

		-- Show ghost text only if buffer is empty or contains only whitespace
		if content == "" then
			-- Only show ghost text on the first line if it's empty
			local first_line = lines[1] or ""
			if first_line:gsub("^%s*", ""):gsub("%s*$", "") == "" then
				vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, 0, {
					virt_text = { { self.prompt, self.highlight } },
					virt_text_pos = "inline",
				})
			end
		end
	end

	-- Enable ghost text
	function manager:enable()
		self.enabled = true
		self:update()
	end

	-- Disable ghost text
	function manager:disable()
		self.enabled = false
		vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)
	end

	-- Change the prompt text
	function manager:set_prompt(new_prompt)
		self.prompt = new_prompt
		self:update()
	end

	-- Change the highlight group
	function manager:set_highlight(new_highlight)
		self.highlight = new_highlight
		self:update()
	end

	-- Clean up the ghost text manager
	function manager:cleanup()
		vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)
	end

	-- Set up autocommands for automatic ghost text management
	function manager:setup_autocommands()
		if not self.enabled then
			return
		end

		local augroup_name = "QGhostText_" .. namespace_name
		local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

		-- Update ghost text on text changes
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			buffer = self.bufnr,
			group = augroup,
			callback = function()
				self:update()
			end,
			desc = "Update ghost text visibility in " .. namespace_name,
		})

		-- Update ghost text when entering insert mode
		vim.api.nvim_create_autocmd("InsertEnter", {
			buffer = self.bufnr,
			group = augroup,
			callback = function()
				self:update()
			end,
			desc = "Update ghost text when entering insert mode",
		})

		-- Update ghost text when leaving insert mode
		vim.api.nvim_create_autocmd("InsertLeave", {
			buffer = self.bufnr,
			group = augroup,
			callback = function()
				self:update()
			end,
			desc = "Update ghost text when leaving insert mode",
		})

		-- Clean up when buffer is deleted
		vim.api.nvim_create_autocmd("BufDelete", {
			buffer = self.bufnr,
			group = augroup,
			callback = function()
				self:cleanup()
			end,
			desc = "Clean up ghost text when buffer is deleted",
		})
	end

	return manager
end

-- Get ghost text configuration from the main plugin config
---@return table Ghost text configuration
function M.get_config()
	local ok, q_module = pcall(require, "q")
	return ok and q_module.config and q_module.config.ghost_text
		or {
			enabled = true,
			chat_prompt = "Ask Amazon Q: ",
			inline_prompt = "What would you like me to do with this code?",
			highlight = "Comment",
		}
end

return M
