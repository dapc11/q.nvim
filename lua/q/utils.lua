local M = {}

-- Execute Amazon Q CLI command
---@param args string[] Command arguments
---@param callback? function Callback function for async execution
---@return string|nil result Command output or nil if async
function M.execute_q_command(args, callback)
	local cmd = { "q" }
	vim.list_extend(cmd, args)

	-- Get debug setting from config
	local ok, q_module = pcall(require, "q")
	local config = ok and q_module.config or nil
	local debug_enabled = config and config.debug_cli or false

	if callback then
		-- Async execution
		vim.system(cmd, {
			text = true,
			timeout = 30000, -- 30 seconds timeout
		}, function(result)
			-- Schedule the callback to run in the main event loop
			vim.schedule(function()
				-- Only show debug info if explicitly enabled
				if debug_enabled then
					vim.notify("Q CLI Debug - Exit code: " .. result.code, vim.log.levels.DEBUG)
					vim.notify("Q CLI Debug - Stdout: " .. (result.stdout or "nil"), vim.log.levels.DEBUG)
					vim.notify("Q CLI Debug - Stderr: " .. (result.stderr or "nil"), vim.log.levels.DEBUG)
				end

				if result.code == 0 then
					local cleaned_output = M.clean_cli_output(result.stdout or "")
					callback(cleaned_output, nil)
				else
					-- Provide detailed error information
					local error_msg = "Exit code " .. result.code
					if result.stderr and result.stderr ~= "" then
						error_msg = error_msg .. ": " .. M.clean_cli_output(result.stderr)
					end
					if result.stdout and result.stdout ~= "" then
						error_msg = error_msg .. " (stdout: " .. M.clean_cli_output(result.stdout) .. ")"
					end
					callback(nil, error_msg)
				end
			end)
		end)
		return nil
	else
		-- Sync execution
		local result = vim
			.system(cmd, {
				text = true,
				timeout = 30000,
			})
			:wait()

		if result.code == 0 then
			return M.clean_cli_output(result.stdout or "")
		else
			local error_msg = result.stderr or "Unknown error"
			error_msg = M.clean_cli_output(error_msg)
			vim.notify("Amazon Q CLI error: " .. error_msg, vim.log.levels.ERROR)
			return nil
		end
	end
end

-- Clean CLI output by removing unwanted messages and formatting
---@param output string Raw CLI output
---@return string cleaned_output
function M.clean_cli_output(output)
	if not output or output == "" then
		return ""
	end

	-- Remove ANSI escape codes
	local cleaned = output:gsub("\27%[[0-9;]*m", "")

	-- Split into lines for filtering
	local lines = {}
	for line in cleaned:gmatch("[^\r\n]+") do
		local trimmed_line = line:gsub("^%s+", ""):gsub("%s+$", "")

		-- Skip various CLI noise patterns
		local skip_patterns = {
			"^Not all mcp servers loaded",
			"^Configure no%-interactive timeout",
			"^%-%-%-%-%-%-+$",
			"^Executing:",
			"^Q command",
			"^Loading",
			"^Initializing",
			"^Connected to",
			"^Session",
			"^Request ID:",
			"^Response ID:",
			"^%[INFO%]",
			"^%[DEBUG%]",
			"^%[WARN%]",
			"^%[ERROR%]",
		}

		local should_skip = false
		for _, pattern in ipairs(skip_patterns) do
			if trimmed_line:match(pattern) then
				should_skip = true
				break
			end
		end

		if not should_skip and trimmed_line ~= "" then
			-- Strip trailing whitespace from each line before adding
			local clean_line = line:gsub("%s+$", "")
			table.insert(lines, clean_line)
		end
	end

	-- Join lines and clean up extra whitespace
	local result = table.concat(lines, "\n")
	result = result:gsub("^%s+", ""):gsub("%s+$", "") -- Trim start/end
	result = result:gsub("\n\n\n+", "\n\n") -- Normalize multiple newlines to max 2

	return result
end

-- Get current buffer context for Q
---@return table context
function M.get_buffer_context()
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	return {
		bufnr = bufnr,
		filetype = filetype,
		filename = filename,
		lines = lines,
		cursor_line = cursor_pos[1],
		cursor_col = cursor_pos[2],
		content = table.concat(lines, "\n"),
	}
end

-- Get selected text in visual mode
---@return string|nil selected_text
function M.get_visual_selection()
	-- Save the current register content
	local reg_save = vim.fn.getreg("v")
	local regtype_save = vim.fn.getregtype("v")

	-- Yank the visual selection into register 'v'
	vim.cmd('normal! gv"vy')

	-- Get the text from register 'v'
	local selected_text = vim.fn.getreg("v")

	-- Restore the register
	vim.fn.setreg("v", reg_save, regtype_save)

	if selected_text == "" then
		return nil
	end

	return selected_text
end

-- Create a floating window
---@param config table Window configuration
---@return number bufnr, number winid
function M.create_float_window(config)
	local width = config.width or 80
	local height = config.height or 20
	local row = config.row or math.floor((vim.o.lines - height) / 2)
	local col = config.col or math.floor((vim.o.columns - width) / 2)

	local bufnr = vim.api.nvim_create_buf(false, true)

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = config.border or "rounded",
		title = config.title,
		title_pos = "center",
	}

	local winid = vim.api.nvim_open_win(bufnr, true, win_config)

	-- Set buffer options
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].bufhidden = "wipe"

	return bufnr, winid
end

-- Create a split window
---@param config table Window configuration
---@return number bufnr, number winid
function M.create_split_window(config)
	local position = config.position or "right"
	local size = config.size or 80

	local cmd
	if position == "right" then
		cmd = "vertical rightbelow " .. size .. "split"
	elseif position == "left" then
		cmd = "vertical leftabove " .. size .. "split"
	elseif position == "bottom" then
		cmd = "horizontal rightbelow " .. size .. "split"
	elseif position == "top" then
		cmd = "horizontal leftabove " .. size .. "split"
	else
		cmd = "vertical rightbelow " .. size .. "split"
	end

	vim.cmd(cmd)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, bufnr)

	-- Set buffer options
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].bufhidden = "wipe"

	return bufnr, vim.api.nvim_get_current_win()
end

-- Check if filetype is supported
---@param filetype string
---@return boolean
function M.is_supported_filetype(filetype)
	local supported = {
		"go",
		"python",
		"lua",
		"javascript",
		"typescript",
		"rust",
		"c",
		"cpp",
		"java",
		"sh",
		"bash",
		"zsh",
		"yaml",
		"json",
		"html",
		"css",
		"sql",
	}

	return vim.tbl_contains(supported, filetype)
end

-- Debounce function
---@param func function
---@param delay number
---@return function
function M.debounce(func, delay)
	local timer = nil
	return function(...)
		local args = { ... }
		if timer then
			timer:stop()
		end
		timer = vim.defer_fn(function()
			func(unpack(args))
		end, delay)
		return timer
	end
end

-- Escape special characters for display
---@param text string
---@return string
function M.escape_text(text)
	return text:gsub("%%", "%%%%")
end

-- Expand % to current buffer path
---@param text string Text that might contain % references
---@param bufnr? number Optional buffer number to use for expansion (defaults to current buffer)
---@return string Expanded text
function M.expand_current_buffer_path(text, bufnr)
	if not text or text == "" then
		return text
	end

	local current_buffer_path
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		current_buffer_path = vim.api.nvim_buf_get_name(bufnr)
	else
		current_buffer_path = vim.fn.expand("%:p")
	end

	-- Only expand if we have a valid path
	if not current_buffer_path or current_buffer_path == "" then
		return text
	end

	-- Replace standalone % with the full path
	text = text:gsub("([^%%])%%([^%%])", "%1" .. current_buffer_path .. "%2")
	text = text:gsub("^%%([^%%])", current_buffer_path .. "%1")
	text = text:gsub("([^%%])%%$", "%1" .. current_buffer_path)
	text = text:gsub("^%%$", current_buffer_path)

	return text
end

return M
