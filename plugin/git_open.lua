-- lua_plugin/git_open.lua - Plugin loader (Lua version for Neovim)
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

if vim.g.loaded_git_open then
  return
end
vim.g.loaded_git_open = 1

local git_open = require('git_open')

-- Initialize with default settings
git_open.setup()

-- Create commands
vim.api.nvim_create_user_command('OpenGitRepo', function()
  git_open.open_repo()
end, {})

vim.api.nvim_create_user_command('OpenGitBranch', function()
  git_open.open_branch()
end, {})

vim.api.nvim_create_user_command('OpenGitFile', function()
  git_open.open_file()
end, { range = true })

vim.api.nvim_create_user_command('OpenGitCommit', function()
  git_open.open_commit()
end, {})

vim.api.nvim_create_user_command('OpenGitPR', function(opts)
  git_open.open_pr(opts.args)
end, { nargs = '?' })

vim.api.nvim_create_user_command('OpenGitMR', function(opts)
  git_open.open_mr(opts.args)
end, { nargs = '?' })

vim.api.nvim_create_user_command('OpenGitFileLastChange', function()
  git_open.open_file_last_change()
end, {})
