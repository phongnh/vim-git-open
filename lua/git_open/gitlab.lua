-- lua/git_open/gitlab.lua - GitLab provider for vim-git-open
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

-- ============================================================================
-- Provider Interface — see lua/git_open/github.lua for the full contract
-- ============================================================================

local M = {}

-- ============================================================================
-- URL pattern helpers
-- ============================================================================

-- {base_url}/{path} — root URL for all repo-scoped paths
local function repo_base(repo_info)
  return repo_info.base_url .. "/" .. repo_info.path
end

local function branch_path(branch)
  return "/-/tree/" .. branch
end

local function file_path(ref, file)
  return "/-/blob/" .. ref .. "/" .. file
end

local function commit_path(commit)
  return "/-/commit/" .. commit
end

local function request_path(number)
  return "/-/merge_requests/" .. number
end

local function requests_path()
  return "/-/merge_requests"
end

local function my_requests_path()
  return "/dashboard/merge_requests"
end

-- Returns the query string (including "?") for a repo-scoped MR list, or "".
-- state_arg: "", "-open", "-closed", "-merged", "-all"
-- GitLab uses ?state=opened|closed|merged|all; "-open" is the default (no query needed).
local function requests_query(state_arg)
  local arg = vim.trim(state_arg or ""):lower()
  if arg == "-merged" then
    return "?state=merged"
  elseif arg == "-closed" then
    return "?state=closed"
  elseif arg == "-all" then
    return "?state=all"
  end
  return ""
end

-- ============================================================================
-- Line anchor
-- ============================================================================

-- GitLab uses #L10 or #L10-20 anchors (no second "L" before the end line)
local function format_line_anchor(line_info)
  if not line_info or line_info == "" then
    return ""
  end
  return "#L" .. line_info
end

-- ============================================================================
-- GitLab username resolution
-- ============================================================================

-- Resolve the GitLab username for use in -search URLs.
-- Resolution order:
--   1. vim.g.vim_git_open_gitlab_username
--   2. $GITLAB_USER
--   3. $GLAB_USER
--   4. $USER
local function get_gitlab_username()
  local cfg = vim.g.vim_git_open_gitlab_username
  if cfg and cfg ~= "" then
    return cfg
  end
  local gitlab_user = vim.fn.getenv("GITLAB_USER")
  if gitlab_user ~= vim.NIL and gitlab_user ~= "" then
    return gitlab_user
  end
  local glab_user = vim.fn.getenv("GLAB_USER")
  if glab_user ~= vim.NIL and glab_user ~= "" then
    return glab_user
  end
  return vim.fn.expand("$USER")
end

-- ============================================================================
-- Public provider interface
-- ============================================================================

-- GitLab uses !1234 for MR references in commit messages
function M.parse_request_number(message)
  if not message then
    return nil
  end
  return message:match("!(%d+)")
end

function M.build_repo_url(repo_info)
  return repo_base(repo_info)
end

function M.build_branch_url(repo_info, branch)
  return repo_base(repo_info) .. branch_path(branch)
end

function M.build_file_url(repo_info, file, line_info, ref)
  local url = repo_base(repo_info) .. file_path(ref, file)
  if line_info and line_info ~= "" then
    url = url .. format_line_anchor(line_info)
  end
  return url
end

function M.build_commit_url(repo_info, commit)
  return repo_base(repo_info) .. commit_path(commit)
end

function M.build_request_url(repo_info, number)
  return repo_base(repo_info) .. request_path(number)
end

function M.build_requests_url(repo_info, state_arg)
  return repo_base(repo_info) .. requests_path() .. requests_query(state_arg)
end

-- state_arg: "", "-open", "-closed", "-merged", "-all", "-search", "-search=<state>"
-- GitLab's dashboard MR page shows the current user's MRs by default.
--   no flag / -open / -all → /dashboard/merge_requests
--   -closed / -merged      → /dashboard/merge_requests/merged
--   -search[=<state>]      → /dashboard/merge_requests/search?author_username=<user>[&state=<state>]
function M.build_my_requests_url(repo_info, state_arg)
  local arg = vim.trim(state_arg or ""):lower()
  if arg:match("^%-search") then
    local search_state = arg:match("^%-search=(.+)$") or ""
    local url = repo_info.base_url .. my_requests_path() .. "/search?author_username=" .. get_gitlab_username()
    if search_state == "closed" or search_state == "merged" then
      url = url .. "&state=" .. search_state
    elseif search_state == "all" then
      url = url .. "&state=all"
    elseif search_state == "open" then
      url = url .. "&state=opened"
    end
    return url
  elseif arg == "-closed" or arg == "-merged" then
    return repo_info.base_url .. my_requests_path() .. "/merged"
  end
  -- no flag / -open / -all: default dashboard page
  return repo_info.base_url .. my_requests_path()
end

return M
