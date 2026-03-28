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
  git_open.open_branch(opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
end, {
  bang = true,
  nargs = '?',
  range = 0,
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
  git_open.open_commit(opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
end, { bang = true, nargs = '?', range = 0 })

vim.api.nvim_create_user_command('OpenGitRequest', function(opts)
  git_open.open_request(opts.args, opts.bang)
end, { bang = true, nargs = '?' })

vim.api.nvim_create_user_command('OpenGitFileLastChange', function(opts)
  git_open.open_file_last_change(opts.bang)
end, { bang = true })

vim.api.nvim_create_user_command('OpenGitMyRequests', function(opts)
  git_open.open_my_requests(opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '?',
  complete = function(arglead) return git_open.complete_my_request_state(arglead) end,
})

vim.api.nvim_create_user_command('OpenGitRequests', function(opts)
  git_open.open_requests(opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '?',
  complete = function(arglead) return git_open.complete_request_state(arglead) end,
})

vim.api.nvim_create_user_command('OpenGitk', function(opts)
  git_open.open_gitk(opts.args ~= '' and opts.args or nil)
end, {
  nargs = '*',
  complete = function(arglead) return git_open.complete_gitk_args(arglead) end,
})

vim.api.nvim_create_user_command('OpenGitkFile', function(opts)
  git_open.open_gitk_file(opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '*',
  complete = function(arglead) return git_open.complete_gitk_branch(arglead) end,
})

vim.api.nvim_create_user_command('Gitk', function(opts)
  git_open.open_gitk(opts.args ~= '' and opts.args or nil)
end, {
  nargs = '*',
  complete = function(arglead) return git_open.complete_gitk_args(arglead) end,
})

vim.api.nvim_create_user_command('GitkFile', function(opts)
  git_open.open_gitk_file(opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '*',
  complete = function(arglead) return git_open.complete_gitk_branch(arglead) end,
})

vim.api.nvim_create_user_command('OpenGitRemote', function(opts)
  git_open.open_git_remote(opts.args ~= '' and opts.args or nil, opts.bang)
end, {
  bang = true,
  nargs = '?',
  complete = function(arglead) return git_open.complete_git_remote(arglead) end,
})

-- Register provider-named commands for each non-origin remote.
-- Deferred to VimEnter so git root and all plugins (e.g. fugitive) are ready.
local function register_multi_remote_commands()
  local remotes = git_open.get_all_remotes()
  if not remotes or #remotes == 0 then
    return
  end

  local provider_remote = {}
  local provider_domain = {}
  local overwritten = {}

  for _, remote_name in ipairs(remotes) do
    local info = git_open.get_repo_info_for_remote(remote_name)
    if info then
      local p = info.provider
      if provider_remote[p] then
        table.insert(overwritten, string.format(
          "git-open: Open%s* now points to remote '%s' (%s) — '%s' (%s) was overwritten",
          p, remote_name, info.domain, provider_remote[p], provider_domain[p]
        ))
      end
      provider_remote[p] = remote_name
      provider_domain[p] = info.domain

      -- Capture remote_name in a local so the closure is correct per iteration.
      local r = remote_name

      if p == 'GitHub' then
        vim.api.nvim_create_user_command('OpenGitHubRepo', function(opts)
          git_open.open_repo_for_remote(r, opts.bang)
        end, { bang = true })

        vim.api.nvim_create_user_command('OpenGitHubBranch', function(opts)
          git_open.open_branch_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
        end, {
          bang = true, nargs = '?', range = 0,
          complete = function(arglead) return git_open.complete_branch(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenGitHubFile', function(opts)
          git_open.open_file_for_remote(r, opts.line1, opts.line2, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?', range = true,
          complete = function(arglead) return git_open.complete_branch(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenGitHubCommit', function(opts)
          git_open.open_commit_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
        end, { bang = true, nargs = '?', range = 0 })

        vim.api.nvim_create_user_command('OpenGitHubPR', function(opts)
          git_open.open_request_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, { bang = true, nargs = '?' })

        vim.api.nvim_create_user_command('OpenGitHubPRs', function(opts)
          git_open.open_requests_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?',
          complete = function(arglead) return git_open.complete_request_state(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenGitHubMyPRs', function(opts)
          git_open.open_my_requests_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?',
          complete = function(arglead) return git_open.complete_my_request_state(arglead) end,
        })

      elseif p == 'GitLab' then
        vim.api.nvim_create_user_command('OpenGitLabRepo', function(opts)
          git_open.open_repo_for_remote(r, opts.bang)
        end, { bang = true })

        vim.api.nvim_create_user_command('OpenGitLabBranch', function(opts)
          git_open.open_branch_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
        end, {
          bang = true, nargs = '?', range = 0,
          complete = function(arglead) return git_open.complete_branch(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenGitLabFile', function(opts)
          git_open.open_file_for_remote(r, opts.line1, opts.line2, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?', range = true,
          complete = function(arglead) return git_open.complete_branch(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenGitLabCommit', function(opts)
          git_open.open_commit_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
        end, { bang = true, nargs = '?', range = 0 })

        vim.api.nvim_create_user_command('OpenGitLabMR', function(opts)
          git_open.open_request_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, { bang = true, nargs = '?' })

        vim.api.nvim_create_user_command('OpenGitLabMRs', function(opts)
          git_open.open_requests_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?',
          complete = function(arglead) return git_open.complete_request_state(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenGitLabMyMRs', function(opts)
          git_open.open_my_requests_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?',
          complete = function(arglead) return git_open.complete_my_request_state(arglead) end,
        })

      elseif p == 'Codeberg' then
        vim.api.nvim_create_user_command('OpenCodebergRepo', function(opts)
          git_open.open_repo_for_remote(r, opts.bang)
        end, { bang = true })

        vim.api.nvim_create_user_command('OpenCodebergBranch', function(opts)
          git_open.open_branch_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
        end, {
          bang = true, nargs = '?', range = 0,
          complete = function(arglead) return git_open.complete_branch(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenCodebergFile', function(opts)
          git_open.open_file_for_remote(r, opts.line1, opts.line2, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?', range = true,
          complete = function(arglead) return git_open.complete_branch(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenCodebergCommit', function(opts)
          git_open.open_commit_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang, opts.count > 0)
        end, { bang = true, nargs = '?', range = 0 })

        vim.api.nvim_create_user_command('OpenCodebergPR', function(opts)
          git_open.open_request_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, { bang = true, nargs = '?' })

        vim.api.nvim_create_user_command('OpenCodebergPRs', function(opts)
          git_open.open_requests_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?',
          complete = function(arglead) return git_open.complete_request_state(arglead) end,
        })

        vim.api.nvim_create_user_command('OpenCodebergMyPRs', function(opts)
          git_open.open_my_requests_for_remote(r, opts.args ~= '' and opts.args or nil, opts.bang)
        end, {
          bang = true, nargs = '?',
          complete = function(arglead) return git_open.complete_my_request_state(arglead) end,
        })
      end
    end
  end

  for _, msg in ipairs(overwritten) do
    vim.api.nvim_echo({{ msg, 'WarningMsg' }}, true, {})
  end
end

vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('git_open_multi_remote', { clear = true }),
  once = true,
  callback = register_multi_remote_commands,
})
