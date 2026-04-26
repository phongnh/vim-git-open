-- lua/git_open/codeberg.lua - Codeberg (Gitea/Forgejo) provider for vim-git-open
-- Maintainer:   Phong Nguyen
-- Version:      1.0.0

-- ============================================================================
-- Provider Interface — see lua/git_open/github.lua for the full contract
--
-- Codeberg URL differences from GitHub:
--   branch view:          /src/branch/{branch}
--   file at branch:       /src/branch/{branch}/{file}
--   file at commit:       /src/commit/{commit}/{file}
--   single PR:            /pulls/{number}   (not /pull/)
--   commit:               /commit/{hash}    (same as GitHub)
--   PR list state param:  ?state=open|closed  (Gitea API; no "merged" state)
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
  return "/src/branch/" .. branch
end

-- ref may be a 40-char commit hash or a branch name — Codeberg requires
-- different path segments for each (/src/commit/ vs /src/branch/)
local function file_path(ref, file)
  local ref_type = (ref:match("^[0-9a-f]+$") and #ref == 40) and "commit" or "branch"
  return "/src/" .. ref_type .. "/" .. ref .. "/" .. file
end

local function commit_path(commit)
  return "/commit/" .. commit
end

-- Codeberg uses /pulls/{number} (plural), unlike GitHub's /pull/{number}
local function request_path(number)
  return "/pulls/" .. number
end

local function requests_path()
  return "/pulls"
end

-- Codeberg user-scoped PR list uses the same /pulls root as the repo list.
local function my_requests_path()
  return "/pulls"
end

-- Returns the query string (including "?") for a repo-scoped PR list, or "".
-- state_arg: "", "-open", "-closed", "-merged", "-all"
-- Codeberg (Gitea) uses ?state=open|closed; no "merged" state — "-merged" maps to closed.
-- "-all" shows all PRs without a state filter.
local function requests_query(state_arg)
  local arg = vim.trim(state_arg or ""):lower()
  if arg == "-closed" or arg == "-merged" then
    return "?state=closed"
  end
  return ""
end

-- Returns the query string (including "?") for a user-scoped PR list, or "".
-- state_arg: "", "-open", "-closed", "-merged", "-all"
-- Codeberg uses type=created_by to filter to the current user.
local function my_requests_query(state_arg)
  local arg = vim.trim(state_arg or ""):lower()
  if arg == "-closed" or arg == "-merged" then
    return "?type=created_by&state=closed"
  elseif arg == "-all" then
    return "?type=created_by"
  end
  return ""
end

-- ============================================================================
-- Line anchor
-- ============================================================================

-- Codeberg uses #L10 or #L10-L20 anchors (same format as GitHub)
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

-- Codeberg uses #1234 for PR references in commit messages (same as GitHub)
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

-- "-merged" is treated as "-closed" (Gitea has no "merged" state param).
-- "-all" returns bare /pulls with no state filter.
function M.build_requests_url(repo_info, state_arg)
  return repo_base(repo_info) .. requests_path() .. requests_query(state_arg)
end

-- Codeberg personal PR page uses type=created_by to filter to current user.
--   no flag / -open  → /pulls            (Gitea already scopes to open PRs)
--   -all             → /pulls?type=created_by
--   -closed/-merged  → /pulls?type=created_by&state=closed
function M.build_my_requests_url(repo_info, state_arg)
  return repo_info.base_url .. my_requests_path() .. my_requests_query(state_arg)
end

return M
