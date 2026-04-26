vim9script

# autoload/git_open/github.vim - GitHub provider for vim-git-open
# Maintainer:   Phong Nguyen
# Version:      1.0.0

# ============================================================================
# Provider Interface
#
# Common interface implemented by every provider.
# `repo_info` is the repo info dict: { base_url, path, provider, domain }
#
#   git_open#<provider>#ParseRequestNumber(message)                        -> string
#   git_open#<provider>#BuildRepoUrl(repo_info)                            -> string
#   git_open#<provider>#BuildBranchUrl(repo_info, branch)                  -> string
#   git_open#<provider>#BuildFileUrl(repo_info, file, line_info, ref)      -> string
#   git_open#<provider>#BuildCommitUrl(repo_info, commit)                  -> string
#   git_open#<provider>#BuildRequestUrl(repo_info, number)                 -> string
#   git_open#<provider>#BuildRequestsUrl(repo_info, state_arg)             -> string
#   git_open#<provider>#BuildMyRequestsUrl(repo_info, state_arg)           -> string
#
# line_info: line number or range string (e.g. '10' or '10-20'), or empty.
# ref:       branch name or 40-char commit SHA; caller resolves empty ref to HEAD.
# state_arg: '', '-open', '-closed', '-merged', '-all' (provider-specific handling).
# ============================================================================

# ============================================================================
# URL pattern helpers
# ============================================================================

# {base_url}/{path} — root URL for all repo-scoped paths
def RepoBase(repo_info: dict<string>): string
    return repo_info.base_url .. '/' .. repo_info.path
enddef

def BranchPath(branch: string): string
    return '/tree/' .. branch
enddef

def FilePath(ref: string, file: string): string
    return '/blob/' .. ref .. '/' .. file
enddef

def CommitPath(commit: string): string
    return '/commit/' .. commit
enddef

def RequestPath(number: string): string
    return '/pull/' .. number
enddef

def RequestsPath(): string
    return '/pulls'
enddef

# GitHub user-scoped PR list uses the same /pulls root as the repo list.
def MyRequestsPath(): string
    return '/pulls'
enddef

# Returns the query string (including '?') for a repo-scoped PR list, or ''.
# state_arg: '', '-open', '-closed', '-merged', '-all'
# GitHub uses search syntax: plain ?state= only targets the issues API.
def RequestsQuery(state_arg: string): string
    var arg = tolower(trim(state_arg))
    if arg ==# '-closed' || arg ==# '-merged'
        return '?q=is%3Apr+is%3Aclosed'
    elseif arg ==# '-all'
        return '?q=is%3Apr'
    endif
    return ''
enddef

# Returns the query string (including '?') for a user-scoped PR list, or ''.
# GitHub scopes /pulls to the current user by default; state flags add author:@me.
def MyRequestsQuery(state_arg: string): string
    var arg = tolower(trim(state_arg))
    if arg ==# '-closed' || arg ==# '-merged'
        return '?q=is%3Apr+is%3Aclosed+author%3A%40me'
    elseif arg ==# '-all'
        return '?q=is%3Apr+author%3A%40me'
    endif
    return ''
enddef

# ============================================================================
# Line anchor
# ============================================================================

# GitHub uses #L10 or #L10-L20 anchors
def FormatLineAnchor(line_info: string): string
    if empty(line_info)
        return ''
    endif
    if line_info =~# '-'
        var parts = split(line_info, '-')
        return '#L' .. parts[0] .. '-L' .. parts[1]
    endif
    return '#L' .. line_info
enddef

# ============================================================================
# Public provider interface
# ============================================================================

# GitHub uses #1234 for PR references in commit messages
export def ParseRequestNumber(message: string): string
    var m = matchlist(message, '#\(\d\+\)')
    return empty(m) ? '' : m[1]
enddef

export def BuildRepoUrl(repo_info: dict<string>): string
    return RepoBase(repo_info)
enddef

export def BuildBranchUrl(repo_info: dict<string>, branch: string): string
    return RepoBase(repo_info) .. BranchPath(branch)
enddef

# file      - relative path to file
# line_info - line number or range string (e.g. '10' or '10-20'), may be empty
# ref       - branch or commit hash; caller must resolve empty ref to HEAD commit
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

# GitHub /pulls is already scoped to the current user when logged in.
# A state flag appends author:@me to stay user-scoped.
export def BuildMyRequestsUrl(repo_info: dict<string>, state_arg: string): string
    return repo_info.base_url .. MyRequestsPath() .. MyRequestsQuery(state_arg)
enddef
