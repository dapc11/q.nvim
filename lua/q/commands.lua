local M = {}

local chat = require("q.chat")
local inline_chat = require("q.inline_chat")

---@class QSubcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, QSubcommand>
local subcommand_tbl = {
	chat = {
		impl = function(args, opts)
			if #args == 0 then
				chat.open()
			else
				local query = table.concat(args, " ")
				-- Expand % to current buffer path
				local utils = require("q.utils")
				query = utils.expand_current_buffer_path(query)
				chat.send_message(query)
			end
		end,
		complete = function(subcmd_arg_lead)
			-- Common chat prompts
			local prompts = {
				"explain this code",
				"optimize this function",
				"add comments",
				"write tests",
				"fix bugs",
				"refactor",
				"add error handling",
				"improve performance",
			}
			return vim.iter(prompts)
				:filter(function(prompt)
					return prompt:find(subcmd_arg_lead, 1, true) ~= nil
				end)
				:totable()
		end,
	},
	inline = {
		impl = function(args, opts)
			local query = #args > 0 and table.concat(args, " ") or nil
			-- Expand % to current buffer path if query exists
			if query then
				local utils = require("q.utils")
				query = utils.expand_current_buffer_path(query)
			end
			inline_chat.start(opts, query)
		end,
		complete = function(subcmd_arg_lead)
			local prompts = {
				"explain",
				"optimize",
				"comment",
				"test",
				"fix",
				"refactor",
			}
			return vim.iter(prompts)
				:filter(function(prompt)
					return prompt:find(subcmd_arg_lead, 1, true) ~= nil
				end)
				:totable()
		end,
	},
	reopen = {
		impl = function(args, opts)
			chat.open()
		end,
	},
	debug = {
		impl = function(args, opts)
			-- Test Amazon Q CLI directly
			local test_message = args[1] or "hello"
			print("Testing Amazon Q CLI with message: " .. test_message)

			local utils = require("q.utils")
			utils.execute_q_command({ "chat", "--no-interactive", test_message }, function(output, error)
				if error then
					print("Error: " .. error)
				else
					print("Success! Output length: " .. (output and #output or 0))
					if output then
						print("First 100 chars: " .. string.sub(output, 1, 100))
					end
				end
			end)
		end,
	},
	login = {
		impl = function(args, opts)
			local auth = require("q.auth")
			auth.login(args)
		end,
		complete = function(subcmd_arg_lead)
			-- Get environment variables for completion suggestions
			local env_license = os.getenv("Q_NVIM_LICENSE") or "pro"
			local env_identity_provider = os.getenv("Q_NVIM_IDENTITY_PROVIDER")
				or "https://d-9367077c28.awsapps.com/start"
			local env_region = os.getenv("Q_NVIM_REGION") or "eu-west-1"

			local options = {
				"--license=free",
				"--license=" .. env_license,
				"--identity-provider=" .. env_identity_provider,
				"--region=" .. env_region,
				"--region=us-east-1",
				"--region=us-west-2",
				"--use-device-flow",
			}
			return vim.iter(options)
				:filter(function(opt)
					return opt:find(subcmd_arg_lead, 1, true) ~= nil
				end)
				:totable()
		end,
	},
	logout = {
		impl = function(args, opts)
			local auth = require("q.auth")
			auth.logout()
		end,
	},
	status = {
		impl = function(args, opts)
			local auth = require("q.auth")
			auth.check_status()
		end,
	},
	["login-default"] = {
		impl = function(args, opts)
			-- Login with your organization's defaults
			local auth = require("q.auth")
			vim.notify("Logging in with organization defaults...", vim.log.levels.INFO)
			auth.login({}) -- Empty args will use defaults
		end,
	},
	["login-manual"] = {
		impl = function(args, opts)
			-- Show manual login command using environment variables
			local env_license = os.getenv("Q_NVIM_LICENSE") or "pro"
			local env_identity_provider = os.getenv("Q_NVIM_IDENTITY_PROVIDER")
				or "https://d-9367077c28.awsapps.com/start"
			local env_region = os.getenv("Q_NVIM_REGION") or "eu-west-1"

			local cmd = string.format(
				"q login --license=%s --identity-provider=%s --region=%s",
				env_license,
				env_identity_provider,
				env_region
			)
			vim.notify("Please run this command in your terminal:", vim.log.levels.INFO)
			vim.notify(cmd, vim.log.levels.INFO)
			vim.notify("Then run :Q status to verify authentication", vim.log.levels.INFO)

			-- Copy to clipboard if possible
			if vim.fn.has("clipboard") == 1 then
				vim.fn.setreg("+", cmd)
				vim.notify("Command copied to clipboard!", vim.log.levels.INFO)
			end
		end,
	},
}

---@param opts table
local function q_cmd(opts)
	local fargs = opts.fargs
	local subcommand_key = fargs[1]
	local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
	local subcommand = subcommand_tbl[subcommand_key]

	if not subcommand then
		vim.notify("Q: Unknown command: " .. (subcommand_key or ""), vim.log.levels.ERROR)
		return
	end

	subcommand.impl(args, opts)
end

function M.setup()
	vim.api.nvim_create_user_command("Q", q_cmd, {
		nargs = "*",
		desc = "Amazon Q integration commands",
		complete = function(arg_lead, cmdline, _)
			-- Get the subcommand
			local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*Q[!]*%s(%S+)%s(.*)$")
			if
				subcmd_key
				and subcmd_arg_lead
				and subcommand_tbl[subcmd_key]
				and subcommand_tbl[subcmd_key].complete
			then
				return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
			end

			-- Check if cmdline is a subcommand
			if cmdline:match("^['<,'>]*Q[!]*%s+%w*$") then
				local subcommand_keys = vim.tbl_keys(subcommand_tbl)
				return vim.iter(subcommand_keys)
					:filter(function(key)
						return key:find(arg_lead, 1, true) ~= nil
					end)
					:totable()
			end

			return {}
		end,
		bang = true,
	})
end

return M
