vim9script

# autoload/git_open.vim - Core functionality (Vim9script version)
# Maintainer:   Phong Nguyen
# Version:      1.0.0

# ============================================================================
# Helper Functions
# ============================================================================

def Warn(msg: string)
    echohl ErrorMsg
    echom msg
    echohl None
enddef

def GetGitRoot(): string
    var git_dir = finddir('.git', expand('%:p:h') .. ';')
    if empty(git_dir)
        return ''
    endif
    # Get absolute path to .git directory, then get its parent
    var abs_git_dir = fnamemodify(git_dir, ':p')
    # Remove trailing slash and .git
    abs_git_dir = substitute(abs_git_dir, '/$', '', '')
    var root = fnamemodify(abs_git_dir, ':h')
    return root
enddef

def GitCommand(args: string): string
    var git_root = GetGitRoot()
    if empty(git_root)
        return ''
    endif
    
    var cmd = 'git -C ' .. shellescape(git_root) .. ' ' .. args
    var output = system(cmd)
    return substitute(output, '\n\+$', '', '')
enddef

def ParseRemoteUrl(): dict<string>
    var remote = GitCommand('config --get remote.origin.url')
    if empty(remote)
        return {}
    endif
    
    var result: dict<string> = {domain: '', path: ''}
    
    # Handle SSH URLs: git@github.com:user/repo.git
    var ssh_match = matchlist(remote, '^\(git@\|ssh://git@\)\([^:\/]\+\)[:|/]\(.*\)\.git$')
    if !empty(ssh_match)
        result.domain = ssh_match[2]
        result.path = ssh_match[3]
        return result
    endif
    
    # Handle HTTPS URLs: https://github.com/user/repo.git
    var https_match = matchlist(remote, '^\(https\?://\)\([^/]\+\)/\(.*\)\(\.git\)\?$')
    if !empty(https_match)
        result.domain = https_match[2]
        result.path = substitute(https_match[3], '\.git$', '', '')
        return result
    endif
    
    return {}
enddef

def DetectProvider(domain: string): string
    # Check user-defined providers first
    if has_key(g:vim_git_open_providers, domain)
        return g:vim_git_open_providers[domain]
    endif
    
    # Auto-detect known providers
    if domain =~# 'github\.com'
        return 'GitHub'
    elseif domain =~# 'gitlab\.com'
        return 'GitLab'
    elseif domain =~# 'codeberg\.org'
        return 'Codeberg'
    endif
    
    # Default to GitHub
    return 'GitHub'
enddef

def GetBaseUrl(domain: string): string
    # Check user-defined domain mappings
    if has_key(g:vim_git_open_domains, domain)
        var mapped_url = g:vim_git_open_domains[domain]
        # Add https:// if no protocol specified
        if mapped_url !~# '^\(https\?://\)'
            return 'https://' .. mapped_url
        endif
        return mapped_url
    endif
    
    # Default to https://domain
    return 'https://' .. domain
enddef

def GetCurrentBranch(): string
    return GitCommand('rev-parse --abbrev-ref HEAD')
enddef

def GetCurrentCommit(): string
    return GitCommand('rev-parse HEAD')
enddef

def GetRelativePath(): string
    var git_root = GetGitRoot()
    if empty(git_root)
        return ''
    endif
    
    var abs_path = expand('%:p')
    
    # Ensure git_root ends with /
    if git_root !~# '/$'
        git_root = git_root .. '/'
    endif
    
    # Check if abs_path starts with git_root using string comparison
    if strpart(abs_path, 0, len(git_root)) ==# git_root
        return strpart(abs_path, len(git_root))
    endif
    
    # Fallback: try regex method with proper escaping
    var rel_path = substitute(abs_path, '^' .. escape(git_root, '\/.*[]^$~') .. '/', '', '')
    return rel_path
enddef

def GetLineRange(line1: number, line2: number): any
    if line1 == line2
        return line1
    else
        return line1 .. '-' .. line2
    endif
enddef

def FormatLineAnchor(provider: string, line_info: any): string
    if empty(line_info)
        return ''
    endif
    
    var line_str = '' .. line_info
    
    if provider ==# 'GitLab'
        # GitLab uses #L10 or #L10-20
        if line_str =~# '-'
            return '#L' .. substitute(line_str, '-', '-', '')
        else
            return '#L' .. line_str
        endif
    else
        # GitHub/Codeberg use #L10 or #L10-L20
        if line_str =~# '-'
            var parts = split(line_str, '-')
            return '#L' .. parts[0] .. '-L' .. parts[1]
        else
            return '#L' .. line_str
        endif
    endif
enddef

# Parse PR/MR number from a given message
def ParsePrMrNumber(message: string, provider: string): string
    var match_result: list<string>
    if provider ==# 'GitLab'
        # GitLab uses !1234
        match_result = matchlist(message, '!\(\d\+\)')
    else
        # GitHub/Codeberg use #1234
        match_result = matchlist(message, '#\(\d\+\)')
    endif
    
    if !empty(match_result)
        return match_result[1]
    endif
    
    return ''
enddef

def ParsePrMrFromCommit(provider: string): string
    var commit_msg = GitCommand('log -1 --pretty=%B')
    return ParsePrMrNumber(commit_msg, provider)
enddef

def GetGitLabUsername(): string
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

# Parse state flag from command args: -open, -closed, -merged, -all
# Returns the query string suffix to append to the pulls/MRs URL.
# GitHub:   uses ?q=is%3Apr+is%3A<state> search query
# Codeberg: uses ?state=<state> param (Gitea-based, no merged state)
# GitLab:   uses ?state=<state> param (opened/merged/closed/all)
def ParseRequestState(args: string, provider: string): string
    var arg = tolower(trim(args))
    if provider ==# 'GitLab'
        if arg ==# '-merged'
            return '?state=merged'
        elseif arg ==# '-closed'
            return '?state=closed'
        elseif arg ==# '-all'
            return '?state=all'
        endif
    elseif provider ==# 'Codeberg'
        if arg ==# '-closed' || arg ==# '-merged'
            return '?state=closed'
        elseif arg ==# '-all'
            return '?state=all'
        endif
    else
        # GitHub
        if arg ==# '-closed' || arg ==# '-merged'
            return '?q=is%3Apr+is%3Aclosed'
        elseif arg ==# '-all'
            return '?q=is%3Apr'
        endif
    endif
    return ''
enddef

# ============================================================================
# URL Builders
# ============================================================================

def BuildGithubUrl(base_url: string, path: string, type: string, ...extra: list<any>): string
    var url = base_url .. '/' .. path
    
    if type ==# 'repo'
        return url
    elseif type ==# 'branch'
        var branch = len(extra) > 0 ? extra[0] : GetCurrentBranch()
        return url .. '/tree/' .. branch
    elseif type ==# 'file'
        var file = (len(extra) > 0 && !empty(extra[0])) ? extra[0] : GetRelativePath()
        # extra[2] is an optional branch/commit ref; fall back to HEAD commit
        var ref = (len(extra) > 2 && !empty(extra[2])) ? extra[2] : GetCurrentCommit()
        var file_url = url .. '/blob/' .. ref .. '/' .. file
        
        # Add line number anchor if provided (extra[1])
        if len(extra) > 1 && !empty(extra[1])
            file_url ..= FormatLineAnchor('GitHub', extra[1])
        endif
        
        return file_url
    elseif type ==# 'commit'
        var commit = len(extra) > 0 ? extra[0] : GetCurrentCommit()
        return url .. '/commit/' .. commit
    elseif type ==# 'pr'
        var pr = len(extra) > 0 ? extra[0] : ''
        if empty(pr)
            Warn('No PR number specified')
            return ''
        endif
        return url .. '/pull/' .. pr
    endif
    
    return url
enddef

def BuildGitlabUrl(base_url: string, path: string, type: string, ...extra: list<any>): string
    var url = base_url .. '/' .. path
    
    if type ==# 'repo'
        return url
    elseif type ==# 'branch'
        var branch = len(extra) > 0 ? extra[0] : GetCurrentBranch()
        return url .. '/-/tree/' .. branch
    elseif type ==# 'file'
        var file = (len(extra) > 0 && !empty(extra[0])) ? extra[0] : GetRelativePath()
        # extra[2] is an optional branch/commit ref; fall back to HEAD commit
        var ref = (len(extra) > 2 && !empty(extra[2])) ? extra[2] : GetCurrentCommit()
        var file_url = url .. '/-/blob/' .. ref .. '/' .. file
        
        # Add line number anchor if provided (extra[1])
        if len(extra) > 1 && !empty(extra[1])
            file_url ..= FormatLineAnchor('GitLab', extra[1])
        endif
        
        return file_url
    elseif type ==# 'commit'
        var commit = len(extra) > 0 ? extra[0] : GetCurrentCommit()
        return url .. '/-/commit/' .. commit
    elseif type ==# 'mr'
        var mr = len(extra) > 0 ? extra[0] : ''
        if empty(mr)
            Warn('No MR number specified')
            return ''
        endif
        return url .. '/-/merge_requests/' .. mr
    endif
    
    return url
enddef

def BuildUrl(provider: string, base_url: string, path: string, type: string, ...extra: list<any>): string
    if provider ==# 'GitLab'
        return call(BuildGitlabUrl, [base_url, path, type] + extra)
    else
        # Default to GitHub (includes Codeberg)
        return call(BuildGithubUrl, [base_url, path, type] + extra)
    endif
enddef

# ============================================================================
# Browser Functions
# ============================================================================

def OpenBrowser(url: string)
    if empty(url)
        return
    endif
    
    if empty(g:vim_git_open_browser_command)
        Warn('No browser command configured. Set g:vim_git_open_browser_command')
        return
    endif
    
    var cmd = g:vim_git_open_browser_command .. ' ' .. shellescape(url)

    if has('win32') || has('win64')
        cmd = '!start "" ' .. shellescape(url)
    else
        cmd = cmd .. ' > /dev/null 2>&1'
    endif

    system(cmd)
    redraw!
    echo 'Opened: ' .. url
enddef

def CopyToClipboard(url: string)
    if empty(url)
        return
    endif

    setreg('+', url)
    setreg('*', url)
    redraw!
    echo 'Copied: ' .. url
enddef

def OpenOrCopy(url: string, copy: bool)
    if copy
        CopyToClipboard(url)
    else
        OpenBrowser(url)
    endif
enddef

def GetRepoInfo(): dict<string>
    var remote = ParseRemoteUrl()
    if empty(remote)
        Warn('Not a git repository or no remote configured')
        return {}
    endif
    
    var provider = DetectProvider(remote.domain)
    var base_url = GetBaseUrl(remote.domain)
    
    return {
        domain: remote.domain,
        path: remote.path,
        provider: provider,
        base_url: base_url
    }
enddef

# ============================================================================
# Completion Functions
# ============================================================================

export def CompleteBranch(arglead: string, cmdline: string, cursorpos: number): list<string>
    # Local branches sorted by most recent commit (-committerdate)
    var local_raw = GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    # Remote branches sorted by most recent commit, strip refs/remotes/<remote>/
    var remote_raw = GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/")

    var branches: list<string> = []
    if !empty(local_raw)
        branches += split(local_raw, '\n')
    endif
    if !empty(remote_raw)
        branches += filter(split(remote_raw, '\n'), (_, v) => v !=# 'HEAD')
    endif

    # Deduplicate while preserving order (local branches first)
    var seen: dict<bool> = {}
    var result: list<string> = []
    for b in branches
        if !has_key(seen, b)
            seen[b] = true
            result->add(b)
        endif
    endfor

    if empty(arglead)
        return result
    endif
    return matchfuzzy(result, arglead)
enddef

export def CompleteRequestState(arglead: string, cmdline: string, cursorpos: number): list<string>
    var flags = ['-open', '-closed', '-merged', '-all']
    if empty(arglead)
        return flags
    endif
    return matchfuzzy(flags, arglead)
enddef

export def CompleteMyRequestState(arglead: string, cmdline: string, cursorpos: number): list<string>
    var flags = ['-open', '-closed', '-merged', '-all',
                \ '-search', '-search=open', '-search=closed', '-search=merged', '-search=all']
    if empty(arglead)
        return flags
    endif
    return matchfuzzy(flags, arglead)
enddef

# ============================================================================
# Public API Functions
# ============================================================================

export def OpenRepo(copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif
    
    var url = BuildUrl(info.provider, info.base_url, info.path, 'repo')
    OpenOrCopy(url, copy)
enddef

export def OpenBranch(branch_arg: string = '', copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif

    var url = BuildUrl(info.provider, info.base_url, info.path, 'branch', branch_arg)
    OpenOrCopy(url, copy)
enddef

export def OpenMyRequests(state_arg: string = '', copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif

    var state = ParseRequestState(state_arg, info.provider)
    var url: string
    if info.provider ==# 'GitLab'
        var arg = tolower(trim(state_arg))
        # Check for -search or -search=<state>
        if arg =~# '^-search'
            var parts = split(arg, '=')
            var search_state = len(parts) > 1 ? parts[1] : ''
            var search_url = info.base_url .. '/dashboard/merge_requests/search?author_username=' .. GetGitLabUsername()
            if search_state ==# 'closed' || search_state ==# 'merged'
                search_url ..= '&state=' .. search_state
            elseif search_state ==# 'all'
                search_url ..= '&state=all'
            endif
            url = search_url
        elseif arg ==# '-closed' || arg ==# '-merged'
            url = info.base_url .. '/dashboard/merge_requests/merged'
        else
            # no flag / -open / -all: use the default dashboard page
            url = info.base_url .. '/dashboard/merge_requests'
        endif
    elseif info.provider ==# 'GitHub'
        # No flag/-open: /pulls is already scoped to current user when logged in
        # With state flag: append author:@me to keep scoped to current user
        url = info.base_url .. '/pulls' .. (empty(state) ? '' : state .. '+author%3A%40me')
    else
        # Codeberg: state is already a full query string or empty
        url = info.base_url .. '/pulls' .. state
    endif

    OpenOrCopy(url, copy)
enddef

export def OpenRequests(state_arg: string = '', copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif

    var state = ParseRequestState(state_arg, info.provider)
    var repo_url = info.base_url .. '/' .. info.path
    var url: string
    if info.provider ==# 'GitLab'
        url = repo_url .. '/-/merge_requests' .. state
    else
        # GitHub and Codeberg: state is already a full query string or empty
        url = repo_url .. '/pulls' .. state
    endif

    OpenOrCopy(url, copy)
enddef

export def OpenFile(line1: number, line2: number, ref_arg: string = '', copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif

    if empty(expand('%'))
        Warn('No file in current buffer')
        return
    endif

    var line_range = GetLineRange(line1, line2)

    # extra[0]=file(empty=current), extra[1]=line_range, extra[2]=ref(branch/commit)
    var url = BuildUrl(info.provider, info.base_url, info.path, 'file', '', line_range, ref_arg)
    OpenOrCopy(url, copy)
enddef

export def OpenCommit(commit_arg: string = '', copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif
    
    var url = BuildUrl(info.provider, info.base_url, info.path, 'commit', commit_arg)
    OpenOrCopy(url, copy)
enddef

export def OpenRequest(req_arg: string = '', copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif

    var number = !empty(req_arg) ? req_arg : ParsePrMrFromCommit(info.provider)

    if empty(number)
        Warn('No request number specified and could not parse from commit message')
        return
    endif

    var type = info.provider ==# 'GitLab' ? 'mr' : 'pr'
    var url = BuildUrl(info.provider, info.base_url, info.path, type, number)
    OpenOrCopy(url, copy)
enddef

export def OpenFileLastChange(copy: bool = false)
    var info = GetRepoInfo()
    if empty(info)
        return
    endif
    
    # Get the file path relative to git root
    var file_path = GetRelativePath()
    if empty(file_path)
        Warn('Current file is not in a git repository')
        return
    endif
    
    # Get the latest commit hash for this file
    var commit = GitCommand('log -1 --format=%H -- ' .. shellescape(file_path))
    if empty(commit)
        Warn('No commits found for current file')
        return
    endif
    
    # Get the commit message
    var message = GitCommand('log -1 --format=%B ' .. commit)
    
    # Try to parse PR/MR number from commit message
    var pr_mr_number = ParsePrMrNumber(message, info.provider)
    
    var url: string
    if !empty(pr_mr_number)
        # Open PR or MR if found
        if info.provider ==# 'GitLab'
            url = BuildUrl(info.provider, info.base_url, info.path, 'mr', pr_mr_number)
        else
            url = BuildUrl(info.provider, info.base_url, info.path, 'pr', pr_mr_number)
        endif
    else
        # Otherwise, open the commit
        url = BuildUrl(info.provider, info.base_url, info.path, 'commit', commit)
    endif
    
    OpenOrCopy(url, copy)
enddef
