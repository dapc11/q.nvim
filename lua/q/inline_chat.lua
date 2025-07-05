local M = {}

local utils = require("q.utils")

-- Inline chat state
local inline_state = {
	active = false,
	bufnr = nil,
	winid = nil,
	original_bufnr = nil,
	original_winid = nil,
	start_line = nil,
	end_line = nil,
	selected_text = nil,
	ns_id = vim.api.nvim_create_namespace("q_inline_chat"),
}

-- Forward declarations
local expand_input_window
local process_inline_request
local setup_inline_keymaps
local create_input_window
local show_response
local apply_suggestion
local show_loading_indicator
local hide_loading_indicator

-- Setup keymaps for inline chat
setup_inline_keymaps = function()
	local opts = { buffer = inline_state.bufnr, noremap = true, silent = true }

	-- Send on Enter
	vim.keymap.set("i", "<CR>", function()
		process_inline_request()
	end, opts)

	vim.keymap.set("n", "<CR>", function()
		process_inline_request()
	end, opts)

	-- Cancel on Escape
	vim.keymap.set({ "i", "n" }, "<Esc>", function()
		M.cancel()
	end, opts)

	-- Expand window on Ctrl+E
	vim.keymap.set("i", "<C-e>", function()
		expand_input_window()
	end, opts)
end

-- Create inline chat input window
create_input_window = function()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local row = cursor_pos[1] + 1
	local col = cursor_pos[2]

	-- Adjust position to avoid going off screen
	local screen_height = vim.o.lines
	local screen_width = vim.o.columns

	if row + 5 > screen_height then
		row = cursor_pos[1] - 6
	end

	if col + 60 > screen_width then
		col = screen_width - 60
	end

	local bufnr, winid = utils.create_float_window({
		width = 60,
		height = 3,
		row = row,
		col = col,
		title = "Ask Amazon Q",
		border = "rounded",
	})

	inline_state.bufnr = bufnr
	inline_state.winid = winid

	-- Set buffer options
	vim.bo[bufnr].filetype = "markdown"

	-- Add prompt
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "What would you like me to do with this code?" })
	vim.api.nvim_win_set_cursor(winid, { 1, 0 })

	-- Enter insert mode
	vim.cmd("startinsert!")

	-- Set up keymaps
	setup_inline_keymaps()
end



-- Show response in a floating window
---@param response string Amazon Q response
show_response = function(response)
	local lines = {}
	for line in response:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	-- Calculate window size
	local width = math.min(math.max(60, #response / 3), vim.o.columns - 10)
	local height = math.min(#lines + 2, vim.o.lines - 10)

	local bufnr, winid = utils.create_float_window({
		width = width,
		height = height,
		title = "Amazon Q Response",
		border = "rounded",
	})

	-- Set content (ensure buffer is modifiable first)
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].filetype = "markdown"
	
	-- Set markdown-specific options for better display
	vim.api.nvim_set_option_value("conceallevel", 2, { win = winid })
	vim.api.nvim_set_option_value("wrap", true, { win = winid })
	vim.api.nvim_set_option_value("linebreak", true, { win = winid })

	-- Set up keymaps for response window
	local opts = { buffer = bufnr, noremap = true, silent = true }

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(winid, true)
		M.cancel()
	end, opts)

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(winid, true)
		M.cancel()
	end, opts)

	vim.keymap.set("n", "a", function()
		apply_suggestion(response)
		vim.api.nvim_win_close(winid, true)
		M.cancel()
	end, opts)

	-- Show help text (ensure buffer is still modifiable)
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
		"",
		"Press 'a' to apply, 'q' or <Esc> to close",
	})

	-- Now make buffer read-only
	vim.bo[bufnr].modifiable = false
end

-- Apply suggestion to the code
---@param suggestion string The suggestion to apply
apply_suggestion = function(suggestion)
	if not inline_state.original_bufnr or not vim.api.nvim_buf_is_valid(inline_state.original_bufnr) then
		vim.notify("Original buffer is no longer valid", vim.log.levels.ERROR)
		return
	end

	-- Switch back to original buffer
	vim.api.nvim_set_current_buf(inline_state.original_bufnr)

	if inline_state.selected_text then
		-- Replace selected text
		local start_pos = vim.api.nvim_buf_get_mark(inline_state.original_bufnr, "<")
		local end_pos = vim.api.nvim_buf_get_mark(inline_state.original_bufnr, ">")

		local suggestion_lines = {}
		for line in suggestion:gmatch("[^\r\n]+") do
			table.insert(suggestion_lines, line)
		end

		vim.api.nvim_buf_set_text(
			inline_state.original_bufnr,
			start_pos[1] - 1,
			start_pos[2],
			end_pos[1] - 1,
			end_pos[2] + 1,
			suggestion_lines
		)
	else
		-- Insert at cursor position
		local cursor_pos = vim.api.nvim_win_get_cursor(inline_state.original_winid)
		local suggestion_lines = {}
		for line in suggestion:gmatch("[^\r\n]+") do
			table.insert(suggestion_lines, line)
		end

		vim.api.nvim_buf_set_lines(inline_state.original_bufnr, cursor_pos[1], cursor_pos[1], false, suggestion_lines)
	end

	vim.notify("Applied Amazon Q suggestion", vim.log.levels.INFO)
end

-- Show loading indicator
show_loading_indicator = function()
	if not inline_state.original_bufnr or not vim.api.nvim_buf_is_valid(inline_state.original_bufnr) then
		return
	end

	local lines = { "⏳ Amazon Q is thinking..." }
	local start_line = inline_state.start_line or vim.api.nvim_win_get_cursor(inline_state.original_winid)[1]

	vim.api.nvim_buf_set_extmark(inline_state.original_bufnr, inline_state.ns_id, start_line - 1, 0, {
		virt_text = { { lines[1], "Comment" } },
		virt_text_pos = "eol",
	})
end

-- Hide loading indicator
hide_loading_indicator = function()
	if not inline_state.original_bufnr or not vim.api.nvim_buf_is_valid(inline_state.original_bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(inline_state.original_bufnr, inline_state.ns_id, 0, -1)
end

-- Expand input window for longer prompts
expand_input_window = function()
	if not inline_state.winid or not vim.api.nvim_win_is_valid(inline_state.winid) then
		return
	end

	-- Get current window config
	local config = vim.api.nvim_win_get_config(inline_state.winid)

	-- Increase height
	config.height = config.height + 3

	-- Apply new config
	vim.api.nvim_win_set_config(inline_state.winid, config)
end

-- Process inline chat request
process_inline_request = function()
	local lines = vim.api.nvim_buf_get_lines(inline_state.bufnr, 0, -1, false)
	local prompt = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

	if prompt == "" or prompt == "What would you like me to do with this code?" then
		vim.notify("Please enter a request", vim.log.levels.WARN)
		return
	end

	-- Expand % to current buffer path (use original buffer)
	prompt = utils.expand_current_buffer_path(prompt, inline_state.original_bufnr)

	-- Close input window
	if inline_state.winid and vim.api.nvim_win_is_valid(inline_state.winid) then
		vim.api.nvim_win_close(inline_state.winid, true)
	end

	-- Return to original window
	if inline_state.original_winid and vim.api.nvim_win_is_valid(inline_state.original_winid) then
		vim.api.nvim_set_current_win(inline_state.original_winid)
	end

	-- Show loading indicator
	show_loading_indicator()

	-- Prepare context and request
	local context = utils.get_buffer_context()
	local args = { "chat", "--no-interactive", "--trust-all-tools" }

	-- Build the full prompt
	local full_prompt = prompt

	if inline_state.selected_text then
		full_prompt = prompt
			.. "\n\nCode:\n```"
			.. (context.filetype or "")
			.. "\n"
			.. inline_state.selected_text
			.. "\n```"
	elseif inline_state.start_line and inline_state.end_line then
		local code_lines = vim.api.nvim_buf_get_lines(
			inline_state.original_bufnr,
			inline_state.start_line - 1,
			inline_state.end_line,
			false
		)
		local code = table.concat(code_lines, "\n")
		full_prompt = prompt .. "\n\nCode:\n```" .. (context.filetype or "") .. "\n" .. code .. "\n```"
	end

	table.insert(args, full_prompt)

	-- Execute Q command
	utils.execute_q_command(args, function(output, error)
		hide_loading_indicator()

		if error then
			vim.notify("Amazon Q error: " .. error, vim.log.levels.ERROR)
			M.cancel()
			return
		end

		if output and output ~= "" then
			-- Check if streaming is enabled
			local ok, q_module = pcall(require, "q")
			local config = ok and q_module.config or nil
			local streaming_enabled = config and config.streaming ~= false -- Default to true
			
			if streaming_enabled then
				-- Create floating window for response
				local width = math.min(math.max(60, #output / 3), vim.o.columns - 10)
				local height = math.min(10, vim.o.lines - 10) -- Start with smaller height
				
				local bufnr, winid = utils.create_float_window({
					width = width,
					height = height,
					title = "Amazon Q Response",
					border = "rounded",
				})
				
				-- Set initial content
				vim.bo[bufnr].modifiable = true
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
				vim.bo[bufnr].filetype = "markdown"
				
				-- Set markdown-specific options for better display
				vim.api.nvim_set_option_value("conceallevel", 2, { win = winid })
				vim.api.nvim_set_option_value("wrap", true, { win = winid })
				vim.api.nvim_set_option_value("linebreak", true, { win = winid })
				
				-- Set up keymaps for response window
				local opts = { buffer = bufnr, noremap = true, silent = true }
				
				vim.keymap.set("n", "q", function()
					vim.api.nvim_win_close(winid, true)
					M.cancel()
				end, opts)
				
				vim.keymap.set("n", "<Esc>", function()
					vim.api.nvim_win_close(winid, true)
					M.cancel()
				end, opts)
				
				vim.keymap.set("n", "a", function()
					apply_suggestion(output)
					vim.api.nvim_win_close(winid, true)
					M.cancel()
				end, opts)
				
				-- Split output into lines for streaming effect
				local lines = {}
				for line in output:gmatch("[^\r\n]+") do
					table.insert(lines, line)
				end
				
				local function update_content(index)
					if index > #lines then
						-- Finished streaming, add help text
						vim.bo[bufnr].modifiable = true
						vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
							"",
							"Press 'a' to apply, 'q' or <Esc> to close",
						})
						vim.bo[bufnr].modifiable = false
						return
					end
					
					-- Update buffer content
					vim.bo[bufnr].modifiable = true
					
					-- Get current lines
					local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
					table.insert(current_lines, lines[index])
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, current_lines)
					
					-- Adjust window height if needed
					if index % 3 == 0 and index < #lines then
						local config = vim.api.nvim_win_get_config(winid)
						local new_height = math.min(#current_lines + 3, vim.o.lines - 10)
						if new_height > config.height then
							config.height = new_height
							vim.api.nvim_win_set_config(winid, config)
						end
					end
					
					vim.bo[bufnr].modifiable = false
					
					-- Auto-scroll to bottom
					if vim.api.nvim_win_is_valid(winid) then
						local line_count = vim.api.nvim_buf_line_count(bufnr)
						vim.api.nvim_win_set_cursor(winid, { line_count, 0 })
					end
					
					-- Schedule next line with delay
					vim.defer_fn(function()
						update_content(index + 1)
					end, 100)
				end
				
				-- Start streaming
				update_content(1)
			else
				-- Just show the response without streaming
				show_response(output:gsub("^%s+", ""):gsub("%s+$", ""))
			end
		else
			vim.notify("No response from Amazon Q", vim.log.levels.WARN)
			M.cancel()
		end
	end)
end

-- Start inline chat
---@param opts table Options for inline chat
---@param initial_prompt? string Initial prompt to use
function M.start(opts, initial_prompt)
	opts = opts or {}
	
	if inline_state.active then
		vim.notify("Inline chat is already active", vim.log.levels.WARN)
		return
	end

	-- Store original buffer and window
	inline_state.original_bufnr = vim.api.nvim_get_current_buf()
	inline_state.original_winid = vim.api.nvim_get_current_win()

	-- Check if text is selected
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		-- Get selected text
		local selected_text = utils.get_visual_selection()
		inline_state.selected_text = selected_text

		-- Get start and end lines
		local start_pos = vim.api.nvim_buf_get_mark(0, "<")
		local end_pos = vim.api.nvim_buf_get_mark(0, ">")
		inline_state.start_line = start_pos[1]
		inline_state.end_line = end_pos[1]

		-- Exit visual mode
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
	elseif opts and opts.range and opts.range > 0 then
		-- Get start and end lines from command range
		inline_state.start_line = opts.line1
		inline_state.end_line = opts.line2

		-- Get text from range
		local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
		inline_state.selected_text = table.concat(lines, "\n")
	end

	inline_state.active = true

	create_input_window()

	if initial_prompt then
		-- Set initial prompt
		vim.api.nvim_buf_set_lines(inline_state.bufnr, 0, -1, false, { initial_prompt })
	end
end

-- Cancel inline chat
function M.cancel()
	-- Clear any loading indicators
	hide_loading_indicator()

	-- Close input window if it exists
	if inline_state.winid and vim.api.nvim_win_is_valid(inline_state.winid) then
		vim.api.nvim_win_close(inline_state.winid, true)
	end

	-- Reset state
	inline_state.active = false
	inline_state.bufnr = nil
	inline_state.winid = nil
	inline_state.selected_text = nil
	inline_state.start_line = nil
	inline_state.end_line = nil

	-- Return to original window if it exists
	if inline_state.original_winid and vim.api.nvim_win_is_valid(inline_state.original_winid) then
		vim.api.nvim_set_current_win(inline_state.original_winid)
	end
end

return M
