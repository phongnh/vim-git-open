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
    # Step 1: FugitiveGitDir() — handles all fugitive virtual buffers
    # (fugitiveblame, fugitive://, etc.).
    # exists('*FugitiveGitDir') is resolved at compile time inside a def and
    # always returns false for late-loaded plugins. Use try/call() instead so
    # the lookup happens at runtime on every call.
    try
        var gitdir = '' .. call('FugitiveGitDir', [])
        if !empty(gitdir)
            return fnamemodify(gitdir, ':h')
        endif
    catch
    endtry
    # Step 2: finddir from the current buffer's directory
    var git_dir = finddir('.git', expand('%:p:h') .. ';')
    if !empty(git_dir)
        return fnamemodify(git_dir, ':p:h')
    endif
    # Step 3: fallback to cwd — works in terminal/quickfix/empty buffers
    git_dir = finddir('.git', getcwd() .. ';')
    if !empty(git_dir)
        return fnamemodify(git_dir, ':p:h')
    endif
    return ''
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

def GetAllRemoteNames(git_root: string): list<string>
    var output = trim(system('git -C ' .. shellescape(git_root) .. ' remote'))
    if empty(output)
        return []
    endif
    return filter(split(output, '\n'), (_, v) => !empty(v))
enddef

def GetCurrentRemote(git_root: string): string
    # Step 1: already resolved for this buffer
    if exists('b:vim_git_open_remote') && !empty(b:vim_git_open_remote)
        return b:vim_git_open_remote
    endif

    var remotes = GetAllRemoteNames(git_root)
    if empty(remotes)
        return ''
    endif

    # Step 2: honour g:vim_git_open_remote if valid
    if exists('g:vim_git_open_remote') && !empty(g:vim_git_open_remote)
        if index(remotes, g:vim_git_open_remote) >= 0
            b:vim_git_open_remote = g:vim_git_open_remote
            return b:vim_git_open_remote
        else
            # Warn once per buffer then fall through
            if !exists('b:vim_git_open_remote_warned')
                Warn("git-open: remote '" .. g:vim_git_open_remote .. "' not found, falling back")
                b:vim_git_open_remote_warned = 1
            endif
        endif
    endif

    # Step 3: prefer 'origin'
    if index(remotes, 'origin') >= 0
        b:vim_git_open_remote = 'origin'
        return b:vim_git_open_remote
    endif

    # Step 4: first available remote
    b:vim_git_open_remote = remotes[0]
    return b:vim_git_open_remote
enddef

# ParseRemoteUrl: uses per-buffer remote resolution (GetCurrentRemote)
def ParseRemoteUrl(): dict<string>
    var git_root = GetGitRoot()
    var remote_name = empty(git_root) ? '' : GetCurrentRemote(git_root)
    if empty(remote_name)
        return {}
    endif
    var remote = GitCommand('config --get remote.' .. remote_name .. '.url')
    if empty(remote)
        return {}
    endif
    return ParseRemoteUrlString(remote)
enddef

# Parse a raw remote URL string into {domain, path}
def ParseRemoteUrlString(remote: string): dict<string>
    # Handle SSH URLs: git@github.com:user/repo.git
    var ssh_match = matchlist(remote, '^\%(git@\|ssh://git@\)\([^:\/]\+\)[:|/]\(.*\)\.git$')
    if !empty(ssh_match)
        return {domain: ssh_match[1], path: ssh_match[2]}
    endif

    # Handle HTTPS URLs: https://github.com/user/repo.git
    var https_match = matchlist(remote, '^\%(https\?://\)\([^/]\+\)/\(.*\)\%(\.git\)\?$')
    if !empty(https_match)
        return {domain: https_match[1], path: substitute(https_match[2], '\.git$', '', '')}
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

    return strpart(abs_path, len(git_root))
enddef

def GetLineRange(line1: number, line2: number): string
    if line1 == line2
        return '' .. line1
    else
        return line1 .. '-' .. line2
    endif
enddef

def GetRepoInfoDict(remote: dict<string>): dict<string>
    var provider = DetectProvider(remote.domain)
    var base_url = GetBaseUrl(remote.domain)
    return {
        domain:   remote.domain,
        path:     remote.path,
        provider: provider,
        base_url: base_url
    }
enddef

# Get repository info (domain, path, provider, base_url) for the current buffer's remote
def GetRepoInfoPrivate(): dict<string>
    var remote = ParseRemoteUrl()
    if empty(remote)
        Warn('Not a git repository or no remote configured')
        return {}
    endif
    return GetRepoInfoDict(remote)
enddef

# Get repository info for a specific named remote (bypasses per-buffer resolution)
def GetRepoInfoForRemotePrivate(remote_name: string): dict<string>
    var remote_url = GitCommand('config --get remote.' .. remote_name .. '.url')
    if empty(remote_url)
        return {}
    endif
    var remote = ParseRemoteUrlString(remote_url)
    if empty(remote)
        return {}
    endif
    return GetRepoInfoDict(remote)
enddef

# Get all non-origin remote names
def GetAllRemotesPrivate(): list<string>
    var output = GitCommand('remote')
    if empty(output)
        return []
    endif
    return filter(split(output, '\n'), (_, v) => v !=# 'origin')
enddef

# ============================================================================
# Provider Dispatch
#
# Each provider module (vim9/autoload/git_open/{github,gitlab,codeberg}.vim)
# implements the common interface (repo_info = {domain, path, provider, base_url}):
#   git_open#<provider>#ParseRequestNumber(message)
#   git_open#<provider>#BuildRepoUrl(repo_info)
#   git_open#<provider>#BuildBranchUrl(repo_info, branch)
#   git_open#<provider>#BuildFileUrl(repo_info, file, line_info, ref)
#   git_open#<provider>#BuildCommitUrl(repo_info, commit)
#   git_open#<provider>#BuildRequestUrl(repo_info, number)
#   git_open#<provider>#BuildRequestsUrl(repo_info, state_arg)
#   git_open#<provider>#BuildMyRequestsUrl(repo_info, state_arg)
#
# ProviderFunction(provider, func) resolves the fully-qualified function name.
# CallProvider(provider, func, args) dispatches the call.
# ============================================================================

def ProviderFunction(provider: string, func: string): string
    if provider ==# 'GitLab'
        return 'git_open#gitlab#' .. func
    elseif provider ==# 'Codeberg'
        return 'git_open#codeberg#' .. func
    else
        return 'git_open#github#' .. func
    endif
enddef

def CallProvider(provider: string, func: string, args: list<any>): any
    return call(ProviderFunction(provider, func), args)
enddef

def ParseRequestNumberFromCommit(provider: string): string
    var msg = GitCommand('log -1 --pretty=%B')
    return CallProvider(provider, 'ParseRequestNumber', [msg])
enddef

# ============================================================================
# Browser Functions
# ============================================================================

export def OpenBrowser(url: string)
    if empty(url)
        return
    endif

    if empty(g:vim_git_open_browser_command)
        Warn('No browser command configured. Set g:vim_git_open_browser_command')
        return
    endif

    var cmd: string
    if has('win32') || has('win64')
        cmd = 'start "" ' .. shellescape(url)
    else
        cmd = g:vim_git_open_browser_command .. ' ' .. shellescape(url) .. ' > /dev/null 2>&1'
    endif

    silent call system(cmd)
    redraw!
    echo 'Opened: ' .. url
enddef

def CopyToClipboard(url: string)
    if empty(url)
        return
    endif

    setreg('+', url)
    setreg('*', url)
    echo 'Copied: ' .. url
enddef

def OpenOrCopy(url: string, copy: bool)
    if copy
        CopyToClipboard(url)
    else
        OpenBrowser(url)
    endif
enddef

# ============================================================================
# Completion Helpers
# ============================================================================

def GetVisualSelection(): string
    if exists('*getregion')
        return trim(join(call('getregion', [getpos("'<"), getpos("'>")]), "\n"))
    endif
    const line = getline("'<")
    const [_b1, l1, c1, _o1] = getpos("'<")
    const [_b2, l2, c2, _o2] = getpos("'>")
    if l1 != l2
        return trim(strpart(line, c1 - 1))
    endif
    return trim(strpart(line, c1 - 1, c2 - c1 + 1))
enddef

def Unique(items: list<string>): list<string>
    var seen: dict<bool> = {}
    var result: list<string> = []
    for item in items
        if !has_key(seen, item)
            seen[item] = true
            result->add(item)
        endif
    endfor
    return result
enddef

def FuzzyFilter(result: list<string>, arglead: string): list<string>
    if empty(arglead)
        return result
    endif
    return matchfuzzy(result, arglead)
enddef

# ============================================================================
# Completion Functions (public autoload API)
# ============================================================================

export def CompleteBranch(arglead: string, cmdline: string, cursorpos: number): list<string>
    # Local branches sorted by most recent commit (-committerdate)
    var local_raw = GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    # Remote branches sorted by most recent commit, strip refs/remotes/<remote>/
    var remote_raw = GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/")
    var local = empty(local_raw) ? [] : split(local_raw, '\n')
    var remote = empty(remote_raw) ? [] : filter(split(remote_raw, '\n'), (_, v) => v !=# 'HEAD')
    return FuzzyFilter(Unique(local + remote), arglead)
enddef

export def CompleteGitkBranch(arglead: string, cmdline: string, cursorpos: number): list<string>
    # Local branches (plain name), then remote branches with full remote/ prefix
    # e.g. main, origin/main, origin/feature
    var local_raw = GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    var remote_raw = GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/remotes/")
    var local = empty(local_raw) ? [] : split(local_raw, '\n')
    var remote = empty(remote_raw) ? [] : filter(split(remote_raw, '\n'), (_, v) => v !~# '/HEAD$')
    return FuzzyFilter(Unique(local + remote), arglead)
enddef

export def CompleteGitkArgs(arglead: string, cmdline: string, cursorpos: number): list<string>
    # Branches (local plain + remote with prefix) then tracked files
    var branches = CompleteGitkBranch('', '', 0)
    var files_raw = GitCommand('ls-files')
    var files = empty(files_raw) ? [] : split(files_raw, '\n')
    return FuzzyFilter(Unique(branches + files), arglead)
enddef

export def CompleteRequestState(arglead: string, cmdline: string, cursorpos: number): list<string>
    return FuzzyFilter(['-open', '-closed', '-merged', '-all'], arglead)
enddef

export def CompleteMyRequestState(arglead: string, cmdline: string, cursorpos: number): list<string>
    return FuzzyFilter(['-open', '-closed', '-merged', '-all',
                '-search', '-search=open', '-search=closed', '-search=merged', '-search=all'], arglead)
enddef

export def CompleteGitRemote(arglead: string, cmdline: string, cursorpos: number): list<string>
    var git_root = GetGitRoot()
    if empty(git_root)
        return []
    endif
    return FuzzyFilter(GetAllRemoteNames(git_root), arglead)
enddef

# :OpenGitRemote command
# ============================================================================

export def OpenGitRemote(name: string = '', reset: bool = false)
    var git_root = GetGitRoot()
    if empty(git_root)
        Warn('git-open: not a git repository')
        return
    endif

    if reset
        if exists('b:vim_git_open_remote')
            unlet b:vim_git_open_remote
        endif
        if exists('b:vim_git_open_remote_warned')
            unlet b:vim_git_open_remote_warned
        endif
        echo 'git-open: remote reset (will re-resolve on next command)'
        return
    endif

    if empty(name)
        var current = GetCurrentRemote(git_root)
        if empty(current)
            Warn('git-open: no remotes found')
        else
            echo "git-open: current remote is '" .. current .. "'"
        endif
        return
    endif

    var remotes = GetAllRemoteNames(git_root)
    if index(remotes, name) < 0
        Warn("git-open: remote '" .. name .. "' not found (available: " .. join(remotes, ', ') .. ')')
        return
    endif
    b:vim_git_open_remote = name
    if exists('b:vim_git_open_remote_warned')
        unlet b:vim_git_open_remote_warned
    endif
    echo "git-open: remote set to '" .. name .. "' for this buffer"
enddef

# ============================================================================
# Public API — primary remote commands
# ============================================================================

export def GetRepoInfo(): dict<string>
    return GetRepoInfoPrivate()
enddef

export def GetAllRemotes(): list<string>
    return GetAllRemotesPrivate()
enddef

export def GetRepoInfoForRemote(remote_name: string): dict<string>
    return GetRepoInfoForRemotePrivate(remote_name)
enddef

export def OpenRepo(copy: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif
    var url = CallProvider(repo_info.provider, 'BuildRepoUrl', [repo_info])
    OpenOrCopy(url, copy)
enddef

export def OpenBranch(branch_arg: string = '', copy: bool = false, visual: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    var branch = branch_arg
    if empty(branch) && visual
        branch = GetVisualSelection()
    endif
    if empty(branch)
        branch = GetCurrentBranch()
    endif

    var url = CallProvider(repo_info.provider, 'BuildBranchUrl', [repo_info, branch])
    OpenOrCopy(url, copy)
enddef

export def OpenFile(line1: number, line2: number, ref_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    if empty(expand('%'))
        Warn('No file in current buffer')
        return
    endif

    var line_range = GetLineRange(line1, line2)
    var file = GetRelativePath()
    var ref = empty(ref_arg) ? GetCurrentCommit() : ref_arg

    var url = CallProvider(repo_info.provider, 'BuildFileUrl', [repo_info, file, line_range, ref])
    OpenOrCopy(url, copy)
enddef

export def OpenCommit(commit_arg: string = '', copy: bool = false, visual: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    var commit = commit_arg
    if empty(commit) && visual
        commit = GetVisualSelection()
    endif
    if empty(commit)
        commit = GetCurrentCommit()
    endif

    var url = CallProvider(repo_info.provider, 'BuildCommitUrl', [repo_info, commit])
    OpenOrCopy(url, copy)
enddef

export def OpenRequest(req_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    var number = !empty(req_arg) ? req_arg : ParseRequestNumberFromCommit(repo_info.provider)

    if empty(number)
        Warn('No request number specified and could not parse from commit message')
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildRequestUrl', [repo_info, number])
    OpenOrCopy(url, copy)
enddef

export def OpenFileLastChange(copy: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    var file_path = GetRelativePath()
    if empty(file_path)
        Warn('Current file is not in a git repository')
        return
    endif

    var commit = GitCommand('log -1 --format=%H -- ' .. shellescape(file_path))
    if empty(commit)
        Warn('No commits found for current file')
        return
    endif

    var message = GitCommand('log -1 --format=%B ' .. commit)
    var pr_mr_number = CallProvider(repo_info.provider, 'ParseRequestNumber', [message])

    var url: string
    if !empty(pr_mr_number)
        url = CallProvider(repo_info.provider, 'BuildRequestUrl', [repo_info, pr_mr_number])
    else
        url = CallProvider(repo_info.provider, 'BuildCommitUrl', [repo_info, commit])
    endif

    OpenOrCopy(url, copy)
enddef

export def OpenRequests(state_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildRequestsUrl', [repo_info, state_arg])
    OpenOrCopy(url, copy)
enddef

export def OpenMyRequests(state_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoPrivate()
    if empty(repo_info)
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildMyRequestsUrl', [repo_info, state_arg])
    OpenOrCopy(url, copy)
enddef

# ============================================================================
# Per-Remote Public API Functions
# ============================================================================

export def OpenRepoForRemote(remote_name: string, copy: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildRepoUrl', [repo_info])
    OpenOrCopy(url, copy)
enddef

export def OpenBranchForRemote(remote_name: string, branch_arg: string = '', copy: bool = false, visual: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    var branch = branch_arg
    if empty(branch) && visual
        branch = GetVisualSelection()
    endif
    if empty(branch)
        branch = GetCurrentBranch()
    endif

    var url = CallProvider(repo_info.provider, 'BuildBranchUrl', [repo_info, branch])
    OpenOrCopy(url, copy)
enddef

export def OpenFileForRemote(remote_name: string, line1: number, line2: number, ref_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    if empty(expand('%'))
        Warn('No file in current buffer')
        return
    endif

    var line_range = GetLineRange(line1, line2)
    var file = GetRelativePath()
    var ref = empty(ref_arg) ? GetCurrentCommit() : ref_arg

    var url = CallProvider(repo_info.provider, 'BuildFileUrl', [repo_info, file, line_range, ref])
    OpenOrCopy(url, copy)
enddef

export def OpenCommitForRemote(remote_name: string, commit_arg: string = '', copy: bool = false, visual: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    var commit = commit_arg
    if empty(commit) && visual
        commit = GetVisualSelection()
    endif
    if empty(commit)
        commit = GetCurrentCommit()
    endif

    var url = CallProvider(repo_info.provider, 'BuildCommitUrl', [repo_info, commit])
    OpenOrCopy(url, copy)
enddef

export def OpenRequestForRemote(remote_name: string, req_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    var number = !empty(req_arg) ? req_arg : ParseRequestNumberFromCommit(repo_info.provider)

    if empty(number)
        Warn('No request number specified and could not parse from commit message')
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildRequestUrl', [repo_info, number])
    OpenOrCopy(url, copy)
enddef

export def OpenRequestsForRemote(remote_name: string, state_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildRequestsUrl', [repo_info, state_arg])
    OpenOrCopy(url, copy)
enddef

export def OpenMyRequestsForRemote(remote_name: string, state_arg: string = '', copy: bool = false)
    var repo_info = GetRepoInfoForRemotePrivate(remote_name)
    if empty(repo_info)
        Warn('No remote configured for: ' .. remote_name)
        return
    endif

    var url = CallProvider(repo_info.provider, 'BuildMyRequestsUrl', [repo_info, state_arg])
    OpenOrCopy(url, copy)
enddef

# ============================================================================
# Gitk Functions
# ============================================================================

def LaunchGitk(args: list<string>, git_root: string)
    if !executable('gitk')
        Warn('git-open: gitk not found in PATH')
        return
    endif
    if exists(':Launch') == 2
        # Vim 9.2+ built-in cross-platform GUI launcher (plugin/openPlugin.vim)
        # :Launch does not support cwd, so temporarily cd to git root.
        # On Unix, dist#vim9#Launch calls job_start(split(args)) — do NOT
        # shellescape individual args or the quotes become literal characters.
        var save_dir = getcwd()
        try
            noautocmd silent execute 'lcd ' .. fnameescape(git_root)
            execute 'Launch gitk ' .. join(args)
        finally
            noautocmd silent execute 'lcd ' .. fnameescape(save_dir)
        endtry
    elseif has('job')
        # Vim 8.0+ job_start with cwd support
        job_start(['gitk'] + args, {cwd: git_root, stoponexit: ''})
    else
        # Vim 7 fallback: shell background
        var escaped = join(map(copy(args), (_, v) => shellescape(v)))
        silent call system('cd ' .. shellescape(git_root) .. ' && gitk ' .. escaped .. ' &')
        redraw!
    endif
enddef

def GetGitkOldPaths(rel_path: string): list<string>
    # Collect all historical paths this file has had (follows renames)
    var output = GitCommand('log --follow --name-only --format= -- ' .. shellescape(rel_path))
    if empty(output)
        return [rel_path]
    endif
    var paths = Unique(filter(split(output, '\n'), (_, v) => !empty(v)))
    return empty(paths) ? [rel_path] : paths
enddef

export def OpenGitk(args_str: string = '')
    var git_root = GetGitRoot()
    if empty(git_root)
        Warn('git-open: not a git repository')
        return
    endif
    LaunchGitk(empty(args_str) ? [] : split(args_str), git_root)
enddef

export def OpenGitkFile(opts_str: string = '', history: bool = false)
    var git_root = GetGitRoot()
    if empty(git_root)
        Warn('git-open: not a git repository')
        return
    endif
    if empty(expand('%'))
        Warn('git-open: no file in current buffer')
        return
    endif
    var rel_path = GetRelativePath()
    var paths = history ? GetGitkOldPaths(rel_path) : [rel_path]
    var extra_args = empty(opts_str) ? [] : split(opts_str)
    LaunchGitk(extra_args + ['--'] + paths, git_root)
enddef
