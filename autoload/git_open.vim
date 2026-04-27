" autoload/git_open.vim - Core functionality for git_open plugin (legacy Vimscript)
" Maintainer:   Phong Nguyen
" Version:      1.0.0

" ============================================================================
" Helper Functions
" ============================================================================

function! s:Warn(msg) abort
    echohl ErrorMsg
    echom a:msg
    echohl None
endfunction

" Get the git root directory
function! s:GetGitRoot() abort
    " Step 1: FugitiveGitDir() — handles all fugitive virtual buffers
    if exists('*FugitiveGitDir')
        let l:gitdir = FugitiveGitDir()
        if !empty(l:gitdir)
            return fnamemodify(l:gitdir, ':h')
        endif
    endif
    " Step 2: finddir from the current buffer's directory
    let l:git_dir = finddir('.git', expand('%:p:h') . ';')
    if !empty(l:git_dir)
        return fnamemodify(l:git_dir, ':p:h')
    endif
    " Step 3: fallback to cwd — works in terminal/quickfix/empty buffers
    let l:git_dir = finddir('.git', getcwd() . ';')
    if !empty(l:git_dir)
        return fnamemodify(l:git_dir, ':p:h')
    endif
    return ''
endfunction

" Execute git command in the git root
function! s:GitCommand(args) abort
    let l:git_root = s:GetGitRoot()
    if empty(l:git_root)
        return ''
    endif

    let l:cmd = 'git -C ' . shellescape(l:git_root) . ' ' . a:args
    let l:output = system(l:cmd)
    return substitute(l:output, '\n\+$', '', '')
endfunction

function! s:GetAllRemoteNames(git_root) abort
    let l:output = trim(system('git -C ' . shellescape(a:git_root) . ' remote'))
    if empty(l:output)
        return []
    endif
    return filter(split(l:output, '\n'), '!empty(v:val)')
endfunction

function! s:GetCurrentRemote(git_root) abort
    " Step 1: already resolved for this buffer
    if exists('b:vim_git_open_remote') && !empty(b:vim_git_open_remote)
        return b:vim_git_open_remote
    endif

    let l:remotes = s:GetAllRemoteNames(a:git_root)
    if empty(l:remotes)
        return ''
    endif

    " Step 2: honour g:vim_git_open_remote if valid
    if exists('g:vim_git_open_remote') && !empty(g:vim_git_open_remote)
        if index(l:remotes, g:vim_git_open_remote) >= 0
            let b:vim_git_open_remote = g:vim_git_open_remote
            return b:vim_git_open_remote
        else
            if !exists('b:vim_git_open_remote_warned')
                call s:Warn("git-open: remote '" . g:vim_git_open_remote . "' not found, falling back")
                let b:vim_git_open_remote_warned = 1
            endif
        endif
    endif

    " Step 3: prefer 'origin'
    if index(l:remotes, 'origin') >= 0
        let b:vim_git_open_remote = 'origin'
        return b:vim_git_open_remote
    endif

    " Step 4: first available remote
    let b:vim_git_open_remote = l:remotes[0]
    return b:vim_git_open_remote
endfunction

" Parse remote URL using per-buffer remote resolution
function! s:ParseRemoteUrl() abort
    let l:git_root = s:GetGitRoot()
    let l:remote_name = empty(l:git_root) ? '' : s:GetCurrentRemote(l:git_root)
    if empty(l:remote_name)
        return {}
    endif
    let l:remote = s:GitCommand('config --get remote.' . l:remote_name . '.url')
    if empty(l:remote)
        return {}
    endif
    return s:ParseRemoteUrlString(l:remote)
endfunction

" Parse a raw remote URL string into {domain, path}
function! s:ParseRemoteUrlString(remote) abort
    " Handle SSH URLs: git@github.com:user/repo.git
    let l:ssh_match = matchlist(a:remote, '^\(git@\|ssh://git@\)\([^:\/]\+\)[:|/]\(.*\)\.git$')
    if !empty(l:ssh_match)
        return {'domain': l:ssh_match[2], 'path': l:ssh_match[3]}
    endif

    " Handle HTTPS URLs: https://github.com/user/repo.git
    let l:https_match = matchlist(a:remote, '^\(https\?://\)\([^/]\+\)/\(.*\)\(\.git\)\?$')
    if !empty(l:https_match)
        return {'domain': l:https_match[2], 'path': substitute(l:https_match[3], '\.git$', '', '')}
    endif

    return {}
endfunction

" Detect git provider from domain
function! s:DetectProvider(domain) abort
    " Check user-defined providers first
    if has_key(g:vim_git_open_providers, a:domain)
        return g:vim_git_open_providers[a:domain]
    endif

    if a:domain =~# 'github\.com'
        return 'GitHub'
    elseif a:domain =~# 'gitlab\.com'
        return 'GitLab'
    elseif a:domain =~# 'codeberg\.org'
        return 'Codeberg'
    endif

    " Default to GitHub for unknown providers
    return 'GitHub'
endfunction

" Get base URL for a domain
function! s:GetBaseUrl(domain) abort
    if has_key(g:vim_git_open_domains, a:domain)
        let l:mapped_url = g:vim_git_open_domains[a:domain]
        if l:mapped_url !~# '^\(https\?://\)'
            return 'https://' . l:mapped_url
        endif
        return l:mapped_url
    endif
    return 'https://' . a:domain
endfunction

" Get current git branch
function! s:GetCurrentBranch() abort
    return s:GitCommand('rev-parse --abbrev-ref HEAD')
endfunction

" Get current commit hash
function! s:GetCurrentCommit() abort
    return s:GitCommand('rev-parse HEAD')
endfunction

" Get file path relative to git root
function! s:GetRelativePath() abort
    let l:git_root = s:GetGitRoot()
    if empty(l:git_root)
        return ''
    endif

    let l:abs_path = expand('%:p')

    if l:git_root !~# '/$'
        let l:git_root = l:git_root . '/'
    endif

    return strpart(l:abs_path, len(l:git_root))
endfunction

" Get line number or range string
function! s:GetLineRange(line1, line2) abort
    if a:line1 == a:line2
        return a:line1
    endif
    return a:line1 . '-' . a:line2
endfunction

" Get repository info (domain, path, provider, base_url) for the current buffer's remote
function! s:GetRepoInfo() abort
    let l:remote = s:ParseRemoteUrl()
    if empty(l:remote)
        call s:Warn('Not a git repository or no remote configured')
        return {}
    endif

    let l:provider = s:DetectProvider(l:remote.domain)
    let l:base_url = s:GetBaseUrl(l:remote.domain)

    return {
        \ 'domain':   l:remote.domain,
        \ 'path':     l:remote.path,
        \ 'provider': l:provider,
        \ 'base_url': l:base_url
        \ }
endfunction

" Get repository info for a specific named remote (bypasses per-buffer resolution)
function! s:GetRepoInfoForRemote(remote_name) abort
    let l:remote_url = s:GitCommand('config --get remote.' . a:remote_name . '.url')
    if empty(l:remote_url)
        return {}
    endif

    let l:remote = s:ParseRemoteUrlString(l:remote_url)
    if empty(l:remote)
        return {}
    endif

    let l:provider = s:DetectProvider(l:remote.domain)
    let l:base_url = s:GetBaseUrl(l:remote.domain)

    return {
        \ 'domain':   l:remote.domain,
        \ 'path':     l:remote.path,
        \ 'provider': l:provider,
        \ 'base_url': l:base_url
        \ }
endfunction

" Get all non-origin remote names
function! s:GetAllRemotes() abort
    let l:output = s:GitCommand('remote')
    if empty(l:output)
        return []
    endif
    return filter(split(l:output, '\n'), 'v:val !=# ''origin''')
endfunction

" ============================================================================
" Provider Dispatch
"
" Each provider module (autoload/git_open/{github,gitlab,codeberg}.vim)
" implements the common interface (repo_info = {domain, path, provider, base_url}):
"   git_open#<provider>#ParseRequestNumber(message)
"   git_open#<provider>#BuildRepoUrl(repo_info)
"   git_open#<provider>#BuildBranchUrl(repo_info, branch)
"   git_open#<provider>#BuildFileUrl(repo_info, file, line_info, ref)
"   git_open#<provider>#BuildCommitUrl(repo_info, commit)
"   git_open#<provider>#BuildRequestUrl(repo_info, number)
"   git_open#<provider>#BuildRequestsUrl(repo_info, state_arg)
"   git_open#<provider>#BuildMyRequestsUrl(repo_info, state_arg)
"
" s:ProviderFunction(provider, func) resolves the fully-qualified function name.
" s:CallProvider(provider, func, args) dispatches the call.
" ============================================================================

function! s:ProviderFunc(provider, func) abort
    if a:provider ==# 'GitLab'
        return 'git_open#gitlab#' . a:func
    elseif a:provider ==# 'Codeberg'
        return 'git_open#codeberg#' . a:func
    else
        return 'git_open#github#' . a:func
    endif
endfunction

function! s:CallProvider(provider, func, args) abort
    return call(s:ProviderFunc(a:provider, a:func), a:args)
endfunction

function! s:ParseRequestNumberFromCommit(provider) abort
    let l:msg = s:GitCommand('log -1 --pretty=%B')
    return s:CallProvider(a:provider, 'ParseRequestNumber', [l:msg])
endfunction

" ============================================================================
" Browser Functions
" ============================================================================

function! s:OpenBrowser(url) abort
    if empty(a:url)
        return
    endif

    if empty(g:vim_git_open_browser_command)
        call s:Warn('No browser command configured. Set g:vim_git_open_browser_command')
        return
    endif

    if has('win32') || has('win64')
        let l:cmd = '!start "" ' . shellescape(a:url)
    else
        let l:cmd = g:vim_git_open_browser_command . ' ' . shellescape(a:url) . ' > /dev/null 2>&1'
    endif

    silent call system(l:cmd)
    redraw!
    echo 'Opened: ' . a:url
endfunction

function! s:CopyToClipboard(url) abort
    if empty(a:url)
        return
    endif

    call setreg('+', a:url)
    call setreg('*', a:url)
    redraw!
    echo 'Copied: ' . a:url
endfunction

function! s:OpenOrCopy(url, copy) abort
    if a:copy
        call s:CopyToClipboard(a:url)
    else
        call s:OpenBrowser(a:url)
    endif
endfunction

" ============================================================================
" Completion Helpers
" ============================================================================

function! s:GetVisualSelection() abort
    if exists('*getregion')
        return trim(join(getregion(getpos("'<"), getpos("'>")), "\n"))
    endif
    let l:line = getline("'<")
    let [l:_b, l:l1, l:c1, l:_o] = getpos("'<")
    let [l:_b, l:l2, l:c2, l:_o] = getpos("'>")
    if l:l1 != l:l2
        return trim(strpart(l:line, l:c1 - 1))
    endif
    return trim(strpart(l:line, l:c1 - 1, l:c2 - l:c1 + 1))
endfunction

function! s:Unique(items) abort
    let l:seen = {}
    let l:result = []
    for l:item in a:items
        if !has_key(l:seen, l:item)
            let l:seen[l:item] = 1
            call add(l:result, l:item)
        endif
    endfor
    return l:result
endfunction

function! s:FuzzyFilter(result, arglead) abort
    if empty(a:arglead)
        return a:result
    endif
    if exists('*matchfuzzy')
        return matchfuzzy(a:result, a:arglead)
    endif
    return filter(copy(a:result), 'v:val =~# ''^'' . escape(a:arglead, ''\/.*[]^$~'')')
endfunction

" ============================================================================
" Completion Functions (public autoload API)
" ============================================================================

function! git_open#CompleteBranch(arglead, cmdline, cursorpos) abort
    let l:local_raw  = s:GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    let l:remote_raw = s:GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/")
    let l:local  = empty(l:local_raw)  ? [] : split(l:local_raw, '\n')
    let l:remote = empty(l:remote_raw) ? [] : filter(split(l:remote_raw, '\n'), 'v:val !=# ''HEAD''')
    return s:FuzzyFilter(s:Unique(l:local + l:remote), a:arglead)
endfunction

function! git_open#CompleteGitkBranch(arglead, cmdline, cursorpos) abort
    let l:local_raw  = s:GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    let l:remote_raw = s:GitCommand("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/remotes/")
    let l:local  = empty(l:local_raw)  ? [] : split(l:local_raw, '\n')
    let l:remote = empty(l:remote_raw) ? [] : filter(split(l:remote_raw, '\n'), 'v:val !~# ''/HEAD$''')
    return s:FuzzyFilter(s:Unique(l:local + l:remote), a:arglead)
endfunction

function! git_open#CompleteGitkArgs(arglead, cmdline, cursorpos) abort
    let l:branches  = git_open#CompleteGitkBranch('', '', 0)
    let l:files_raw = s:GitCommand('ls-files')
    let l:files     = empty(l:files_raw) ? [] : split(l:files_raw, '\n')
    return s:FuzzyFilter(s:Unique(l:branches + l:files), a:arglead)
endfunction

function! git_open#CompleteRequestState(arglead, cmdline, cursorpos) abort
    return s:FuzzyFilter(['-open', '-closed', '-merged', '-all'], a:arglead)
endfunction

function! git_open#CompleteMyRequestState(arglead, cmdline, cursorpos) abort
    return s:FuzzyFilter(['-open', '-closed', '-merged', '-all',
                \ '-search', '-search=open', '-search=closed', '-search=merged', '-search=all'], a:arglead)
endfunction

function! git_open#CompleteGitRemote(arglead, cmdline, cursorpos) abort
    let l:git_root = s:GetGitRoot()
    if empty(l:git_root)
        return []
    endif
    return s:FuzzyFilter(s:GetAllRemoteNames(l:git_root), a:arglead)
endfunction

" ============================================================================
" :OpenGitRemote command
" ============================================================================

function! git_open#OpenBrowser(url) abort
    call s:OpenBrowser(a:url)
endfunction

function! git_open#OpenGitRemote(name, reset) abort
    let l:git_root = s:GetGitRoot()
    if empty(l:git_root)
        call s:Warn('git-open: not a git repository')
        return
    endif

    if a:reset
        if exists('b:vim_git_open_remote')
            unlet b:vim_git_open_remote
        endif
        if exists('b:vim_git_open_remote_warned')
            unlet b:vim_git_open_remote_warned
        endif
        echo 'git-open: remote reset (will re-resolve on next command)'
        return
    endif

    if empty(a:name)
        let l:current = s:GetCurrentRemote(l:git_root)
        if empty(l:current)
            call s:Warn('git-open: no remotes found')
        else
            echo "git-open: current remote is '" . l:current . "'"
        endif
        return
    endif

    let l:remotes = s:GetAllRemoteNames(l:git_root)
    if index(l:remotes, a:name) < 0
        call s:Warn("git-open: remote '" . a:name . "' not found (available: " . join(l:remotes, ', ') . ')')
        return
    endif
    let b:vim_git_open_remote = a:name
    if exists('b:vim_git_open_remote_warned')
        unlet b:vim_git_open_remote_warned
    endif
    echo "git-open: remote set to '" . a:name . "' for this buffer"
endfunction

" ============================================================================
" Public API — primary remote commands
" ============================================================================

function! git_open#OpenRepo(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildRepoUrl', [l:repo_info])
    call s:OpenOrCopy(l:url, a:0 > 0 && a:1)
endfunction

function! git_open#OpenBranch(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    let l:branch = a:0 > 0 ? a:1 : ''
    let l:copy   = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3

    if empty(l:branch) && l:visual
        let l:branch = s:GetVisualSelection()
    endif
    if empty(l:branch)
        let l:branch = s:GetCurrentBranch()
    endif

    let l:url = s:CallProvider(l:repo_info.provider, 'BuildBranchUrl', [l:repo_info, l:branch])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenFile(line1, line2, ...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    if empty(expand('%'))
        call s:Warn('No file in current buffer')
        return
    endif

    let l:line_range = s:GetLineRange(a:line1, a:line2)
    let l:ref  = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2

    let l:file = s:GetRelativePath()
    let l:ref  = empty(l:ref) ? s:GetCurrentCommit() : l:ref

    let l:url = s:CallProvider(l:repo_info.provider, 'BuildFileUrl',
                \ [l:repo_info, l:file, l:line_range, l:ref])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenCommit(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    let l:commit = a:0 > 0 ? a:1 : ''
    let l:copy   = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3

    if empty(l:commit) && l:visual
        let l:commit = s:GetVisualSelection()
    endif
    if empty(l:commit)
        let l:commit = s:GetCurrentCommit()
    endif

    let l:url = s:CallProvider(l:repo_info.provider, 'BuildCommitUrl', [l:repo_info, l:commit])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenRequest(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    let l:number = a:0 > 0 && !empty(a:1) ? a:1 : s:ParseRequestNumberFromCommit(l:repo_info.provider)
    let l:copy   = a:0 > 1 && a:2

    if empty(l:number)
        call s:Warn('No request number specified and could not parse from commit message')
        return
    endif

    let l:url = s:CallProvider(l:repo_info.provider, 'BuildRequestUrl', [l:repo_info, l:number])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenFileLastChange(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    let l:file_path = s:GetRelativePath()
    if empty(l:file_path)
        call s:Warn('Current file is not in a git repository')
        return
    endif

    let l:commit = s:GitCommand('log -1 --format=%H -- ' . shellescape(l:file_path))
    if empty(l:commit)
        call s:Warn('No commits found for current file')
        return
    endif

    let l:message = s:GitCommand('log -1 --format=%B ' . l:commit)
    let l:pr_mr_number = s:CallProvider(l:repo_info.provider, 'ParseRequestNumber', [l:message])

    if !empty(l:pr_mr_number)
        let l:url = s:CallProvider(l:repo_info.provider, 'BuildRequestUrl',
                    \ [l:repo_info, l:pr_mr_number])
    else
        let l:url = s:CallProvider(l:repo_info.provider, 'BuildCommitUrl',
                    \ [l:repo_info, l:commit])
    endif

    call s:OpenOrCopy(l:url, a:0 > 0 && a:1)
endfunction

function! git_open#OpenRequests(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    let l:state_arg = a:0 > 0 ? a:1 : ''
    let l:copy      = a:0 > 1 && a:2

    let l:url = s:CallProvider(l:repo_info.provider, 'BuildRequestsUrl',
                \ [l:repo_info, l:state_arg])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenMyRequests(...) abort
    let l:repo_info = s:GetRepoInfo()
    if empty(l:repo_info)
        return
    endif

    let l:state_arg = a:0 > 0 ? a:1 : ''
    let l:copy      = a:0 > 1 && a:2

    let l:url = s:CallProvider(l:repo_info.provider, 'BuildMyRequestsUrl',
                \ [l:repo_info, l:state_arg])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

" ============================================================================
" Gitk Functions
" ============================================================================

function! s:LaunchGitk(args, git_root) abort
    if !executable('gitk')
        call s:Warn('git-open: gitk not found in PATH')
        return
    endif
    if has('job')
        call job_start(['gitk'] + a:args, {'cwd': a:git_root, 'stoponexit': ''})
    else
        let l:escaped = join(map(copy(a:args), 'shellescape(v:val)'))
        silent call system('cd ' . shellescape(a:git_root) . ' && gitk ' . l:escaped . ' &')
        redraw!
    endif
endfunction

function! s:GetGitkOldPaths(rel_path) abort
    let l:output = s:GitCommand('log --follow --name-only --format= -- ' . shellescape(a:rel_path))
    if empty(l:output)
        return [a:rel_path]
    endif
    let l:paths = s:Unique(filter(split(l:output, '\n'), '!empty(v:val)'))
    return empty(l:paths) ? [a:rel_path] : l:paths
endfunction

function! git_open#OpenGitk(...) abort
    let l:git_root = s:GetGitRoot()
    if empty(l:git_root)
        call s:Warn('git-open: not a git repository')
        return
    endif
    let l:args_str = a:0 > 0 ? a:1 : ''
    let l:args = empty(l:args_str) ? [] : split(l:args_str)
    call s:LaunchGitk(l:args, l:git_root)
endfunction

function! git_open#OpenGitkFile(...) abort
    let l:git_root = s:GetGitRoot()
    if empty(l:git_root)
        call s:Warn('git-open: not a git repository')
        return
    endif
    if empty(expand('%'))
        call s:Warn('git-open: no file in current buffer')
        return
    endif
    let l:opts_str = a:0 > 0 ? a:1 : ''
    let l:history  = a:0 > 1 ? a:2 : 0
    let l:rel_path = s:GetRelativePath()
    let l:paths    = l:history ? s:GetGitkOldPaths(l:rel_path) : [l:rel_path]
    let l:extra_args = empty(l:opts_str) ? [] : split(l:opts_str)
    call s:LaunchGitk(l:extra_args + ['--'] + l:paths, l:git_root)
endfunction

" ============================================================================
" Multi-Remote Public API
" ============================================================================

function! git_open#GetAllRemotes() abort
    return s:GetAllRemotes()
endfunction

function! git_open#GetRepoInfo() abort
    return s:GetRepoInfo()
endfunction

function! git_open#GetRepoInfoForRemote(remote_name) abort
    return s:GetRepoInfoForRemote(a:remote_name)
endfunction

function! git_open#OpenRepoForRemote(remote_name, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildRepoUrl', [l:repo_info])
    call s:OpenOrCopy(l:url, a:0 > 0 && a:1)
endfunction

function! git_open#OpenBranchForRemote(remote_name, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:branch = a:0 > 0 ? a:1 : ''
    let l:copy   = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3
    if empty(l:branch) && l:visual
        let l:branch = s:GetVisualSelection()
    endif
    if empty(l:branch)
        let l:branch = s:GetCurrentBranch()
    endif
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildBranchUrl', [l:repo_info, l:branch])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenFileForRemote(remote_name, line1, line2, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    if empty(expand('%'))
        call s:Warn('No file in current buffer')
        return
    endif
    let l:line_range = s:GetLineRange(a:line1, a:line2)
    let l:ref  = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2
    let l:file = s:GetRelativePath()
    let l:ref  = empty(l:ref) ? s:GetCurrentCommit() : l:ref
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildFileUrl',
                \ [l:repo_info, l:file, l:line_range, l:ref])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenCommitForRemote(remote_name, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:commit = a:0 > 0 ? a:1 : ''
    let l:copy   = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3
    if empty(l:commit) && l:visual
        let l:commit = s:GetVisualSelection()
    endif
    if empty(l:commit)
        let l:commit = s:GetCurrentCommit()
    endif
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildCommitUrl', [l:repo_info, l:commit])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenRequestForRemote(remote_name, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:number = a:0 > 0 && !empty(a:1) ? a:1 : s:ParseRequestNumberFromCommit(l:repo_info.provider)
    let l:copy   = a:0 > 1 && a:2
    if empty(l:number)
        call s:Warn('No request number specified and could not parse from commit message')
        return
    endif
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildRequestUrl', [l:repo_info, l:number])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenRequestsForRemote(remote_name, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:state_arg = a:0 > 0 ? a:1 : ''
    let l:copy      = a:0 > 1 && a:2
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildRequestsUrl',
                \ [l:repo_info, l:state_arg])
    call s:OpenOrCopy(l:url, l:copy)
endfunction

function! git_open#OpenMyRequestsForRemote(remote_name, ...) abort
    let l:repo_info = s:GetRepoInfoForRemote(a:remote_name)
    if empty(l:repo_info)
        call s:Warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:state_arg = a:0 > 0 ? a:1 : ''
    let l:copy      = a:0 > 1 && a:2
    let l:url = s:CallProvider(l:repo_info.provider, 'BuildMyRequestsUrl',
                \ [l:repo_info, l:state_arg])
    call s:OpenOrCopy(l:url, l:copy)
endfunction
