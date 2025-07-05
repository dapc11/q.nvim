-- Luacheck configuration for q.nvim
std = "luajit"
cache = true

-- Global variables
globals = {
  "vim",
  "describe",
  "it",
  "before_each",
  "after_each",
  "setup",
  "teardown"
}

-- Ignore specific warnings
ignore = {
  "212", -- Unused argument
  "213", -- Unused loop variable
  "631", -- Line is too long
}

-- Files to exclude
exclude_files = {
  ".luarocks",
  "lua_modules"
}

-- Max line length
max_line_length = 120

-- Max cyclomatic complexity
max_cyclomatic_complexity = 10
