-- lua/git_open/github.lua - GitHub provider for vim-git-open
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

-- ============================================================================
-- Provider Interface
--
-- Common interface implemented by every provider.
-- `repo_info` is the repo info table: { base_url, path, provider, domain }
--
--   M.parse_request_number(message)                        -> string|nil
--   M.build_repo_url(repo_info)                            -> string
--   M.build_branch_url(repo_info, branch)                  -> string
--   M.build_file_url(repo_info, file, line_info, ref)      -> string
--   M.build_commit_url(repo_info, commit)                  -> string
--   M.build_request_url(repo_info, number)                 -> string
--   M.build_requests_url(repo_info, state_arg)             -> string
--   M.build_my_requests_url(repo_info, state_arg)          -> string
--
-- line_info: line number or range string (e.g. "10" or "10-20"), or "".
-- ref:       branch name or 40-char commit SHA; caller resolves empty ref to HEAD.
-- state_arg: "", "-open", "-closed", "-merged", "-all" (provider-specific handling).
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
  return "/tree/" .. branch
end

local function file_path(ref, file)
  return "/blob/" .. ref .. "/" .. file
end

local function commit_path(commit)
  return "/commit/" .. commit
end

local function request_path(number)
  return "/pull/" .. number
end

local function requests_path()
  return "/pulls"
end

-- GitHub user-scoped PR list uses the same /pulls root as the repo list.
local function my_requests_path()
  return "/pulls"
end

-- Returns the query string (including "?") for a repo-scoped PR list, or "".
-- state_arg: "", "-open", "-closed", "-merged", "-all"
-- GitHub uses search syntax: plain ?state= only targets the issues API.
local function requests_query(state_arg)
  local arg = vim.trim(state_arg or ""):lower()
  if arg == "-closed" or arg == "-merged" then
    return "?q=is%3Apr+is%3Aclosed"
  elseif arg == "-all" then
    return "?q=is%3Apr"
  end
  return ""
end

-- Returns the query string (including "?") for a user-scoped PR list, or "".
-- GitHub scopes /pulls to the current user by default; state flags add author:@me.
local function my_requests_query(state_arg)
  local arg = vim.trim(state_arg or ""):lower()
  if arg == "-closed" or arg == "-merged" then
    return "?q=is%3Apr+is%3Aclosed+author%3A%40me"
  elseif arg == "-all" then
    return "?q=is%3Apr+author%3A%40me"
  end
  return ""
end

-- ============================================================================
-- Line anchor
-- ============================================================================

-- GitHub uses #L10 or #L10-L20 anchors
local function format_line_anchor(line_info)
  if not line_info or line_info == "" then
    return ""
  end
  if line_info:match("-") then
    local parts = vim.split(line_info, "-", { plain = true })
    return "#L" .. parts[1] .. "-L" .. parts[2]
  end
  return "#L" .. line_info
end

-- ============================================================================
-- Public provider interface
-- ============================================================================

-- GitHub uses #1234 for PR references in commit messages
function M.parse_request_number(message)
  if not message then
    return nil
  end
  return message:match("#(%d+)")
end

function M.build_repo_url(repo_info)
  return repo_base(repo_info)
end

function M.build_branch_url(repo_info, branch)
  return repo_base(repo_info) .. branch_path(branch)
end

-- file      - relative path to file
-- line_info - line number or range string (e.g. "10" or "10-20"), may be ""
-- ref       - branch or commit hash; caller must resolve empty ref to HEAD commit
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

-- GitHub /pulls is already scoped to the current user when logged in.
-- A state flag appends author:@me to stay user-scoped.
function M.build_my_requests_url(repo_info, state_arg)
  return repo_info.base_url .. my_requests_path() .. my_requests_query(state_arg)
end

return M
