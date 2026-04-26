vim9script

# autoload/git_open/codeberg.vim - Codeberg (Gitea/Forgejo) provider for vim-git-open
# Maintainer:   Phong Nguyen
# Version:      1.0.0

# ============================================================================
# Provider Interface — see autoload/git_open/github.vim for the full contract
#
# Codeberg URL differences from GitHub:
#   branch view:          /src/branch/{branch}
#   file at branch:       /src/branch/{branch}/{file}
#   file at commit:       /src/commit/{commit}/{file}
#   single PR:            /pulls/{number}   (not /pull/)
#   commit:               /commit/{hash}    (same as GitHub)
#   PR list state param:  ?state=open|closed  (Gitea API; no 'merged' state)
# ============================================================================

# ============================================================================
# URL pattern helpers
# ============================================================================

# {base_url}/{path} — root URL for all repo-scoped paths
def RepoBase(repo_info: dict<string>): string
    return repo_info.base_url .. '/' .. repo_info.path
enddef

def BranchPath(branch: string): string
    return '/src/branch/' .. branch
enddef

# ref may be a 40-char commit hash or a branch name — Codeberg requires
# different path segments for each (/src/commit/ vs /src/branch/)
def FilePath(ref: string, file: string): string
    var ref_type = ref =~# '^[0-9a-f]\{40\}$' ? 'commit' : 'branch'
    return '/src/' .. ref_type .. '/' .. ref .. '/' .. file
enddef

def CommitPath(commit: string): string
    return '/commit/' .. commit
enddef

# Codeberg uses /pulls/{number} (plural), unlike GitHub's /pull/{number}
def RequestPath(number: string): string
    return '/pulls/' .. number
enddef

def RequestsPath(): string
    return '/pulls'
enddef

# Codeberg user-scoped PR list uses the same /pulls root as the repo list.
def MyRequestsPath(): string
    return '/pulls'
enddef

# Returns the query string (including '?') for a repo-scoped PR list, or ''.
# state_arg: '', '-open', '-closed', '-merged', '-all'
# Codeberg (Gitea) uses ?state=open|closed; no 'merged' state — '-merged' maps to closed.
# '-all' shows all PRs without a state filter.
def RequestsQuery(state_arg: string): string
    var arg = tolower(trim(state_arg))
    if arg ==# '-closed' || arg ==# '-merged'
        return '?state=closed'
    endif
    return ''
enddef

# Returns the query string (including '?') for a user-scoped PR list, or ''.
# state_arg: '', '-open', '-closed', '-merged', '-all'
# Codeberg uses type=created_by to filter to the current user.
def MyRequestsQuery(state_arg: string): string
    var arg = tolower(trim(state_arg))
    if arg ==# '-closed' || arg ==# '-merged'
        return '?type=created_by&state=closed'
    elseif arg ==# '-all'
        return '?type=created_by'
    endif
    return ''
enddef

# ============================================================================
# Line anchor
# ============================================================================

# Codeberg uses #L10 or #L10-L20 anchors (same format as GitHub)
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

# Codeberg uses #1234 for PR references in commit messages (same as GitHub)
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

# '-merged' is treated as '-closed' (Gitea has no 'merged' state param).
# '-all' returns bare /pulls with no state filter.
export def BuildRequestsUrl(repo_info: dict<string>, state_arg: string): string
    return RepoBase(repo_info) .. RequestsPath() .. RequestsQuery(state_arg)
enddef

# Codeberg personal PR page uses type=created_by to filter to current user.
#   no flag / -open  → /pulls            (Gitea already scopes to open PRs)
#   -all             → /pulls?type=created_by
#   -closed/-merged  → /pulls?type=created_by&state=closed
export def BuildMyRequestsUrl(repo_info: dict<string>, state_arg: string): string
    return repo_info.base_url .. MyRequestsPath() .. MyRequestsQuery(state_arg)
enddef
