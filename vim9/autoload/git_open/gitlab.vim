vim9script

# autoload/git_open/gitlab.vim - GitLab provider for vim-git-open
# Maintainer:   Phong Nguyen
# Version:      1.0.0

# ============================================================================
# Provider Interface — see autoload/git_open/github.vim for the full contract
# ============================================================================

# ============================================================================
# URL pattern helpers
# ============================================================================

# {base_url}/{path} — root URL for all repo-scoped paths
def RepoBase(repo_info: dict<string>): string
    return repo_info.base_url .. '/' .. repo_info.path
enddef

def BranchPath(branch: string): string
    return '/-/tree/' .. branch
enddef

def FilePath(ref: string, file: string): string
    return '/-/blob/' .. ref .. '/' .. file
enddef

def CommitPath(commit: string): string
    return '/-/commit/' .. commit
enddef

def RequestPath(number: string): string
    return '/-/merge_requests/' .. number
enddef

def RequestsPath(): string
    return '/-/merge_requests'
enddef

def MyRequestsPath(): string
    return '/dashboard/merge_requests'
enddef

# Returns the query string (including '?') for a repo-scoped MR list, or ''.
# state_arg: '', '-open', '-closed', '-merged', '-all'
# GitLab uses ?state=opened|closed|merged|all; '-open' is the default (no query needed).
def RequestsQuery(state_arg: string): string
    var arg = tolower(trim(state_arg))
    if arg ==# '-merged'
        return '?state=merged'
    elseif arg ==# '-closed'
        return '?state=closed'
    elseif arg ==# '-all'
        return '?state=all'
    endif
    return ''
enddef

# ============================================================================
# Line anchor
# ============================================================================

# GitLab uses #L10 or #L10-20 anchors (no second 'L' before the end line)
def FormatLineAnchor(line_info: string): string
    if empty(line_info)
        return ''
    endif
    return '#L' .. line_info
enddef

# ============================================================================
# GitLab username resolution
# ============================================================================

# Resolve the GitLab username for use in -search URLs.
# Resolution order:
#   1. g:vim_git_open_gitlab_username
#   2. $GITLAB_USER
#   3. $GLAB_USER
#   4. $USER
def GetGitlabUsername(): string
    if exists('g:vim_git_open_gitlab_username') && !empty(g:vim_git_open_gitlab_username)
        return g:vim_git_open_gitlab_username
    endif
    if !empty($GITLAB_USER)
        return $GITLAB_USER
    elseif !empty($GLAB_USER)
        return $GLAB_USER
    endif
    return $USER
enddef

# ============================================================================
# Public provider interface
# ============================================================================

# GitLab uses !1234 for MR references in commit messages
export def ParseRequestNumber(message: string): string
    var m = matchlist(message, '!\(\d\+\)')
    return empty(m) ? '' : m[1]
enddef

export def BuildRepoUrl(repo_info: dict<string>): string
    return RepoBase(repo_info)
enddef

export def BuildBranchUrl(repo_info: dict<string>, branch: string): string
    return RepoBase(repo_info) .. BranchPath(branch)
enddef

export def BuildFileUrl(repo_info: dict<string>, file: string, line_info: string, ref: string): string
    var url = RepoBase(repo_info) .. FilePath(ref, file)
    if !empty(line_info)
        url ..= FormatLineAnchor(line_info)
    endif
    return url
enddef

export def BuildCommitUrl(repo_info: dict<string>, commit: string): string
    return RepoBase(repo_info) .. CommitPath(commit)
enddef

export def BuildRequestUrl(repo_info: dict<string>, number: string): string
    return RepoBase(repo_info) .. RequestPath(number)
enddef

export def BuildRequestsUrl(repo_info: dict<string>, state_arg: string): string
    return RepoBase(repo_info) .. RequestsPath() .. RequestsQuery(state_arg)
enddef

# state_arg: '', '-open', '-closed', '-merged', '-all', '-search', '-search=<state>'
# GitLab's dashboard MR page shows the current user's MRs by default.
#   no flag / -open / -all → /dashboard/merge_requests
#   -closed / -merged      → /dashboard/merge_requests/merged
#   -search[=<state>]      → /dashboard/merge_requests/search?author_username=<user>[&state=<state>]
export def BuildMyRequestsUrl(repo_info: dict<string>, state_arg: string): string
    var arg = tolower(trim(state_arg))
    if arg =~# '^-search'
        var parts = split(arg, '=')
        var search_state = len(parts) > 1 ? parts[1] : ''
        var url = repo_info.base_url .. MyRequestsPath() .. '/search?author_username=' .. GetGitlabUsername()
        if search_state ==# 'closed' || search_state ==# 'merged'
            url ..= '&state=' .. search_state
        elseif search_state ==# 'all'
            url ..= '&state=all'
        elseif search_state ==# 'open'
            url ..= '&state=opened'
        endif
        return url
    elseif arg ==# '-closed' || arg ==# '-merged'
        return repo_info.base_url .. MyRequestsPath() .. '/merged'
    endif
    # no flag / -open / -all: default dashboard page
    return repo_info.base_url .. MyRequestsPath()
enddef
