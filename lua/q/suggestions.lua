local M = {}

local utils = require("q.utils")

-- Suggestions state
local suggestions_state = {
	enabled = true,
	current_suggestion = nil,
	suggestion_bufnr = nil,
	suggestion_winid = nil,
	ns_id = vim.api.nvim_create_namespace("q_suggestions"),
	timer = nil,
	last_request_time = 0,
	debounced_request = nil,
}

-- Forward declarations
local request_suggestion
local parse_and_show_suggestion
local show_virtual_suggestion

-- Parse Q output and show suggestion
---@param output string Q command output
---@param position table Cursor position when request was made
parse_and_show_suggestion = function(output, position)
	-- Clean up the output
	local suggestion = output:gsub("^%s+", ""):gsub("%s+$", "")

	-- Extract code from markdown if present
	local code_match = suggestion:match("```[%w]*\n(.-)\n```")
	if code_match then
		suggestion = code_match
	end

	-- Skip if suggestion is empty or too short
	if not suggestion or #suggestion < 3 then
		return
	end

	-- Check if we're still at the same position
	local current_pos = vim.api.nvim_win_get_cursor(0)
	if current_pos[1] ~= position.line or current_pos[2] ~= position.col then
		return
	end

	-- Check if we're still in insert mode
	if vim.fn.mode() ~= "i" then
		return
	end

	-- Split suggestion into lines
	local suggestion_lines = {}
	for line in suggestion:gmatch("[^\r\n]+") do
		table.insert(suggestion_lines, line)
	end

	if #suggestion_lines == 0 then
		return
	end

	-- Store suggestion
	suggestions_state.current_suggestion = {
		text = suggestion,
		lines = suggestion_lines,
		position = position,
	}

	-- Show suggestion as virtual text
	show_virtual_suggestion(suggestion_lines, position)
end

-- Show suggestion as virtual text
---@param lines table Suggestion lines
---@param position table Position to show suggestion
show_virtual_suggestion = function(lines, position)
	local bufnr = position.bufnr

	-- Clear any existing suggestions
	vim.api.nvim_buf_clear_namespace(bufnr, suggestions_state.ns_id, 0, -1)

	-- Show first line as inline virtual text
	if lines[1] then
		vim.api.nvim_buf_set_extmark(bufnr, suggestions_state.ns_id, position.line - 1, position.col, {
			virt_text = { { lines[1], "Comment" } },
			virt_text_pos = "inline",
			id = 1,
		})
	end

	-- Show additional lines as virtual lines
	if #lines > 1 then
		local virt_lines = {}
		for i = 2, #lines do
			table.insert(virt_lines, { { lines[i], "Comment" } })
		end

		vim.api.nvim_buf_set_extmark(bufnr, suggestions_state.ns_id, position.line - 1, 0, {
			virt_lines = virt_lines,
			virt_lines_above = false,
			id = 2,
		})
	end

	-- Show accept/dismiss hint
	vim.api.nvim_buf_set_extmark(bufnr, suggestions_state.ns_id, position.line - 1, 0, {
		virt_text = { { " (Tab to accept, Esc to dismiss)", "NonText" } },
		virt_text_pos = "eol",
		id = 3,
	})
end

-- Request suggestion from Amazon Q
request_suggestion = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local context = utils.get_buffer_context()

	-- Only suggest for supported filetypes
	if not utils.is_supported_filetype(context.filetype) then
		return
	end

	-- Don't suggest if we're not in insert mode
	if vim.fn.mode() ~= "i" then
		return
	end

	-- Get current line and cursor position
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor_pos[1]
	local col_num = cursor_pos[2]
	local current_line = vim.api.nvim_get_current_line()

	-- Don't suggest on empty lines or if cursor is at the beginning
	if current_line:match("^%s*$") or col_num == 0 then
		return
	end

	-- Get context around cursor
	local context_lines = {}
	local start_line = math.max(1, line_num - 10)
	local end_line = math.min(vim.api.nvim_buf_line_count(bufnr), line_num + 5)

	for i = start_line, end_line do
		local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
		table.insert(context_lines, line)
	end

	local context_text = table.concat(context_lines, "\n")

	-- Prepare Q command for code completion
	local args = { "chat", "--no-interactive", "--trust-all-tools" }

	-- Add the completion request
	local prompt = string.format(
		"Complete the following %s code. Only return the completion, no explanations:\n\n%s",
		context.filetype,
		context_text
	)

	table.insert(args, prompt)

	-- Track request time to avoid duplicate requests
	local request_time = vim.loop.hrtime()
	suggestions_state.last_request_time = request_time

	-- Execute Q command asynchronously
	utils.execute_q_command(args, function(output, error)
		-- Ignore if this is not the latest request
		if request_time ~= suggestions_state.last_request_time then
			return
		end

		if error or not output then
			return
		end

		-- Parse and show suggestion
		parse_and_show_suggestion(output, {
			line = line_num,
			col = col_num,
			bufnr = bufnr,
		})
	end)
end

-- Initialize suggestions system
function M.setup(config)
	suggestions_state.enabled = config.auto_suggestions

	if not suggestions_state.enabled then
		return
	end

	-- Create debounced request function
	suggestions_state.debounced_request = utils.debounce(request_suggestion, config.suggestion_delay)

	-- Set up autocommands
	local group = vim.api.nvim_create_augroup("QSuggestions", { clear = true })

	-- Trigger suggestions on text change in insert mode
	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
		group = group,
		callback = function()
			if suggestions_state.enabled and suggestions_state.debounced_request then
				suggestions_state.debounced_request()
			end
		end,
	})

	-- Clear suggestions when leaving insert mode
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			M.dismiss()
		end,
	})

	-- Clear suggestions when changing buffers
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function()
			M.dismiss()
		end,
	})

	-- Handle cursor movement
	vim.api.nvim_create_autocmd("CursorMovedI", {
		group = group,
		callback = function()
			if suggestions_state.current_suggestion then
				-- Check if cursor is still at the suggestion position
				local cursor_pos = vim.api.nvim_win_get_cursor(0)
				local suggestion_pos = suggestions_state.current_suggestion.position

				if cursor_pos[1] ~= suggestion_pos.line or cursor_pos[2] ~= suggestion_pos.col then
					M.dismiss()
				end
			end
		end,
	})
end

-- Accept current suggestion
function M.accept()
	if not suggestions_state.current_suggestion then
		return false
	end

	local suggestion = suggestions_state.current_suggestion
	local bufnr = vim.api.nvim_get_current_buf()

	-- Check if we're still at the right position
	local current_pos = vim.api.nvim_win_get_cursor(0)
	if current_pos[1] ~= suggestion.position.line or current_pos[2] ~= suggestion.position.col then
		M.dismiss()
		return false
	end

	-- Insert the suggestion
	local cursor_line = current_pos[1]
	local cursor_col = current_pos[2]

	if #suggestion.lines == 1 then
		-- Single line suggestion - insert at cursor
		local current_line = vim.api.nvim_get_current_line()
		local new_line = current_line:sub(1, cursor_col) .. suggestion.lines[1] .. current_line:sub(cursor_col + 1)
		vim.api.nvim_buf_set_lines(bufnr, cursor_line - 1, cursor_line, false, { new_line })

		-- Move cursor to end of inserted text
		vim.api.nvim_win_set_cursor(0, { cursor_line, cursor_col + #suggestion.lines[1] })
	else
		-- Multi-line suggestion
		local current_line = vim.api.nvim_get_current_line()
		local before_cursor = current_line:sub(1, cursor_col)
		local after_cursor = current_line:sub(cursor_col + 1)

		-- Prepare new lines
		local new_lines = { before_cursor .. suggestion.lines[1] }
		for i = 2, #suggestion.lines - 1 do
			table.insert(new_lines, suggestion.lines[i])
		end
		table.insert(new_lines, suggestion.lines[#suggestion.lines] .. after_cursor)

		-- Replace current line with new lines
		vim.api.nvim_buf_set_lines(bufnr, cursor_line - 1, cursor_line, false, new_lines)

		-- Move cursor to end of inserted text
		local final_line = cursor_line + #suggestion.lines - 1
		local final_col = #suggestion.lines[#suggestion.lines]
		if #suggestion.lines == 1 then
			final_col = cursor_col + final_col
		end
		vim.api.nvim_win_set_cursor(0, { final_line, final_col })
	end

	-- Clear suggestion
	M.dismiss()

	return true
end

-- Dismiss current suggestion
function M.dismiss()
	if not suggestions_state.current_suggestion then
		return
	end

	local bufnr = suggestions_state.current_suggestion.position.bufnr

	-- Clear virtual text
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, suggestions_state.ns_id, 0, -1)
	end

	-- Clear state
	suggestions_state.current_suggestion = nil
end

-- Enable suggestions
function M.enable()
	suggestions_state.enabled = true
	vim.notify("Amazon Q suggestions enabled", vim.log.levels.INFO)
end

-- Disable suggestions
function M.disable()
	suggestions_state.enabled = false
	M.dismiss()
	vim.notify("Amazon Q suggestions disabled", vim.log.levels.INFO)
end

-- Toggle suggestions
function M.toggle()
	if suggestions_state.enabled then
		M.disable()
	else
		M.enable()
	end
end

-- Check if suggestions are enabled
function M.is_enabled()
	return suggestions_state.enabled
end

return M
