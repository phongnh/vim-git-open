-- git_open.lua - Core functionality (Lua version for Neovim)
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

local M = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local unpack = table.unpack or unpack

local function warn(msg)
  vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
end

local function get_git_root()
  -- Step 1: FugitiveGitDir() — handles all fugitive virtual buffers
  if vim.fn.exists("*FugitiveGitDir") == 1 then
    local fgd = vim.fn.FugitiveGitDir()
    if type(fgd) == "string" and fgd ~= "" then
      return vim.fn.fnamemodify(fgd, ":h")
    end
  end
  -- Step 2: finddir from the current buffer's directory
  local git_dir = vim.fn.finddir(".git", vim.fn.expand("%:p:h") .. ";")
  if git_dir ~= "" then
    return vim.fn.fnamemodify(git_dir, ":p:h")
  end
  -- Step 3: fallback to cwd — works in terminal/quickfix/empty buffers
  git_dir = vim.fn.finddir(".git", vim.fn.getcwd() .. ";")
  if git_dir ~= "" then
    return vim.fn.fnamemodify(git_dir, ":p:h")
  end
  return nil
end

local function system(cmd, opts)
  local result = vim.system(cmd, vim.list_extend(opts or {}, { text = true })):wait()
  return result.code == 0 and vim.trim(result.stdout) or ""
end

local function git_command(args)
  local git_root = get_git_root()
  if not git_root then
    return nil
  end
  return system({ "git", "-C", git_root, unpack(args or {}) })
end

local function get_all_remote_names(git_root)
  local output = system({ "git", "-C", git_root, "remote" })
  if output == "" then
    return {}
  end
  local names = {}
  for _, name in ipairs(vim.split(output, "\n", { plain = true, trimempty = true })) do
    table.insert(names, name)
  end
  return names
end

local function get_current_remote(git_root)
  -- Step 1: already resolved for this buffer
  local cached = vim.b.vim_git_open_remote
  if cached and cached ~= "" then
    return cached
  end

  local remotes = get_all_remote_names(git_root)
  if #remotes == 0 then
    return nil
  end

  -- Step 2: honour vim.g.vim_git_open_remote if valid
  local pref = vim.g.vim_git_open_remote
  if pref and pref ~= "" then
    for _, r in ipairs(remotes) do
      if r == pref then
        vim.b.vim_git_open_remote = pref
        return pref
      end
    end
    -- pref not in remotes — warn once per buffer then fall through
    if not vim.b.vim_git_open_remote_warned then
      warn("git-open: remote '" .. pref .. "' not found, falling back")
      vim.b.vim_git_open_remote_warned = 1
    end
  end

  -- Step 3: prefer "origin"
  for _, r in ipairs(remotes) do
    if r == "origin" then
      vim.b.vim_git_open_remote = "origin"
      return "origin"
    end
  end

  -- Step 4: first available remote
  vim.b.vim_git_open_remote = remotes[1]
  return remotes[1]
end

-- Parse a raw remote URL string into { domain, path }
local function parse_remote_url_string(remote)
  -- Handle SSH URLs: git@github.com:user/repo.git
  local domain, path = remote:match("^git@([^:]+):(.*)%.git$")
  if domain and path then
    return { domain = domain, path = path }
  end

  -- Handle SSH URLs: ssh://git@github.com/user/repo.git
  domain, path = remote:match("^ssh://git@([^/]+)/(.*)%.git$")
  if domain and path then
    return { domain = domain, path = path }
  end

  -- Handle HTTPS URLs: https://github.com/user/repo.git or without .git
  domain, path = remote:match("^https?://([^/]+)/(.*)$")
  if domain and path then
    path = path:gsub("%.git$", "")
    return { domain = domain, path = path }
  end

  return nil
end

-- parse_remote_url: uses per-buffer remote resolution (get_current_remote)
local function parse_remote_url()
  local git_root = get_git_root()
  local remote_name = git_root and get_current_remote(git_root) or nil
  if not remote_name or remote_name == "" then
    return nil
  end
  local remote = git_command({ "config", "--get", "remote." .. remote_name .. ".url" })
  if not remote or remote == "" then
    return nil
  end
  return parse_remote_url_string(remote)
end

-- parse_remote_url_for_name: bypasses per-buffer resolution
local function parse_remote_url_for_name(remote_name)
  local remote = git_command({ "config", "--get", "remote." .. remote_name .. ".url" })
  if not remote or remote == "" then
    return nil
  end
  return parse_remote_url_string(remote)
end

local function detect_provider(domain)
  -- Check user-defined providers first
  local providers = vim.g.vim_git_open_providers or {}
  if providers[domain] then
    return providers[domain]
  end

  -- Auto-detect known providers
  if domain:match("github%.com") then
    return "GitHub"
  elseif domain:match("gitlab%.com") then
    return "GitLab"
  elseif domain:match("codeberg%.org") then
    return "Codeberg"
  end

  -- Default to GitHub
  return "GitHub"
end

local function get_base_url(domain)
  -- Check user-defined domain mappings
  local domains = vim.g.vim_git_open_domains or {}
  if domains[domain] then
    local mapped_url = domains[domain]
    -- Add https:// if no protocol specified
    if not mapped_url:match("^https?://") then
      return "https://" .. mapped_url
    end
    return mapped_url
  end

  -- Default to https://domain
  return "https://" .. domain
end

local function get_current_branch()
  return git_command({ "rev-parse", "--abbrev-ref", "HEAD" })
end

local function get_current_commit()
  return git_command({ "rev-parse", "HEAD" })
end

local function get_relative_path()
  local git_root = get_git_root()
  if not git_root then
    return nil
  end

  local abs_path = vim.fn.expand("%:p")

  -- Ensure git_root ends with /
  if not git_root:match("/$") then
    git_root = git_root .. "/"
  end

  return abs_path:sub(#git_root + 1)
end

local function get_line_range(line1, line2)
  if line1 == line2 then
    return tostring(line1)
  else
    return line1 .. "-" .. line2
  end
end

local function get_repo_info_from_remote(remote)
  local provider = detect_provider(remote.domain)
  local base_url = get_base_url(remote.domain)
  return {
    domain = remote.domain,
    path = remote.path,
    provider = provider,
    base_url = base_url,
  }
end

local function get_repo_info()
  local remote = parse_remote_url()
  if not remote then
    warn("Not a git repository or no remote configured")
    return nil
  end
  return get_repo_info_from_remote(remote)
end

local function get_all_remotes()
  local output = git_command({ "remote" })
  if not output or output == "" then
    return {}
  end
  local result = {}
  for _, name in ipairs(vim.split(output, "\n", { plain = true, trimempty = true })) do
    if name ~= "origin" then
      table.insert(result, name)
    end
  end
  return result
end

local function get_repo_info_for_remote(remote_name)
  local remote = parse_remote_url_for_name(remote_name)
  if not remote then
    return nil
  end
  return get_repo_info_from_remote(remote)
end

local function get_visual_selection()
  if vim.fn.exists("*getregion") == 1 then
    local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"))
    return vim.trim(table.concat(lines, "\n"))
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
-- Provider Dispatch
--
-- Provider modules live in lua/git_open/{github,gitlab,codeberg}.lua.
-- Each module exports the full provider interface:
--   parse_request_number(message)
--   build_repo_url(repo_info)
--   build_branch_url(repo_info, branch)
--   build_file_url(repo_info, file, line_info, ref)
--   build_commit_url(repo_info, commit)
--   build_request_url(repo_info, number)
--   build_requests_url(repo_info, state_arg)
--   build_my_requests_url(repo_info, state_arg)
-- ============================================================================

local providers = {}

local function get_provider(provider)
  if not providers[provider] then
    local mod_name = provider:lower()
    providers[provider] = require("git_open." .. mod_name)
  end
  return providers[provider]
end

local function call_provider(provider, func, ...)
  return get_provider(provider)[func](...)
end

local function parse_request_number_from_commit(provider)
  local msg = git_command({ "log", "-1", "--pretty=%B" })
  return call_provider(provider, "parse_request_number", msg)
end

-- ============================================================================
-- Browser Functions
-- ============================================================================

local function open_browser(url)
  if not url or url == "" then
    return
  end

  local browser_cmd = vim.g.vim_git_open_browser_command
  if not browser_cmd or browser_cmd == "" then
    warn("No browser command configured. Set g:vim_git_open_browser_command")
    return
  end

  local cmd
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    cmd = string.format('start "" %s', vim.fn.shellescape(url))
  else
    cmd = string.format("%s %s > /dev/null 2>&1", browser_cmd, vim.fn.shellescape(url))
  end

  system({ "sh", "-c", cmd })
  vim.cmd("redraw!")
  print("Opened: " .. url)
end

local function copy_to_clipboard(url)
  if not url or url == "" then
    return
  end

  vim.fn.setreg("+", url)
  vim.fn.setreg("*", url)
  vim.cmd("redraw!")
  print("Copied: " .. url)
end

local function open_or_copy(url, copy)
  if copy then
    copy_to_clipboard(url)
  else
    open_browser(url)
  end
end

-- ============================================================================
-- Completion Helpers
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
  if not arglead or arglead == "" then
    return result
  end
  return vim.fn.matchfuzzy(result, arglead)
end

-- ============================================================================
-- Gitk Helper Functions
-- ============================================================================

local function launch_gitk(args, git_root)
  if vim.fn.executable("gitk") == 0 then
    warn("git-open: gitk not found in PATH")
    return
  end
  local cmd = { "gitk" }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end
  vim.fn.jobstart(cmd, { cwd = git_root, detach = true })
end

local function get_gitk_old_paths(rel_path, git_root)
  local output = system({ "git", "-C", git_root, "log", "--follow", "--name-only", "--format=", "--", rel_path })
  if output == "" then
    return { rel_path }
  end
  local paths = unique(vim.split(output, "\n", { plain = true, trimempty = true }))
  return #paths > 0 and paths or { rel_path }
end

-- ============================================================================
-- Completion Functions
-- ============================================================================

function M.open_browser(url)
  open_browser(url)
end

function M.complete_branch(arglead)
  -- Local branches sorted by most recent commit (-committerdate)
  local local_raw =
    git_command({ "for-each-ref", "--sort=-committerdate", "--format='%(refname:lstrip=2)'", "refs/heads/" })
  -- Remote branches sorted by most recent commit, strip refs/remotes/<remote>/
  local remote_raw =
    git_command({ "for-each-ref", "--sort=-committerdate", "--format='%(refname:lstrip=3)'", "refs/remotes/" })
  local local_branches = (local_raw and local_raw ~= "")
      and vim.split(local_raw, "\n", { plain = true, trimempty = true })
    or {}
  local remote_branches = (remote_raw and remote_raw ~= "")
      and vim.tbl_filter(function(b)
        return b ~= "HEAD"
      end, vim.split(remote_raw, "\n", { plain = true, trimempty = true }))
    or {}
  local combined = vim.list_extend(vim.list_extend({}, local_branches), remote_branches)
  return fuzzy_filter(unique(combined), arglead)
end

function M.complete_gitk_branch(arglead)
  -- Local branches (plain name), then remote branches with full remote/ prefix
  local local_raw =
    git_command({ "for-each-ref", "--sort=-committerdate", "--format='%(refname:lstrip=2)'", "refs/heads/" })
  local remote_raw =
    git_command({ "for-each-ref", "--sort=-committerdate", "--format='%(refname:lstrip=2)'", "refs/remotes/" })
  local local_branches = (local_raw and local_raw ~= "")
      and vim.split(local_raw, "\n", { plain = true, trimempty = true })
    or {}
  local remote_branches = (remote_raw and remote_raw ~= "")
      and vim.tbl_filter(function(b)
        return not b:match("/HEAD$")
      end, vim.split(remote_raw, "\n", { plain = true, trimempty = true }))
    or {}
  local combined = vim.list_extend(vim.list_extend({}, local_branches), remote_branches)
  return fuzzy_filter(unique(combined), arglead)
end

function M.complete_gitk_args(arglead)
  -- Branches (local plain + remote with prefix) then tracked files
  local branches = M.complete_gitk_branch("")
  local files_raw = git_command({ "ls-files" })
  local files = (files_raw and files_raw ~= "") and vim.split(files_raw, "\n", { plain = true, trimempty = true }) or {}
  local combined = vim.list_extend(vim.list_extend({}, branches), files)
  return fuzzy_filter(unique(combined), arglead)
end

function M.complete_request_state(arglead)
  return fuzzy_filter({ "-open", "-closed", "-merged", "-all" }, arglead)
end

function M.complete_my_request_state(arglead)
  return fuzzy_filter({
    "-open",
    "-closed",
    "-merged",
    "-all",
    "-search",
    "-search=open",
    "-search=closed",
    "-search=merged",
    "-search=all",
  }, arglead)
end

function M.complete_git_remote(arglead)
  local git_root = get_git_root()
  if not git_root then
    return {}
  end
  return fuzzy_filter(get_all_remote_names(git_root), arglead)
end

-- ============================================================================
-- :OpenGitRemote command
-- ============================================================================

function M.open_git_remote(name, reset)
  local git_root = get_git_root()
  if not git_root then
    warn("git-open: not a git repository")
    return
  end

  if reset then
    vim.b.vim_git_open_remote = nil
    vim.b.vim_git_open_remote_warned = nil
    print("git-open: remote reset (will re-resolve on next command)")
    return
  end

  if not name or name == "" then
    local current = get_current_remote(git_root)
    if not current or current == "" then
      warn("git-open: no remotes found")
    else
      print("git-open: current remote is '" .. current .. "'")
    end
    return
  end

  local remotes = get_all_remote_names(git_root)
  for _, r in ipairs(remotes) do
    if r == name then
      vim.b.vim_git_open_remote = name
      vim.b.vim_git_open_remote_warned = nil
      print("git-open: remote set to '" .. name .. "' for this buffer")
      return
    end
  end
  warn("git-open: remote '" .. name .. "' not found (available: " .. table.concat(remotes, ", ") .. ")")
end

-- ============================================================================
-- Public API — primary remote commands
-- ============================================================================

function M.get_repo_info()
  return get_repo_info()
end

function M.get_all_remotes()
  return get_all_remotes()
end

function M.get_repo_info_for_remote(remote_name)
  return get_repo_info_for_remote(remote_name)
end

function M.open_repo(copy)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local url = call_provider(repo_info.provider, "build_repo_url", repo_info)
  open_or_copy(url, copy)
end

function M.open_branch(branch, copy, visual)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local ref = branch
  if (not ref or ref == "") and visual then
    ref = get_visual_selection()
  end
  if not ref or ref == "" then
    ref = get_current_branch()
  end

  local url = call_provider(repo_info.provider, "build_branch_url", repo_info, ref)
  open_or_copy(url, copy)
end

function M.open_file(line1, line2, ref, copy)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  if vim.fn.expand("%") == "" then
    warn("No file in current buffer")
    return
  end

  local line_range = get_line_range(line1, line2)
  local file = get_relative_path()
  local resolved_ref = (ref and ref ~= "") and ref or get_current_commit()

  local url = call_provider(repo_info.provider, "build_file_url", repo_info, file, line_range, resolved_ref)
  open_or_copy(url, copy)
end

function M.open_commit(commit, copy, visual)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local ref = commit
  if (not ref or ref == "") and visual then
    ref = get_visual_selection()
  end
  if not ref or ref == "" then
    ref = get_current_commit()
  end

  local url = call_provider(repo_info.provider, "build_commit_url", repo_info, ref)
  open_or_copy(url, copy)
end

function M.open_request(number, copy)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local req = (number and number ~= "") and number or parse_request_number_from_commit(repo_info.provider)

  if not req or req == "" then
    warn("No request number specified and could not parse from commit message")
    return
  end

  local url = call_provider(repo_info.provider, "build_request_url", repo_info, req)
  open_or_copy(url, copy)
end

function M.open_file_last_change(copy)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local file_path = get_relative_path()
  if not file_path then
    warn("Current file is not in a git repository")
    return
  end

  local commit = git_command({ "log", "-1", "--format=%H", "--", file_path })
  if not commit or commit == "" then
    warn("No commits found for current file")
    return
  end

  local message = git_command({ "log", "-1", "--format=%B", commit })
  local pr_mr_number = call_provider(repo_info.provider, "parse_request_number", message)

  local url
  if pr_mr_number then
    url = call_provider(repo_info.provider, "build_request_url", repo_info, pr_mr_number)
  else
    url = call_provider(repo_info.provider, "build_commit_url", repo_info, commit)
  end

  open_or_copy(url, copy)
end

function M.open_requests(state_arg, copy)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local url = call_provider(repo_info.provider, "build_requests_url", repo_info, state_arg)
  open_or_copy(url, copy)
end

function M.open_my_requests(state_arg, copy)
  local repo_info = get_repo_info()
  if not repo_info then
    return
  end

  local url = call_provider(repo_info.provider, "build_my_requests_url", repo_info, state_arg)
  open_or_copy(url, copy)
end

-- ============================================================================
-- Per-Remote Public API
-- ============================================================================

function M.open_repo_for_remote(remote_name, copy)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  local url = call_provider(repo_info.provider, "build_repo_url", repo_info)
  open_or_copy(url, copy)
end

function M.open_branch_for_remote(remote_name, branch, copy, visual)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  local ref = branch
  if (not ref or ref == "") and visual then
    ref = get_visual_selection()
  end
  if not ref or ref == "" then
    ref = get_current_branch()
  end
  local url = call_provider(repo_info.provider, "build_branch_url", repo_info, ref)
  open_or_copy(url, copy)
end

function M.open_file_for_remote(remote_name, line1, line2, ref, copy)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  if vim.fn.expand("%") == "" then
    warn("No file in current buffer")
    return
  end
  local line_range = get_line_range(line1, line2)
  local file = get_relative_path()
  local resolved_ref = (ref and ref ~= "") and ref or get_current_commit()
  local url = call_provider(repo_info.provider, "build_file_url", repo_info, file, line_range, resolved_ref)
  open_or_copy(url, copy)
end

function M.open_commit_for_remote(remote_name, commit, copy, visual)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  local ref = commit
  if (not ref or ref == "") and visual then
    ref = get_visual_selection()
  end
  if not ref or ref == "" then
    ref = get_current_commit()
  end
  local url = call_provider(repo_info.provider, "build_commit_url", repo_info, ref)
  open_or_copy(url, copy)
end

function M.open_request_for_remote(remote_name, number, copy)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  local req = (number and number ~= "") and number or parse_request_number_from_commit(repo_info.provider)
  if not req or req == "" then
    warn("No request number specified and could not parse from commit message")
    return
  end
  local url = call_provider(repo_info.provider, "build_request_url", repo_info, req)
  open_or_copy(url, copy)
end

function M.open_requests_for_remote(remote_name, state_arg, copy)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  local url = call_provider(repo_info.provider, "build_requests_url", repo_info, state_arg)
  open_or_copy(url, copy)
end

function M.open_my_requests_for_remote(remote_name, state_arg, copy)
  local repo_info = get_repo_info_for_remote(remote_name)
  if not repo_info then
    warn("No remote configured for: " .. remote_name)
    return
  end
  local url = call_provider(repo_info.provider, "build_my_requests_url", repo_info, state_arg)
  open_or_copy(url, copy)
end

-- ============================================================================
-- Gitk Functions
-- ============================================================================

function M.open_gitk(args_str)
  local git_root = get_git_root()
  if not git_root then
    warn("git-open: not a git repository")
    return
  end
  local args = (args_str and args_str ~= "") and vim.split(args_str, "%s+") or {}
  launch_gitk(args, git_root)
end

function M.open_gitk_file(opts_str, history)
  local git_root = get_git_root()
  if not git_root then
    warn("git-open: not a git repository")
    return
  end
  if vim.fn.expand("%") == "" then
    warn("git-open: no file in current buffer")
    return
  end
  local rel_path = get_relative_path()
  local paths = history and get_gitk_old_paths(rel_path, git_root) or { rel_path }
  local extra_args = (opts_str and opts_str ~= "") and vim.split(opts_str, "%s+") or {}
  local args = {}
  for _, a in ipairs(extra_args) do
    table.insert(args, a)
  end
  table.insert(args, "--")
  for _, p in ipairs(paths) do
    table.insert(args, p)
  end
  launch_gitk(args, git_root)
end

-- ============================================================================
-- Setup
-- ============================================================================

function M.setup(opts)
  opts = opts or {}

  if opts.domains then
    vim.g.vim_git_open_domains = opts.domains
  end

  if opts.providers then
    vim.g.vim_git_open_providers = opts.providers
  end

  if opts.remote then
    if not vim.g.vim_git_open_remote then
      vim.g.vim_git_open_remote = opts.remote
    end
  elseif not vim.g.vim_git_open_remote then
    vim.g.vim_git_open_remote = ""
  end

  if opts.browser_command then
    vim.g.vim_git_open_browser_command = opts.browser_command
  end

  if not vim.g.vim_git_open_browser_command or vim.g.vim_git_open_browser_command == "" then
    if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
      vim.g.vim_git_open_browser_command = "open"
    elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
      vim.g.vim_git_open_browser_command = "start"
    else
      vim.g.vim_git_open_browser_command = "xdg-open"
    end
  end

  local browser_env = vim.fn.getenv("BROWSER")
  if browser_env and browser_env ~= vim.NIL and browser_env ~= "" then
    vim.g.vim_git_open_browser_command = browser_env
  end
end

return M
