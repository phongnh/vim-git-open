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
vim.api.nvim_create_user_command('OpenGitRepo', function(opts)
  git_open.open_repo(opts.bang)
end, { bang = true })

vim.api.nvim_create_user_command('OpenGitBranch', function(opts)
  git_open.open_branch(opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '?',
  complete = function(arglead) return git_open.complete_branch(arglead) end,
})

vim.api.nvim_create_user_command('OpenGitFile', function(opts)
  git_open.open_file(opts.line1, opts.line2, opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '?',
  range = true,
  complete = function(arglead) return git_open.complete_branch(arglead) end,
})

vim.api.nvim_create_user_command('OpenGitCommit', function(opts)
  git_open.open_commit(opts.args ~= '' and opts.args or nil, opts.bang)
end, { bang = true, nargs = '?' })

vim.api.nvim_create_user_command('OpenGitRequest', function(opts)
  git_open.open_request(opts.args, opts.bang)
end, { bang = true, nargs = '?' })

vim.api.nvim_create_user_command('OpenGitFileLastChange', function(opts)
  git_open.open_file_last_change(opts.bang)
end, { bang = true })

vim.api.nvim_create_user_command('OpenGitMyRequests', function(opts)
  git_open.open_my_requests(opts.args ~= '' and opts.args or nil, opts.bang)
end, { bang = true, nargs = '?' })

vim.api.nvim_create_user_command('OpenGitRequests', function(opts)
  git_open.open_requests(opts.args ~= '' and opts.args or nil, opts.bang)
end, { bang = true, nargs = '?' })
