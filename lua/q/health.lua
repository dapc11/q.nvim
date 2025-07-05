local M = {}

local health = vim.health

function M.check()
	health.start("q.nvim Health Check")

	-- Check if Amazon Q CLI is installed
	if vim.fn.executable("q") == 1 then
		health.ok("Amazon Q CLI is installed")

		-- Check Q CLI version
		local result = vim.system({ "q", "--version" }, { text = true, timeout = 5000 }):wait()
		if result.code == 0 and result.stdout then
			health.info("Amazon Q CLI version: " .. result.stdout:gsub("\n", ""))
		else
			health.warn("Could not determine Amazon Q CLI version")
		end

		-- Check authentication status
		local auth = require("q.auth")
		if auth.is_authenticated() then
			health.ok("Amazon Q CLI is authenticated")
		else
			health.warn("Amazon Q CLI is not authenticated. Run :Q login to authenticate.")
		end

		-- Test Q CLI functionality
		local test_result = vim.system({ "q", "chat", "--help" }, { text = true, timeout = 5000 }):wait()
		if test_result.code == 0 then
			health.ok("Amazon Q CLI chat command is working")
		else
			health.error("Amazon Q CLI chat command failed: " .. (test_result.stderr or "Unknown error"))
		end
	else
		health.error("Amazon Q CLI is not installed or not in PATH")
		health.info(
			"Please install Amazon Q CLI: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-getting-started-installing.html"
		)
	end

	-- Check plugin configuration
	local config = require("q").config
	if config then
		health.ok("Plugin configuration loaded")

		-- Validate configuration
		local ok, err = pcall(vim.validate, {
			enabled = { config.enabled, "boolean" },
			auto_suggestions = { config.auto_suggestions, "boolean" },
			suggestion_delay = { config.suggestion_delay, "number" },
		})

		if ok then
			health.ok("Configuration is valid")
		else
			health.error("Invalid configuration: " .. err)
		end

		-- Check if plugin is enabled
		if config.enabled then
			health.ok("Plugin is enabled")
		else
			health.warn("Plugin is disabled")
		end

		-- Check auto suggestions
		if config.auto_suggestions then
			health.ok("Auto suggestions are enabled")
		else
			health.info("Auto suggestions are disabled")
		end
	else
		health.error("Could not load plugin configuration")
	end

	-- Check Neovim version
	local nvim_version = vim.version()
	if nvim_version.major > 0 or nvim_version.minor >= 9 then
		health.ok(
			string.format(
				"Neovim version %d.%d.%d is supported",
				nvim_version.major,
				nvim_version.minor,
				nvim_version.patch
			)
		)
	else
		health.error(
			string.format(
				"Neovim version %d.%d.%d is not supported (requires 0.9+)",
				nvim_version.major,
				nvim_version.minor,
				nvim_version.patch
			)
		)
	end

	-- Check for required Lua features
	if vim.fn.has("nvim-0.9") == 1 then
		health.ok("Required Neovim features are available")
	else
		health.error("Required Neovim features are not available")
	end

	-- Check current buffer filetype support
	local current_ft = vim.bo.filetype
	if current_ft and current_ft ~= "" then
		local utils = require("q.utils")
		if utils.is_supported_filetype(current_ft) then
			health.ok("Current filetype '" .. current_ft .. "' is supported")
		else
			health.info("Current filetype '" .. current_ft .. "' is not explicitly supported")
		end
	else
		health.info("No filetype set for current buffer")
	end

	-- Check plugin state
	local q_module = require("q")
	local state = q_module.state or { initialized = false }
	if state.initialized then
		health.ok("Plugin is initialized")
	else
		health.warn("Plugin is not initialized")
	end

	-- Check suggestions system
	local suggestions = require("q.suggestions")
	if suggestions.is_enabled() then
		health.ok("Suggestions system is enabled")
	else
		health.info("Suggestions system is disabled")
	end

	-- Performance checks
	health.start("Performance")

	-- Check suggestion delay
	if config and config.suggestion_delay then
		if config.suggestion_delay < 100 then
			health.warn("Suggestion delay is very low (" .. config.suggestion_delay .. "ms) - may impact performance")
		elseif config.suggestion_delay > 2000 then
			health.warn("Suggestion delay is very high (" .. config.suggestion_delay .. "ms) - may feel slow")
		else
			health.ok("Suggestion delay is reasonable (" .. config.suggestion_delay .. "ms)")
		end
	end

	-- Security checks
	health.start("Security")

	-- Check if we're in a trusted directory (basic check)
	local cwd = vim.fn.getcwd()
	if cwd:match("^/tmp") or cwd:match("^/var/tmp") then
		health.warn("Working in temporary directory - be cautious about code suggestions")
	else
		health.ok("Working directory appears safe")
	end

	-- Integration checks
	health.start("Integration")

	-- Check for common plugin managers
	local plugin_managers = {
		{
			name = "lazy.nvim",
			check = function()
				return pcall(require, "lazy")
			end,
		},
		{
			name = "packer.nvim",
			check = function()
				return pcall(require, "packer")
			end,
		},
		{
			name = "vim-plug",
			check = function()
				return vim.fn.exists(":PlugInstall") == 2
			end,
		},
	}

	local found_manager = false
	for _, manager in ipairs(plugin_managers) do
		if manager.check() then
			health.info("Using " .. manager.name .. " plugin manager")
			found_manager = true
			break
		end
	end

	if not found_manager then
		health.info("No recognized plugin manager detected")
	end

	-- Check for complementary plugins
	local complementary_plugins = {
		{ name = "nvim-cmp", module = "cmp" },
		{ name = "telescope.nvim", module = "telescope" },
		{ name = "lualine.nvim", module = "lualine" },
	}

	for _, plugin in ipairs(complementary_plugins) do
		if pcall(require, plugin.module) then
			health.info(plugin.name .. " is available for potential integration")
		end
	end
end

return M
