local M = {}

local utils = require("q.utils")

-- Chat state
local chat_state = {
	bufnr = nil,
	winid = nil,
	input_bufnr = nil,
	input_winid = nil,
	history = {},
	is_open = false,
	original_bufnr = nil, -- Track the original buffer for % expansion
	original_winid = nil, -- Track the original window
	closing = false, -- Flag to avoid triggering our own autocommands
}

-- Forward declarations
local setup_chat_keymaps
local send_current_message
local add_message
local display_message
local refresh_chat_display
local send_message_authenticated
local create_chat_window
local setup_window_close_detection

-- Add message to chat history and display
---@param role string "user" or "assistant"
---@param content string Message content
add_message = function(role, content)
	local timestamp = os.date("%H:%M:%S")
	local message = {
		role = role,
		content = content,
		timestamp = timestamp,
	}

	table.insert(chat_state.history, message)

	-- Check if buffer is valid and display message
	if
		chat_state.bufnr
		and pcall(vim.api.nvim_buf_is_valid, chat_state.bufnr)
		and vim.api.nvim_buf_is_valid(chat_state.bufnr)
	then
		display_message(message)
	end
end

-- Display message in chat buffer
---@param message table Message object
display_message = function(message)
	local lines = {}
	local prefix = message.role == "user" and "**You**" or "**Amazon Q**"

	table.insert(lines, "")
	table.insert(lines, prefix .. " (" .. message.timestamp .. ")")
	table.insert(lines, "")

	-- Split content into lines and strip trailing whitespace
	for line in message.content:gmatch("[^\r\n]+") do
		-- Strip trailing whitespace from each line
		local clean_line = line:gsub("%s+$", "")
		table.insert(lines, clean_line)
	end

	table.insert(lines, "")
	table.insert(lines, "---")

	-- Make buffer modifiable temporarily
	vim.bo[chat_state.bufnr].modifiable = true

	-- Append lines
	local current_lines = vim.api.nvim_buf_get_lines(chat_state.bufnr, 0, -1, false)
	vim.list_extend(current_lines, lines)
	vim.api.nvim_buf_set_lines(chat_state.bufnr, 0, -1, false, current_lines)

	-- Make buffer read-only again
	vim.bo[chat_state.bufnr].modifiable = false

	-- Scroll to bottom
	if chat_state.winid and vim.api.nvim_win_is_valid(chat_state.winid) then
		local line_count = vim.api.nvim_buf_line_count(chat_state.bufnr)
		vim.api.nvim_win_set_cursor(chat_state.winid, { line_count, 0 })
	end
end

-- Refresh the entire chat display
refresh_chat_display = function()
	if
		not chat_state.bufnr
		or not pcall(vim.api.nvim_buf_is_valid, chat_state.bufnr)
		or not vim.api.nvim_buf_is_valid(chat_state.bufnr)
	then
		return
	end

	-- Clear buffer
	vim.bo[chat_state.bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(chat_state.bufnr, 0, -1, false, {})
	vim.bo[chat_state.bufnr].modifiable = false

	-- Redisplay all messages
	for _, message in ipairs(chat_state.history) do
		display_message(message)
	end
end

-- Send message after authentication is confirmed
---@param message string User message
send_message_authenticated = function(message)
	-- Get current buffer context
	local context = utils.get_buffer_context()

	-- Prepare Q command arguments
	local args = { "chat", "--no-interactive", "--trust-all-tools" }

	-- Add the message
	table.insert(args, message)

	-- Only show command execution in debug mode
	local ok, q_module = pcall(require, "q")
	local config = ok and q_module.config or nil
	if config and config.debug_cli then
		vim.notify("Executing: q " .. table.concat(args, " "), vim.log.levels.DEBUG)
	end

	-- Show loading indicator
	add_message("assistant", "🤔 Thinking...")

	-- Execute Q command asynchronously
	utils.execute_q_command(args, function(output, error)
		if error then
			-- Remove loading message and add error
			if #chat_state.history > 0 and chat_state.history[#chat_state.history].content == "🤔 Thinking..." then
				table.remove(chat_state.history)
				-- Refresh display
				refresh_chat_display()
			end

			-- Check if it's an authentication error
			if error:match("not authenticated") or error:match("login") or error:match("auth") then
				add_message("assistant", "❌ Authentication expired. Please run :Q login to re-authenticate.")
			else
				-- Provide more detailed error information
				local error_msg = "❌ Error: "
					.. (error ~= "" and error or "Amazon Q CLI returned an error but no details were provided")
				add_message("assistant", error_msg)
			end

			-- Also log the full command for debugging (only if debug is enabled)
			if config and config.debug_cli then
				vim.notify("Q command failed: " .. table.concat(args, " "), vim.log.levels.DEBUG)
			end
			return
		end

		if output and output ~= "" then
			-- Remove loading message
			if #chat_state.history > 0 and chat_state.history[#chat_state.history].content == "🤔 Thinking..." then
				table.remove(chat_state.history)
				-- Refresh display
				refresh_chat_display()
			end

			-- Check if streaming is enabled
			local streaming_enabled = config and config.streaming ~= false -- Default to true

			if streaming_enabled then
				-- Add message with empty content first
				local timestamp = os.date("%H:%M:%S")
				local message = {
					role = "assistant",
					content = "",
					timestamp = timestamp,
				}
				table.insert(chat_state.history, message)
				display_message(message)

				-- Split output into lines for streaming effect
				local lines = {}
				for line in output:gmatch("[^\r\n]+") do
					table.insert(lines, line)
				end

				local function update_content(index)
					if index > #lines then
						return
					end

					-- Update message content
					message.content = message.content .. (index > 1 and "\n" or "") .. lines[index]

					-- Update display
					refresh_chat_display()

					-- Schedule next line with delay
					vim.defer_fn(function()
						update_content(index + 1)
					end, 100)
				end

				-- Start streaming
				update_content(1)
			else
				-- Just add the complete message at once
				add_message("assistant", output)
			end
		else
			-- Remove loading message and show error
			if #chat_state.history > 0 and chat_state.history[#chat_state.history].content == "🤔 Thinking..." then
				table.remove(chat_state.history)
				refresh_chat_display()
			end
			add_message("assistant", "❌ No response received from Amazon Q")
		end
	end)
end

-- Function to set up window close detection
setup_window_close_detection = function()
	-- Create an autocommand group for our window close detection
	local augroup = vim.api.nvim_create_augroup("QChatWindowClose", { clear = true })

	-- Detect when chat buffer is closed
	if chat_state.bufnr and vim.api.nvim_buf_is_valid(chat_state.bufnr) then
		vim.api.nvim_create_autocmd("BufWinLeave", {
			buffer = chat_state.bufnr,
			group = augroup,
			callback = function()
				-- Only close if this is the main chat buffer and not during our own close operation
				if not chat_state.closing then
					vim.schedule(function()
						M.close()
					end)
				end
			end,
			desc = "Detect when Amazon Q chat window is closed with :q",
		})
	end

	-- Detect when input buffer is closed
	if chat_state.input_bufnr and vim.api.nvim_buf_is_valid(chat_state.input_bufnr) then
		vim.api.nvim_create_autocmd("BufWinLeave", {
			buffer = chat_state.input_bufnr,
			group = augroup,
			callback = function()
				-- Only close if this is the input buffer and not during our own close operation
				if not chat_state.closing then
					vim.schedule(function()
						M.close()
					end)
				end
			end,
			desc = "Detect when Amazon Q chat input window is closed with :q",
		})
	end
end

-- Create chat window
create_chat_window = function()
	local ok, q_module = pcall(require, "q")
	local config = ok and q_module.config and q_module.config.chat_window
		or {
			width = 80,
			height = 20,
			position = "right",
		}

	if config.position == "float" then
		local bufnr, winid = utils.create_float_window({
			width = config.width,
			height = config.height,
			title = "Amazon Q Chat",
			border = "rounded",
		})
		chat_state.bufnr = bufnr
		chat_state.winid = winid
	else
		local bufnr, winid = utils.create_split_window({
			position = config.position,
			size = config.width,
		})
		chat_state.bufnr = bufnr
		chat_state.winid = winid
	end

	-- Set buffer options (don't set names to avoid conflicts)
	vim.bo[chat_state.bufnr].filetype = "markdown"
	vim.bo[chat_state.bufnr].modifiable = false
	vim.bo[chat_state.bufnr].buftype = "nofile"
	vim.bo[chat_state.bufnr].swapfile = false
	vim.bo[chat_state.bufnr].bufhidden = "wipe"

	-- Disable trailing whitespace display in chat window
	if chat_state.winid and vim.api.nvim_win_is_valid(chat_state.winid) then
		vim.api.nvim_set_option_value("list", false, { win = chat_state.winid })
		vim.api.nvim_set_option_value("listchars", "", { win = chat_state.winid })

		-- Set markdown-specific options for better display
		vim.api.nvim_set_option_value("conceallevel", 2, { win = chat_state.winid })
		vim.api.nvim_set_option_value("wrap", true, { win = chat_state.winid })
		vim.api.nvim_set_option_value("linebreak", true, { win = chat_state.winid })
	end

	-- Create input buffer at the bottom
	vim.cmd("horizontal rightbelow 3split")
	chat_state.input_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, chat_state.input_bufnr)
	chat_state.input_winid = vim.api.nvim_get_current_win()

	-- Set input buffer options (don't set names to avoid conflicts)
	vim.bo[chat_state.input_bufnr].buftype = "nofile"
	vim.bo[chat_state.input_bufnr].swapfile = false
	vim.bo[chat_state.input_bufnr].filetype = "markdown"
	vim.bo[chat_state.input_bufnr].bufhidden = "wipe"

	-- Create empty line for input
	vim.api.nvim_buf_set_lines(chat_state.input_bufnr, 0, -1, false, { "" })

	-- Get ghost text configuration
	local ok, q_module = pcall(require, "q")
	local ghost_config = ok and q_module.config and q_module.config.ghost_text
		or {
			enabled = true,
			chat_prompt = "Ask Amazon Q: ",
			highlight = "Comment",
		}

	-- Create namespace for virtual text
	local ns_id = vim.api.nvim_create_namespace("q_chat_ghost_text")

	-- Add ghost text prompt using virtual text (if enabled)
	if ghost_config.enabled then
		vim.api.nvim_buf_set_extmark(chat_state.input_bufnr, ns_id, 0, 0, {
			virt_text = { { ghost_config.chat_prompt, ghost_config.highlight } },
			virt_text_pos = "inline",
		})
	end

	-- Position cursor at the beginning of the line
	vim.api.nvim_win_set_cursor(chat_state.input_winid, { 1, 0 })

	-- Set up keymaps for chat window
	setup_chat_keymaps()

	-- Set up detection for when windows are closed with :q
	setup_window_close_detection()

	chat_state.is_open = true
end

-- Get the original buffer path for display
---@return string|nil path The original buffer path or nil if not available
local function get_original_buffer_path()
	if chat_state.original_bufnr and vim.api.nvim_buf_is_valid(chat_state.original_bufnr) then
		local path = vim.api.nvim_buf_get_name(chat_state.original_bufnr)
		if path and path ~= "" then
			return path
		end
	end
	return nil
end

-- Send current message from input buffer
send_current_message = function()
	local lines = vim.api.nvim_buf_get_lines(chat_state.input_bufnr, 0, -1, false)
	local input = table.concat(lines, "\n")

	-- Since we're using ghost text, the input is the actual message content
	local message = input:gsub("^%s*", ""):gsub("%s*$", "") -- Trim whitespace
	if not message or message == "" then
		return
	end

	-- Expand % to current buffer path (use original buffer if available)
	message = utils.expand_current_buffer_path(message, chat_state.original_bufnr)

	M.send_message(message)

	-- Clear input and reset ghost text
	vim.api.nvim_buf_set_lines(chat_state.input_bufnr, 0, -1, false, { "" })

	-- Get ghost text configuration
	local ok, q_module = pcall(require, "q")
	local ghost_config = ok and q_module.config and q_module.config.ghost_text
		or {
			enabled = true,
			chat_prompt = "Ask Amazon Q: ",
			highlight = "Comment",
		}

	-- Recreate ghost text (if enabled)
	if ghost_config.enabled then
		local ns_id = vim.api.nvim_create_namespace("q_chat_ghost_text")
		vim.api.nvim_buf_clear_namespace(chat_state.input_bufnr, ns_id, 0, -1)
		vim.api.nvim_buf_set_extmark(chat_state.input_bufnr, ns_id, 0, 0, {
			virt_text = { { ghost_config.chat_prompt, ghost_config.highlight } },
			virt_text_pos = "inline",
		})
	end

	vim.api.nvim_win_set_cursor(chat_state.input_winid, { 1, 0 })
end

-- Open chat window
function M.open()
	if chat_state.is_open then
		-- Focus existing chat window
		if chat_state.input_winid and vim.api.nvim_win_is_valid(chat_state.input_winid) then
			vim.api.nvim_set_current_win(chat_state.input_winid)
		end
		return
	end

	-- Capture the original buffer and window before opening chat
	chat_state.original_bufnr = vim.api.nvim_get_current_buf()
	chat_state.original_winid = vim.api.nvim_get_current_win()

	create_chat_window()

	-- Add welcome message if history is empty
	if #chat_state.history == 0 then
		local welcome_msg = "Hello! I'm Amazon Q. How can I help you with your code today?"
		local original_path = get_original_buffer_path()
		if original_path then
			local filename = vim.fn.fnamemodify(original_path, ":t")
			welcome_msg = welcome_msg .. "\n\n💡 Tip: Use `%` to refer to your current file: **" .. filename .. "**"
		end
		add_message("assistant", welcome_msg)
	else
		-- Refresh display with existing history
		refresh_chat_display()
	end
end

-- Close chat window
function M.close()
	-- Set a flag to avoid triggering our own autocommands
	chat_state.closing = true

	if chat_state.winid and vim.api.nvim_win_is_valid(chat_state.winid) then
		vim.api.nvim_win_close(chat_state.winid, true)
	end

	if chat_state.input_winid and vim.api.nvim_win_is_valid(chat_state.input_winid) then
		vim.api.nvim_win_close(chat_state.input_winid, true)
	end

	-- Clean up buffer references
	if chat_state.bufnr and vim.api.nvim_buf_is_valid(chat_state.bufnr) then
		vim.api.nvim_buf_delete(chat_state.bufnr, { force = true })
	end

	if chat_state.input_bufnr and vim.api.nvim_buf_is_valid(chat_state.input_bufnr) then
		vim.api.nvim_buf_delete(chat_state.input_bufnr, { force = true })
	end

	-- Reset window and buffer state, but preserve chat history
	chat_state.is_open = false
	chat_state.winid = nil
	chat_state.input_winid = nil
	chat_state.bufnr = nil
	chat_state.input_bufnr = nil
	chat_state.original_bufnr = nil
	chat_state.original_winid = nil
	chat_state.closing = false -- Reset the closing flag

	-- Note: We intentionally don't reset chat_state.history to preserve the conversation
end

-- Send message to Amazon Q
---@param message string User message
function M.send_message(message)
	if not chat_state.is_open then
		M.open()
	end

	-- Add user message to history
	add_message("user", message)

	-- Check authentication before proceeding
	local auth = require("q.auth")
	auth.ensure_authenticated(function()
		-- Authenticated, proceed with sending message
		send_message_authenticated(message)
	end, function(error)
		-- Not authenticated, show error
		add_message("assistant", "❌ Authentication required. Please run :Q login to authenticate with Amazon Q.")
	end)
end

-- Toggle chat window
function M.toggle()
	if chat_state.is_open then
		M.close()
	else
		M.open()
	end
end

-- Clear chat history
function M.clear()
	chat_state.history = {}
	if chat_state.bufnr and vim.api.nvim_buf_is_valid(chat_state.bufnr) then
		vim.bo[chat_state.bufnr].modifiable = true
		vim.api.nvim_buf_set_lines(chat_state.bufnr, 0, -1, false, {})
		vim.bo[chat_state.bufnr].modifiable = false

		add_message("assistant", "Chat history cleared. How can I help you?")
	end
end

-- Setup keymaps for chat interaction
setup_chat_keymaps = function()
	local opts = { buffer = chat_state.input_bufnr, noremap = true, silent = true }
	local ns_id = vim.api.nvim_create_namespace("q_chat_ghost_text")

	-- Get ghost text configuration
	local ok, q_module = pcall(require, "q")
	local ghost_config = ok and q_module.config and q_module.config.ghost_text
		or {
			enabled = true,
			chat_prompt = "Ask Amazon Q: ",
			highlight = "Comment",
		}

	-- Function to update ghost text visibility
	local function update_ghost_text()
		if not ghost_config.enabled then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(chat_state.input_bufnr, 0, -1, false)
		local content = table.concat(lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")

		-- Clear existing ghost text
		vim.api.nvim_buf_clear_namespace(chat_state.input_bufnr, ns_id, 0, -1)

		-- Show ghost text only if buffer is empty or contains only whitespace
		if content == "" then
			-- Only show ghost text on the first line if it's empty
			local first_line = lines[1] or ""
			if first_line:gsub("^%s*", ""):gsub("%s*$", "") == "" then
				vim.api.nvim_buf_set_extmark(chat_state.input_bufnr, ns_id, 0, 0, {
					virt_text = { { ghost_config.chat_prompt, ghost_config.highlight } },
					virt_text_pos = "inline",
				})
			end
		end
	end

	-- Send message on Enter
	vim.keymap.set("i", "<CR>", function()
		send_current_message()
	end, opts)

	vim.keymap.set("n", "<CR>", function()
		send_current_message()
	end, opts)

	-- Close chat on Escape
	vim.keymap.set("n", "<Esc>", function()
		M.close()
	end, opts)

	-- Navigate to chat window
	vim.keymap.set("n", "<C-w>k", function()
		vim.api.nvim_set_current_win(chat_state.winid)
	end, opts)

	-- Clear input
	vim.keymap.set("n", "<C-c>", function()
		vim.api.nvim_buf_set_lines(chat_state.input_bufnr, 0, -1, false, { "" })
		update_ghost_text()
		vim.api.nvim_win_set_cursor(chat_state.input_winid, { 1, 0 })
	end, opts)

	-- Set up autocommands to handle ghost text visibility
	if ghost_config.enabled then
		local augroup = vim.api.nvim_create_augroup("QChatGhostText", { clear = true })

		-- Update ghost text on text changes
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			buffer = chat_state.input_bufnr,
			group = augroup,
			callback = update_ghost_text,
			desc = "Update ghost text visibility in Q chat input",
		})

		-- Update ghost text when entering insert mode
		vim.api.nvim_create_autocmd("InsertEnter", {
			buffer = chat_state.input_bufnr,
			group = augroup,
			callback = update_ghost_text,
			desc = "Update ghost text when entering insert mode",
		})

		-- Update ghost text when leaving insert mode
		vim.api.nvim_create_autocmd("InsertLeave", {
			buffer = chat_state.input_bufnr,
			group = augroup,
			callback = update_ghost_text,
			desc = "Update ghost text when leaving insert mode",
		})
	end
end

return M
