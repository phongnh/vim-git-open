-- git_open.lua - Core functionality (Lua version for Neovim)
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

local M = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function warn(msg)
  vim.api.nvim_echo({{msg, 'ErrorMsg'}}, true, {})
end

local function get_git_root()
  -- Step 1: FugitiveGitDir() — handles all fugitive virtual buffers
  if vim.fn.exists('*FugitiveGitDir') == 1 then
    local fgd = vim.fn.FugitiveGitDir()
    if type(fgd) == 'string' and fgd ~= '' then
      return vim.fn.fnamemodify(fgd, ':h')
    end
  end
  -- Step 2: finddir from the current buffer's directory
  local git_dir = vim.fn.finddir('.git', vim.fn.expand('%:p:h') .. ';')
  if git_dir ~= '' then
    return vim.fn.fnamemodify(git_dir, ':p:h')
  end
  -- Step 3: fallback to cwd — works in terminal/quickfix/empty buffers
  git_dir = vim.fn.finddir('.git', vim.fn.getcwd() .. ';')
  if git_dir ~= '' then
    return vim.fn.fnamemodify(git_dir, ':p:h')
  end
  return nil
end

local function git_command(args)
  local git_root = get_git_root()
  if not git_root then
    return nil
  end
  
  local cmd = string.format('git -C %s %s', vim.fn.shellescape(git_root), args)
  local output = vim.fn.system(cmd)
  return vim.trim(output)
end

local function parse_remote_url()
  local remote = git_command('config --get remote.origin.url')
  if not remote or remote == '' then
    return nil
  end
  
  -- Handle SSH URLs: git@github.com:user/repo.git
  local domain, path = remote:match('^git@([^:]+):(.*)%.git$')
  if domain and path then
    return { domain = domain, path = path }
  end
  
  -- Handle SSH URLs: ssh://git@github.com/user/repo.git
  domain, path = remote:match('^ssh://git@([^/]+)/(.*)%.git$')
  if domain and path then
    return { domain = domain, path = path }
  end
  
  -- Handle HTTPS URLs: https://github.com/user/repo.git
  domain, path = remote:match('^https?://([^/]+)/(.*)$')
  if domain and path then
    path = path:gsub('%.git$', '')
    return { domain = domain, path = path }
  end
  
  return nil
end

local function detect_provider(domain)
  -- Check user-defined providers first
  local providers = vim.g.vim_git_open_providers or {}
  if providers[domain] then
    return providers[domain]
  end
  
  -- Auto-detect known providers
  if domain:match('github%.com') then
    return 'GitHub'
  elseif domain:match('gitlab%.com') then
    return 'GitLab'
  elseif domain:match('codeberg%.org') then
    return 'Codeberg'
  end
  
  -- Default to GitHub
  return 'GitHub'
end

local function get_base_url(domain)
  -- Check user-defined domain mappings
  local domains = vim.g.vim_git_open_domains or {}
  if domains[domain] then
    local mapped_url = domains[domain]
    -- Add https:// if no protocol specified
    if not mapped_url:match('^https?://') then
      return 'https://' .. mapped_url
    end
    return mapped_url
  end
  
  -- Default to https://domain
  return 'https://' .. domain
end

local function get_current_branch()
  return git_command('rev-parse --abbrev-ref HEAD')
end

local function get_current_commit()
  return git_command('rev-parse HEAD')
end

local function get_relative_path()
  local git_root = get_git_root()
  if not git_root then
    return nil
  end
  
  local abs_path = vim.fn.expand('%:p')
  
  -- Ensure git_root ends with /
  if not git_root:match('/$') then
    git_root = git_root .. '/'
  end
  
  -- Check if abs_path starts with git_root
  if abs_path:sub(1, #git_root) == git_root then
    return abs_path:sub(#git_root + 1)
  end
  
  -- Fallback: try original method
  local rel_path = abs_path:gsub('^' .. vim.pesc(git_root), '')
  return rel_path
end

local function get_line_range(line1, line2)
  if line1 == line2 then
    return tostring(line1)
  else
    return line1 .. '-' .. line2
  end
end

local function format_line_anchor(provider, line_info)
  if not line_info or line_info == '' then
    return ''
  end
  
  if provider == 'GitLab' then
    -- GitLab uses #L10 or #L10-20
    if line_info:match('-') then
      return '#L' .. line_info
    else
      return '#L' .. line_info
    end
  else
    -- GitHub/Codeberg use #L10 or #L10-L20
    if line_info:match('-') then
      local parts = vim.split(line_info, '-')
      return '#L' .. parts[1] .. '-L' .. parts[2]
    else
      return '#L' .. line_info
    end
  end
end

-- Parse PR/MR number from a given message
local function parse_pr_mr_number(message, provider)
  if not message then
    return nil
  end
  
  local pattern
  if provider == 'GitLab' then
    -- GitLab uses !1234
    pattern = '!(%d+)'
  else
    -- GitHub/Codeberg use #1234
    pattern = '#(%d+)'
  end
  
  local number = message:match(pattern)
  return number
end

local function parse_pr_mr_from_commit(provider)
  local commit_msg = git_command('log -1 --pretty=%B')
  return parse_pr_mr_number(commit_msg, provider)
end

local function get_gitlab_username()
  local cfg = vim.g.vim_git_open_gitlab_username
  if cfg and cfg ~= '' then
    return cfg
  end
  local gitlab_user = vim.fn.getenv('GITLAB_USER')
  if gitlab_user ~= vim.NIL and gitlab_user ~= '' then
    return gitlab_user
  end
  local glab_user = vim.fn.getenv('GLAB_USER')
  if glab_user ~= vim.NIL and glab_user ~= '' then
    return glab_user
  end
  return vim.fn.expand('$USER')
end

-- Parse state flag from command args: -open, -closed, -merged, -all
-- Returns the query string suffix to append to the pulls/MRs URL.
-- GitHub:   uses ?q=is%3Apr+is%3A<state> search query
-- Codeberg: uses ?state=<state> param (Gitea-based, no merged state)
-- GitLab:   uses ?state=<state> param (opened/merged/closed/all)
local function parse_request_state(args, provider)
  local arg = vim.trim(args or ''):lower()
  if provider == 'GitLab' then
    if arg == '-merged' then
      return '?state=merged'
    elseif arg == '-closed' then
      return '?state=closed'
    elseif arg == '-all' then
      return '?state=all'
    end
  elseif provider == 'Codeberg' then
    if arg == '-closed' or arg == '-merged' then
      return '?state=closed'
    elseif arg == '-all' then
      return '?state=all'
    end
  else
    -- GitHub
    if arg == '-closed' or arg == '-merged' then
      return '?q=is%3Apr+is%3Aclosed'
    elseif arg == '-all' then
      return '?q=is%3Apr'
    end
  end
  return ''
end

-- ============================================================================
-- URL Builders
-- ============================================================================

local function build_github_url(base_url, path, url_type, extra, line_info, ref)
  local url = base_url .. '/' .. path
  
  if url_type == 'repo' then
    return url
  elseif url_type == 'branch' then
    local branch = extra or get_current_branch()
    return url .. '/tree/' .. branch
  elseif url_type == 'file' then
    local file = extra or get_relative_path()
    -- ref is an optional branch/commit; fall back to HEAD commit
    local commit = (ref and ref ~= '') and ref or get_current_commit()
    local file_url = url .. '/blob/' .. commit .. '/' .. file
    
    -- Add line number anchor if provided
    if line_info and line_info ~= '' then
      file_url = file_url .. format_line_anchor('GitHub', line_info)
    end
    
    return file_url
  elseif url_type == 'commit' then
    local commit = extra or get_current_commit()
    return url .. '/commit/' .. commit
  elseif url_type == 'pr' then
    if not extra or extra == '' then
      warn('No PR number specified')
      return nil
    end
    return url .. '/pull/' .. extra
  end
  
  return url
end

local function build_gitlab_url(base_url, path, url_type, extra, line_info, ref)
  local url = base_url .. '/' .. path
  
  if url_type == 'repo' then
    return url
  elseif url_type == 'branch' then
    local branch = extra or get_current_branch()
    return url .. '/-/tree/' .. branch
  elseif url_type == 'file' then
    local file = extra or get_relative_path()
    -- ref is an optional branch/commit; fall back to HEAD commit
    local commit = (ref and ref ~= '') and ref or get_current_commit()
    local file_url = url .. '/-/blob/' .. commit .. '/' .. file
    
    -- Add line number anchor if provided
    if line_info and line_info ~= '' then
      file_url = file_url .. format_line_anchor('GitLab', line_info)
    end
    
    return file_url
  elseif url_type == 'commit' then
    local commit = extra or get_current_commit()
    return url .. '/-/commit/' .. commit
  elseif url_type == 'mr' then
    if not extra or extra == '' then
      warn('No MR number specified')
      return nil
    end
    return url .. '/-/merge_requests/' .. extra
  end
  
  return url
end

local function build_url(provider, base_url, path, url_type, extra, line_info, ref)
  if provider == 'GitLab' then
    return build_gitlab_url(base_url, path, url_type, extra, line_info, ref)
  else
    -- Default to GitHub (includes Codeberg)
    return build_github_url(base_url, path, url_type, extra, line_info, ref)
  end
end

-- ============================================================================
-- Browser Functions
-- ============================================================================

local function open_browser(url)
  if not url or url == '' then
    return
  end
  
  local browser_cmd = vim.g.vim_git_open_browser_command
  if not browser_cmd or browser_cmd == '' then
    warn('No browser command configured. Set g:vim_git_open_browser_command')
    return
  end
  
  local cmd
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    cmd = string.format('start "" %s', vim.fn.shellescape(url))
  else
    cmd = string.format('%s %s > /dev/null 2>&1', browser_cmd, vim.fn.shellescape(url))
  end

  vim.fn.system(cmd)
  vim.cmd('redraw')
  print('Opened: ' .. url)
end

local function copy_to_clipboard(url)
  if not url or url == '' then
    return
  end

  vim.fn.setreg('+', url)
  vim.fn.setreg('*', url)
  vim.cmd('redraw')
  print('Copied: ' .. url)
end

local function open_or_copy(url, copy)
  if copy then
    copy_to_clipboard(url)
  else
    open_browser(url)
  end
end

local function get_repo_info()
  local remote = parse_remote_url()
  if not remote then
    warn('Not a git repository or no remote configured')
    return nil
  end
  
  local provider = detect_provider(remote.domain)
  local base_url = get_base_url(remote.domain)
  
  return {
    domain = remote.domain,
    path = remote.path,
    provider = provider,
    base_url = base_url
  }
end

local function get_visual_selection()
  if vim.fn.exists('*getregion') == 1 then
    local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"))
    return vim.trim(table.concat(lines, '\n'))
  end
  local line = vim.fn.getline("'<")
  local _, _, c1 = unpack(vim.fn.getpos("'<"))
  local _, l2, c2 = unpack(vim.fn.getpos("'>"))
  local _, l1 = unpack(vim.fn.getpos("'<"))
  if l1 ~= l2 then
    return vim.trim(line:sub(c1))
  end
  return vim.trim(line:sub(c1, c2))
end

-- ============================================================================
-- Completion Functions
-- ============================================================================

local function unique(items)
  local seen = {}
  local result = {}
  for _, item in ipairs(items) do
    if not seen[item] then
      seen[item] = true
      table.insert(result, item)
    end
  end
  return result
end

local function fuzzy_filter(result, arglead)
  if not arglead or arglead == '' then
    return result
  end
  return vim.fn.matchfuzzy(result, arglead)
end

-- ============================================================================
-- Gitk Helper Functions
-- ============================================================================

local function launch_gitk(args, git_root)
  if vim.fn.executable('gitk') == 0 then
    warn('git-open: gitk not found in PATH')
    return
  end
  local cmd = { 'gitk' }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end
  vim.fn.jobstart(cmd, { cwd = git_root, detach = true })
end

local function get_gitk_old_paths(rel_path, git_root)
  local cmd = string.format(
    'git -C %s log --follow --name-only --format= -- %s',
    vim.fn.shellescape(git_root),
    vim.fn.shellescape(rel_path)
  )
  local output = vim.trim(vim.fn.system(cmd))
  if output == '' then
    return { rel_path }
  end
  local seen = {}
  local paths = {}
  for _, p in ipairs(vim.split(output, '\n', { plain = true, trimempty = true })) do
    if not seen[p] then
      seen[p] = true
      table.insert(paths, p)
    end
  end
  return #paths > 0 and paths or { rel_path }
end

function M.complete_branch(arglead)
  -- Local branches sorted by most recent commit (-committerdate)
  local local_raw = git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
  -- Remote branches sorted by most recent commit, strip refs/remotes/<remote>/
  local remote_raw = git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/")
  local local_branches = (local_raw and local_raw ~= '')
    and vim.split(local_raw, '\n', { plain = true, trimempty = true }) or {}
  local remote_branches = (remote_raw and remote_raw ~= '')
    and vim.tbl_filter(function(b) return b ~= 'HEAD' end,
        vim.split(remote_raw, '\n', { plain = true, trimempty = true })) or {}
  local combined = vim.list_extend(vim.list_extend({}, local_branches), remote_branches)
  return fuzzy_filter(unique(combined), arglead)
end

function M.complete_gitk_branch(arglead)
  -- Local branches (plain name), then remote branches with full remote/ prefix
  local local_raw = git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
  local remote_raw = git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/remotes/")
  local local_branches = (local_raw and local_raw ~= '')
    and vim.split(local_raw, '\n', { plain = true, trimempty = true }) or {}
  local remote_branches = (remote_raw and remote_raw ~= '')
    and vim.tbl_filter(function(b) return not b:match('/HEAD$') end,
        vim.split(remote_raw, '\n', { plain = true, trimempty = true })) or {}
  local combined = vim.list_extend(vim.list_extend({}, local_branches), remote_branches)
  return fuzzy_filter(unique(combined), arglead)
end

function M.complete_gitk_args(arglead)
  -- Branches (local plain + remote with prefix) then tracked files
  local branches = M.complete_gitk_branch('')
  local files_raw = git_command('ls-files')
  local files = (files_raw and files_raw ~= '')
    and vim.split(files_raw, '\n', { plain = true, trimempty = true }) or {}
  local combined = vim.list_extend(vim.list_extend({}, branches), files)
  return fuzzy_filter(unique(combined), arglead)
end

function M.complete_request_state(arglead)
  return fuzzy_filter({ '-open', '-closed', '-merged', '-all' }, arglead)
end

function M.complete_my_request_state(arglead)
  return fuzzy_filter({ '-open', '-closed', '-merged', '-all',
    '-search', '-search=open', '-search=closed', '-search=merged', '-search=all' }, arglead)
end

-- ============================================================================
-- Public API Functions
-- ============================================================================

function M.open_repo(copy)
  local info = get_repo_info()
  if not info then
    return
  end
  
  local url = build_url(info.provider, info.base_url, info.path, 'repo')
  open_or_copy(url, copy)
end

function M.open_branch(branch, copy, visual)
  local info = get_repo_info()
  if not info then
    return
  end

  local ref = branch
  if (not ref or ref == '') and visual then
    ref = get_visual_selection()
  end

  local url = build_url(info.provider, info.base_url, info.path, 'branch', ref)
  open_or_copy(url, copy)
end

function M.open_file(line1, line2, ref, copy)
  local info = get_repo_info()
  if not info then
    return
  end

  if vim.fn.expand('%') == '' then
    warn('No file in current buffer')
    return
  end

  local line_range = get_line_range(line1, line2)

  -- extra=nil (use current file), line_info=line_range, ref=branch/commit
  local url = build_url(info.provider, info.base_url, info.path, 'file', nil, line_range, ref)
  open_or_copy(url, copy)
end

function M.open_commit(commit, copy, visual)
  local info = get_repo_info()
  if not info then
    return
  end

  local ref = commit
  if (not ref or ref == '') and visual then
    ref = get_visual_selection()
  end

  local url = build_url(info.provider, info.base_url, info.path, 'commit', ref)
  open_or_copy(url, copy)
end

function M.open_request(number, copy)
  local info = get_repo_info()
  if not info then
    return
  end

  local req = number
  if not req or req == '' then
    req = parse_pr_mr_from_commit(info.provider)
  end

  if not req or req == '' then
    warn('No request number specified and could not parse from commit message')
    return
  end

  local type = info.provider == 'GitLab' and 'mr' or 'pr'
  local url = build_url(info.provider, info.base_url, info.path, type, req)
  open_or_copy(url, copy)
end

function M.open_file_last_change(copy)
  local info = get_repo_info()
  if not info then
    return
  end
  
  -- Get the file path relative to git root
  local file_path = get_relative_path()
  if not file_path then
    warn('Current file is not in a git repository')
    return
  end
  
  -- Get the latest commit hash for this file
  local commit = git_command('log -1 --format=%H -- ' .. vim.fn.shellescape(file_path))
  if not commit or commit == '' then
    warn('No commits found for current file')
    return
  end
  
  -- Get the commit message
  local message = git_command('log -1 --format=%B ' .. commit)
  
  -- Try to parse PR/MR number from commit message
  local pr_mr_number = parse_pr_mr_number(message, info.provider)
  
  local url
  if pr_mr_number then
    -- Open PR or MR if found
    if info.provider == 'GitLab' then
      url = build_url(info.provider, info.base_url, info.path, 'mr', pr_mr_number)
    else
      url = build_url(info.provider, info.base_url, info.path, 'pr', pr_mr_number)
    end
  else
    -- Otherwise, open the commit
    url = build_url(info.provider, info.base_url, info.path, 'commit', commit)
  end
  
  open_or_copy(url, copy)
end

function M.open_my_requests(state_arg, copy)
  local info = get_repo_info()
  if not info then
    return
  end

  local state = parse_request_state(state_arg, info.provider)
  local url
  if info.provider == 'GitLab' then
    local arg = vim.trim(state_arg or ''):lower()
    -- Check for -search or -search=<state>
    if arg:match('^%-search') then
      local search_state = arg:match('^%-search=(.+)$') or ''
      local search_url = info.base_url .. '/dashboard/merge_requests/search?author_username=' .. get_gitlab_username()
      if search_state == 'closed' or search_state == 'merged' then
        search_url = search_url .. '&state=' .. search_state
      elseif search_state == 'all' then
        search_url = search_url .. '&state=all'
      end
      url = search_url
    elseif arg == '-closed' or arg == '-merged' then
      url = info.base_url .. '/dashboard/merge_requests/merged'
    else
      -- no flag / -open / -all: use the default dashboard page
      url = info.base_url .. '/dashboard/merge_requests'
    end
  elseif info.provider == 'GitHub' then
    -- No flag/-open: /pulls is already scoped to current user when logged in
    -- With state flag: append author:@me to keep scoped to current user
    url = info.base_url .. '/pulls' .. (state ~= '' and (state .. '+author%3A%40me') or '')
  else
    -- Codeberg: state is already a full query string or empty
    url = info.base_url .. '/pulls' .. state
  end

  open_or_copy(url, copy)
end

function M.open_requests(state_arg, copy)
  local info = get_repo_info()
  if not info then
    return
  end

  local state = parse_request_state(state_arg, info.provider)
  local repo_url = info.base_url .. '/' .. info.path
  local url
  if info.provider == 'GitLab' then
    url = repo_url .. '/-/merge_requests' .. state
  else
    -- GitHub and Codeberg: state is already a full query string or empty
    url = repo_url .. '/pulls' .. state
  end

  open_or_copy(url, copy)
end

function M.open_gitk(args_str)
  local git_root = get_git_root()
  if not git_root then
    warn('git-open: not a git repository')
    return
  end
  local args = (args_str and args_str ~= '') and vim.split(args_str, '%s+') or {}
  launch_gitk(args, git_root)
end

function M.open_gitk_file(opts_str, history)
  local git_root = get_git_root()
  if not git_root then
    warn('git-open: not a git repository')
    return
  end
  if vim.fn.expand('%') == '' then
    warn('git-open: no file in current buffer')
    return
  end
  local rel_path = get_relative_path()
  local paths = history and get_gitk_old_paths(rel_path, git_root) or { rel_path }
  local extra_args = (opts_str and opts_str ~= '') and vim.split(opts_str, '%s+') or {}
  local args = {}
  for _, a in ipairs(extra_args) do table.insert(args, a) end
  table.insert(args, '--')
  for _, p in ipairs(paths) do table.insert(args, p) end
  launch_gitk(args, git_root)
end

function M.setup(opts)
  opts = opts or {}
  
  -- Set default configurations
  if opts.domains then
    vim.g.vim_git_open_domains = opts.domains
  end
  
  if opts.providers then
    vim.g.vim_git_open_providers = opts.providers
  end
  
  if opts.browser_command then
    vim.g.vim_git_open_browser_command = opts.browser_command
  elseif not vim.g.vim_git_open_browser_command then
    -- Check for $BROWSER environment variable first
    local browser_env = vim.fn.getenv('BROWSER')
    if browser_env and browser_env ~= vim.NIL and browser_env ~= '' then
      vim.g.vim_git_open_browser_command = browser_env
    elseif vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
      vim.g.vim_git_open_browser_command = 'open'
    elseif vim.fn.has('unix') == 1 then
      vim.g.vim_git_open_browser_command = 'xdg-open'
    elseif vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
      vim.g.vim_git_open_browser_command = 'start'
    else
      vim.g.vim_git_open_browser_command = ''
    end
  end
end

return M
