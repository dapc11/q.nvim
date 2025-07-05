local M = {}

local utils = require("q.utils")

-- Default configuration values
local defaults = {
	license = "pro",
	identity_provider = "https://d-9367077c28.awsapps.com/start",
	region = "eu-west-1",
}

-- Check if user is authenticated
---@return boolean is_authenticated
function M.is_authenticated()
	-- Try a simple command to check if authentication works
	local result = utils.execute_q_command({ "chat", "--no-interactive", "--trust-all-tools", "test" })
	return result ~= nil
end

-- Check authentication status and display result
function M.check_status()
	vim.notify("Checking Amazon Q authentication status...", vim.log.levels.INFO)

	utils.execute_q_command({ "chat", "--no-interactive", "--trust-all-tools", "test" }, function(output, error)
		if error then
			if error:match("not authenticated") or error:match("login") or error:match("auth") then
				vim.notify("❌ Not authenticated with Amazon Q. Please run :Q login", vim.log.levels.WARN)
			else
				vim.notify("❌ Authentication check failed: " .. error, vim.log.levels.ERROR)
			end
		else
			vim.notify("✅ Successfully authenticated with Amazon Q", vim.log.levels.INFO)
		end
	end)
end

-- Login to Amazon Q (simplified approach)
---@param args table Command arguments
function M.login(args)
	-- Get values from environment variables with fallback defaults
	local env_license = os.getenv("Q_NVIM_LICENSE")
	local env_identity_provider = os.getenv("Q_NVIM_IDENTITY_PROVIDER")
	local env_region = os.getenv("Q_NVIM_REGION")

	-- Apply environment variables to defaults if they exist
	if env_license then
		defaults.license = env_license
	end
	if env_identity_provider then
		defaults.identity_provider = env_identity_provider
	end
	if env_region then
		defaults.region = env_region
	end

	-- Parse arguments and apply defaults
	local provided_args = {}
	for _, arg in ipairs(args) do
		if arg:match("^%-%-license=") then
			provided_args.license = arg:match("^%-%-license=(.+)")
		elseif arg:match("^%-%-identity%-provider=") then
			provided_args.identity_provider = arg:match("^%-%-identity%-provider=(.+)")
		elseif arg:match("^%-%-region=") then
			provided_args.region = arg:match("^%-%-region=(.+)")
		elseif arg == "--use-device-flow" then
			provided_args.use_device_flow = true
		end
	end

	-- Apply defaults if not provided (environment variables take precedence over hardcoded defaults)
	local final_license = provided_args.license or defaults.license
	local final_identity_provider = provided_args.identity_provider or defaults.identity_provider
	local final_region = provided_args.region or defaults.region

	-- Build command string
	local cmd_parts = { "q", "login", "--license=" .. final_license }

	if final_license == "pro" then
		table.insert(cmd_parts, "--identity-provider=" .. final_identity_provider)
		table.insert(cmd_parts, "--region=" .. final_region)
	end

	if provided_args.use_device_flow then
		table.insert(cmd_parts, "--use-device-flow")
	end

	local cmd_str = table.concat(cmd_parts, " ")

	vim.notify("Starting Amazon Q login process...", vim.log.levels.INFO)
	vim.notify(
		"Using: License="
		.. final_license
		.. (
			final_license == "pro"
			and (", Identity Provider=" .. final_identity_provider .. ", Region=" .. final_region)
			or ""
		),
		vim.log.levels.INFO
	)

	-- Open terminal with the login command
	vim.cmd("split")
	vim.cmd("resize 15")
	local term_cmd = "terminal " .. cmd_str
	vim.cmd(term_cmd)

	-- Switch to insert mode in terminal
	vim.cmd("startinsert")

	vim.notify(
		"Complete the login process in the terminal above. Close the terminal when done and run :Q status to verify.",
		vim.log.levels.INFO
	)
end

-- Logout from Amazon Q
function M.logout()
	vim.notify("Logging out from Amazon Q...", vim.log.levels.INFO)

	-- Amazon Q CLI might not have a direct logout command, so we'll try common approaches
	utils.execute_q_command({ "logout" }, function(output, error)
		if error then
			-- If logout command doesn't exist, provide manual instructions
			if error:match("Unknown command") or error:match("not found") then
				vim.notify("ℹ️  Amazon Q CLI may not have a logout command. To logout:", vim.log.levels.INFO)
				vim.notify("   1. Clear credentials manually", vim.log.levels.INFO)
				vim.notify("   2. Or run 'q login' to switch accounts", vim.log.levels.INFO)
			else
				vim.notify("❌ Logout failed: " .. error, vim.log.levels.ERROR)
			end
		else
			vim.notify("✅ Successfully logged out from Amazon Q", vim.log.levels.INFO)
		end
	end)
end

-- Check authentication before executing commands
---@param callback function Function to call if authenticated
---@param error_callback? function Function to call if not authenticated
function M.ensure_authenticated(callback, error_callback)
	utils.execute_q_command({ "chat", "--no-interactive", "--trust-all-tools", "test" }, function(output, error)
		if error then
			if error:match("not authenticated") or error:match("login") or error:match("auth") then
				vim.notify("❌ Not authenticated with Amazon Q. Please run :Q login", vim.log.levels.WARN)
				if error_callback then
					error_callback("Not authenticated")
				end
			else
				-- Other error, might still be authenticated
				callback()
			end
		else
			callback()
		end
	end)
end

-- Get authentication info for display
---@return table auth_info
function M.get_auth_info()
	-- This could be expanded to show current user, license type, etc.
	return {
		authenticated = M.is_authenticated(),
		user = "Unknown", -- Could be extracted from CLI output
		license = "Unknown", -- Could be extracted from CLI output
	}
end

return M
