-- git_open.lua - Core functionality (Lua version for Neovim)
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

local M = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function get_git_root()
  local git_dir = vim.fn.finddir('.git', vim.fn.expand('%:p:h') .. ';')
  if git_dir == '' then
    return nil
  end
  return vim.fn.fnamemodify(git_dir, ':h')
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
  local rel_path = abs_path:gsub('^' .. vim.pesc(git_root) .. '/', '')
  return rel_path
end

local function get_line_range()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Visual mode - get range
    local line_start = vim.fn.line("'<")
    local line_end = vim.fn.line("'>")
    if line_start == line_end then
      return tostring(line_start)
    else
      return line_start .. '-' .. line_end
    end
  else
    -- Normal mode - get current line
    return tostring(vim.fn.line('.'))
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

-- ============================================================================
-- URL Builders
-- ============================================================================

local function build_github_url(base_url, path, url_type, extra, line_info)
  local url = base_url .. '/' .. path
  
  if url_type == 'repo' then
    return url
  elseif url_type == 'branch' then
    local branch = extra or get_current_branch()
    return url .. '/tree/' .. branch
  elseif url_type == 'file' then
    local file = extra or get_relative_path()
    local commit = get_current_commit()
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
      vim.api.nvim_err_writeln('No PR number specified')
      return nil
    end
    return url .. '/pull/' .. extra
  end
  
  return url
end

local function build_gitlab_url(base_url, path, url_type, extra, line_info)
  local url = base_url .. '/' .. path
  
  if url_type == 'repo' then
    return url
  elseif url_type == 'branch' then
    local branch = extra or get_current_branch()
    return url .. '/-/tree/' .. branch
  elseif url_type == 'file' then
    local file = extra or get_relative_path()
    local commit = get_current_commit()
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
      vim.api.nvim_err_writeln('No MR number specified')
      return nil
    end
    return url .. '/-/merge_requests/' .. extra
  end
  
  return url
end

local function build_url(provider, base_url, path, url_type, extra, line_info)
  if provider == 'GitLab' then
    return build_gitlab_url(base_url, path, url_type, extra, line_info)
  else
    -- Default to GitHub (includes Codeberg)
    return build_github_url(base_url, path, url_type, extra, line_info)
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
    vim.api.nvim_err_writeln('No browser command configured. Set g:vim_git_open_browser_command')
    return
  end
  
  local cmd
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    cmd = string.format('start "" %s', vim.fn.shellescape(url))
  else
    cmd = string.format('%s %s', browser_cmd, vim.fn.shellescape(url))
  end
  
  vim.fn.system(cmd)
  print('Opened: ' .. url)
end

local function get_repo_info()
  local remote = parse_remote_url()
  if not remote then
    vim.api.nvim_err_writeln('Not a git repository or no remote configured')
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

-- ============================================================================
-- Public API Functions
-- ============================================================================

function M.open_repo()
  local info = get_repo_info()
  if not info then
    return
  end
  
  local url = build_url(info.provider, info.base_url, info.path, 'repo')
  open_browser(url)
end

function M.open_branch()
  local info = get_repo_info()
  if not info then
    return
  end
  
  local url = build_url(info.provider, info.base_url, info.path, 'branch')
  open_browser(url)
end

function M.open_file()
  local info = get_repo_info()
  if not info then
    return
  end
  
  if vim.fn.expand('%') == '' then
    vim.api.nvim_err_writeln('No file in current buffer')
    return
  end
  
  -- Get line range (supports visual selection)
  local line_range = get_line_range()
  
  local url = build_url(info.provider, info.base_url, info.path, 'file', nil, line_range)
  open_browser(url)
end

function M.open_commit()
  local info = get_repo_info()
  if not info then
    return
  end
  
  local url = build_url(info.provider, info.base_url, info.path, 'commit')
  open_browser(url)
end

function M.open_pr(pr_number)
  local info = get_repo_info()
  if not info then
    return
  end
  
  local pr = pr_number
  if not pr or pr == '' then
    pr = parse_pr_mr_from_commit(info.provider)
  end
  
  if not pr or pr == '' then
    vim.api.nvim_err_writeln('No PR number specified and could not parse from commit message')
    return
  end
  
  local url = build_url(info.provider, info.base_url, info.path, 'pr', pr)
  open_browser(url)
end

function M.open_mr(mr_number)
  local info = get_repo_info()
  if not info then
    return
  end
  
  local mr = mr_number
  if not mr or mr == '' then
    mr = parse_pr_mr_from_commit(info.provider)
  end
  
  if not mr or mr == '' then
    vim.api.nvim_err_writeln('No MR number specified and could not parse from commit message')
    return
  end
  
  local url = build_url(info.provider, info.base_url, info.path, 'mr', mr)
  open_browser(url)
end

function M.open_file_last_change()
  local info = get_repo_info()
  if not info then
    return
  end
  
  -- Get the file path relative to git root
  local file_path = get_relative_path()
  if not file_path then
    vim.api.nvim_echo({{'Current file is not in a git repository', 'ErrorMsg'}}, true, {})
    return
  end
  
  -- Get the latest commit hash for this file
  local commit = git_command('log -1 --format=%H -- ' .. vim.fn.shellescape(file_path))
  if not commit or commit == '' then
    vim.api.nvim_echo({{'No commits found for current file', 'ErrorMsg'}}, true, {})
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
  
  open_browser(url)
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
