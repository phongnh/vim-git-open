" autoload/git_open/legacy.vim - Core functionality for git_open plugin (legacy Vimscript)
" Maintainer:   Phong Nguyen
" Version:      1.0.0

" Save cpoptions
let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" Helper Functions
" ============================================================================

function! s:warn(msg) abort
    echohl ErrorMsg
    echom a:msg
    echohl None
endfunction

" Get the git root directory
function! s:get_git_root() abort
    let l:git_dir = finddir('.git', expand('%:p:h') . ';')
    if empty(l:git_dir)
        return ''
    endif
    " Get absolute path to .git directory, then get its parent
    let l:abs_git_dir = fnamemodify(l:git_dir, ':p')
    " Remove trailing slash and .git
    let l:abs_git_dir = substitute(l:abs_git_dir, '/$', '', '')
    let l:root = fnamemodify(l:abs_git_dir, ':h')
    return l:root
endfunction

" Execute git command in the git root
function! s:git_command(args) abort
    let l:git_root = s:get_git_root()
    if empty(l:git_root)
        return ''
    endif

    let l:cmd = 'git -C ' . shellescape(l:git_root) . ' ' . a:args
    let l:output = system(l:cmd)
    return substitute(l:output, '\n\+$', '', '')
endfunction

" Parse git remote URL
function! s:parse_remote_url() abort
    let l:remote = s:git_command('config --get remote.origin.url')
    if empty(l:remote)
        return {}
    endif

    let l:result = {}

    " Handle SSH URLs: git@github.com:user/repo.git
    let l:ssh_match = matchlist(l:remote, '^\(git@\|ssh://git@\)\([^:\/]\+\)[:|/]\(.*\)\.git$')
    if !empty(l:ssh_match)
        let l:result.domain = l:ssh_match[2]
        let l:result.path = l:ssh_match[3]
        return l:result
    endif

    " Handle HTTPS URLs: https://github.com/user/repo.git
    let l:https_match = matchlist(l:remote, '^\(https\?://\)\([^/]\+\)/\(.*\)\(\.git\)\?$')
    if !empty(l:https_match)
        let l:result.domain = l:https_match[2]
        let l:result.path = substitute(l:https_match[3], '\.git$', '', '')
        return l:result
    endif

    return {}
endfunction

" Detect git provider from domain
function! s:detect_provider(domain) abort
    " Check user-defined providers first
    if has_key(g:vim_git_open_providers, a:domain)
        return g:vim_git_open_providers[a:domain]
    endif

    " Auto-detect known providers
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
function! s:get_base_url(domain) abort
    " Check user-defined domain mappings
    if has_key(g:vim_git_open_domains, a:domain)
        let l:mapped_url = g:vim_git_open_domains[a:domain]
        " Add https:// if no protocol specified
        if l:mapped_url !~# '^\(https\?://\)'
            return 'https://' . l:mapped_url
        endif
        return l:mapped_url
    endif

    " Default to https://domain
    return 'https://' . a:domain
endfunction

" Get current git branch
function! s:get_current_branch() abort
    return s:git_command('rev-parse --abbrev-ref HEAD')
endfunction

" Get current commit hash
function! s:get_current_commit() abort
    return s:git_command('rev-parse HEAD')
endfunction

" Get file path relative to git root
function! s:get_relative_path() abort
    let l:git_root = s:get_git_root()
    if empty(l:git_root)
        return ''
    endif

    let l:abs_path = expand('%:p')

    " Ensure git_root ends with /
    if l:git_root !~# '/$'
        let l:git_root = l:git_root . '/'
    endif

    " Check if abs_path starts with git_root using string comparison
    if strpart(l:abs_path, 0, len(l:git_root)) ==# l:git_root
        return strpart(l:abs_path, len(l:git_root))
    endif

    " Fallback: try regex method with proper escaping
    let l:rel_path = substitute(l:abs_path, '^' . escape(l:git_root, '\/.*[]^$~') . '/', '', '')
    return l:rel_path
endfunction

" Get current line number or range
function! s:get_line_range(line1, line2) abort
    if a:line1 == a:line2
        return a:line1
    else
        return a:line1 . '-' . a:line2
    endif
endfunction

" Format line anchor for provider
function! s:format_line_anchor(provider, line_info) abort
    if empty(a:line_info)
        return ''
    endif

    if a:provider ==# 'GitLab'
        " GitLab uses #L10 or #L10-20
        if a:line_info =~# '-'
            return '#L' . substitute(a:line_info, '-', '-', '')
        else
            return '#L' . a:line_info
        endif
    else
        " GitHub/Codeberg use #L10 or #L10-L20
        if a:line_info =~# '-'
            let l:parts = split(a:line_info, '-')
            return '#L' . l:parts[0] . '-L' . l:parts[1]
        else
            return '#L' . a:line_info
        endif
    endif
endfunction

" Parse PR/MR number from a given message
function! s:parse_pr_mr_number(message, provider) abort
    if a:provider ==# 'GitLab'
        " GitLab uses !1234
        let l:match = matchlist(a:message, '!\(\d\+\)')
    else
        " GitHub/Codeberg use #1234
        let l:match = matchlist(a:message, '#\(\d\+\)')
    endif

    if !empty(l:match)
        return l:match[1]
    endif

    return ''
endfunction

function! s:parse_pr_mr_from_commit(provider) abort
    let l:commit_msg = s:git_command('log -1 --pretty=%B')
    return s:parse_pr_mr_number(l:commit_msg, a:provider)
endfunction

function! s:get_gitlab_username() abort
    if exists('g:vim_git_open_gitlab_username') && !empty(g:vim_git_open_gitlab_username)
        return g:vim_git_open_gitlab_username
    endif
    if !empty($GITLAB_USER)
        return $GITLAB_USER
    elseif !empty($GLAB_USER)
        return $GLAB_USER
    endif
    return $USER
endfunction

" Parse state flag from command args: -open, -closed, -merged, -all
" Returns the query string suffix to append to the pulls/MRs URL.
" GitHub:   uses ?q=is%3Apr+is%3A<state> search query
" Codeberg: uses ?state=<state> param (Gitea-based, no merged state)
" GitLab:   uses ?state=<state> param (opened/merged/closed/all)
function! s:parse_request_state(args, provider) abort
    let l:arg = tolower(trim(a:args))
    if a:provider ==# 'GitLab'
        if l:arg ==# '-merged'
            return '?state=merged'
        elseif l:arg ==# '-closed'
            return '?state=closed'
        elseif l:arg ==# '-all'
            return '?state=all'
        endif
    elseif a:provider ==# 'Codeberg'
        if l:arg ==# '-closed' || l:arg ==# '-merged'
            return '?state=closed'
        elseif l:arg ==# '-all'
            return '?state=all'
        endif
    else
        " GitHub
        if l:arg ==# '-closed' || l:arg ==# '-merged'
            return '?q=is%3Apr+is%3Aclosed'
        elseif l:arg ==# '-all'
            return '?q=is%3Apr'
        endif
    endif
    return ''
endfunction

" ============================================================================
" URL Builders
" ============================================================================

" Build URL for GitHub
function! s:build_github_url(base_url, path, type, ...) abort
    let l:url = a:base_url . '/' . a:path

    if a:type ==# 'repo'
        return l:url
    elseif a:type ==# 'branch'
        let l:branch = a:0 > 0 ? a:1 : s:get_current_branch()
        return l:url . '/tree/' . l:branch
    elseif a:type ==# 'file'
        let l:file = (a:0 > 0 && !empty(a:1)) ? a:1 : s:get_relative_path()
        " a:3 (extra[2]) is an optional branch/commit ref; fall back to HEAD commit
        let l:ref = (a:0 > 2 && !empty(a:3)) ? a:3 : s:get_current_commit()
        let l:file_url = l:url . '/blob/' . l:ref . '/' . l:file

        " Add line number anchor if provided (a:2)
        if a:0 > 1 && !empty(a:2)
            let l:file_url .= s:format_line_anchor('GitHub', a:2)
        endif

        return l:file_url
    elseif a:type ==# 'commit'
        let l:commit = a:0 > 0 ? a:1 : s:get_current_commit()
        return l:url . '/commit/' . l:commit
    elseif a:type ==# 'pr'
        let l:pr = a:0 > 0 ? a:1 : ''
        if empty(l:pr)
            call s:warn('No PR number specified')
            return ''
        endif
        return l:url . '/pull/' . l:pr
    endif

    return l:url
endfunction

" Build URL for GitLab
function! s:build_gitlab_url(base_url, path, type, ...) abort
    let l:url = a:base_url . '/' . a:path

    if a:type ==# 'repo'
        return l:url
    elseif a:type ==# 'branch'
        let l:branch = a:0 > 0 ? a:1 : s:get_current_branch()
        return l:url . '/-/tree/' . l:branch
    elseif a:type ==# 'file'
        let l:file = (a:0 > 0 && !empty(a:1)) ? a:1 : s:get_relative_path()
        " a:3 (extra[2]) is an optional branch/commit ref; fall back to HEAD commit
        let l:ref = (a:0 > 2 && !empty(a:3)) ? a:3 : s:get_current_commit()
        let l:file_url = l:url . '/-/blob/' . l:ref . '/' . l:file

        " Add line number anchor if provided (a:2)
        if a:0 > 1 && !empty(a:2)
            let l:file_url .= s:format_line_anchor('GitLab', a:2)
        endif

        return l:file_url
    elseif a:type ==# 'commit'
        let l:commit = a:0 > 0 ? a:1 : s:get_current_commit()
        return l:url . '/-/commit/' . l:commit
    elseif a:type ==# 'mr'
        let l:mr = a:0 > 0 ? a:1 : ''
        if empty(l:mr)
            call s:warn('No MR number specified')
            return ''
        endif
        return l:url . '/-/merge_requests/' . l:mr
    endif

    return l:url
endfunction

" Build URL for Codeberg (uses same structure as GitHub)
function! s:build_codeberg_url(base_url, path, type, ...) abort
    return call('s:build_github_url', [a:base_url, a:path, a:type] + a:000)
endfunction

" Build URL based on provider
function! s:build_url(provider, base_url, path, type, ...) abort
    if a:provider ==# 'GitLab'
        return call('s:build_gitlab_url', [a:base_url, a:path, a:type] + a:000)
    elseif a:provider ==# 'Codeberg'
        return call('s:build_codeberg_url', [a:base_url, a:path, a:type] + a:000)
    else
        " Default to GitHub
        return call('s:build_github_url', [a:base_url, a:path, a:type] + a:000)
    endif
endfunction

" ============================================================================
" Browser Functions
" ============================================================================

function! s:open_browser(url) abort
    if empty(a:url)
        return
    endif

    if empty(g:vim_git_open_browser_command)
        call s:warn('No browser command configured. Set g:vim_git_open_browser_command')
        return
    endif

    let l:cmd = g:vim_git_open_browser_command . ' ' . shellescape(a:url)

    if has('win32') || has('win64')
        let l:cmd = '!start "" ' . shellescape(a:url)
    else
        let l:cmd = l:cmd . ' > /dev/null 2>&1'
    endif

    call system(l:cmd)
    redraw!
    echo 'Opened: ' . a:url
endfunction

function! s:copy_to_clipboard(url) abort
    if empty(a:url)
        return
    endif

    call setreg('+', a:url)
    call setreg('*', a:url)
    redraw!
    echo 'Copied: ' . a:url
endfunction

function! s:open_or_copy(url, copy) abort
    if a:copy
        call s:copy_to_clipboard(a:url)
    else
        call s:open_browser(a:url)
    endif
endfunction

" Get repository info (domain, path, provider)
function! s:get_repo_info() abort
    let l:remote = s:parse_remote_url()
    if empty(l:remote)
        call s:warn('Not a git repository or no remote configured')
        return {}
    endif

    let l:provider = s:detect_provider(l:remote.domain)
    let l:base_url = s:get_base_url(l:remote.domain)

    return {
        \ 'domain': l:remote.domain,
        \ 'path': l:remote.path,
        \ 'provider': l:provider,
        \ 'base_url': l:base_url
        \ }
endfunction

" ============================================================================
" Completion Functions
" ============================================================================

function! git_open#legacy#complete_branch(arglead, cmdline, cursorpos) abort
    " Local branches sorted by most recent commit (-committerdate)
    let l:local_raw = s:git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    " Remote branches sorted by most recent commit, strip refs/remotes/<remote>/
    let l:remote_raw = s:git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/")

    let l:branches = []
    if !empty(l:local_raw)
        let l:branches += split(l:local_raw, '\n')
    endif
    if !empty(l:remote_raw)
        let l:branches += filter(split(l:remote_raw, '\n'), 'v:val !=# ''HEAD''')
    endif

    " Deduplicate while preserving order (local branches first)
    let l:seen = {}
    let l:result = []
    for l:b in l:branches
        if !has_key(l:seen, l:b)
            let l:seen[l:b] = 1
            call add(l:result, l:b)
        endif
    endfor

    if empty(a:arglead)
        return l:result
    endif
    if exists('*matchfuzzy')
        return matchfuzzy(l:result, a:arglead)
    endif
    return filter(l:result, 'v:val =~# ''^'' . escape(a:arglead, ''\/.*[]^$~'')')
endfunction

function! git_open#legacy#complete_request_state(arglead, cmdline, cursorpos) abort
    let l:flags = ['-open', '-closed', '-merged', '-all', '-search']
    if empty(a:arglead)
        return l:flags
    endif
    if exists('*matchfuzzy')
        return matchfuzzy(l:flags, a:arglead)
    endif
    return filter(copy(l:flags), 'v:val =~# ''^'' . escape(a:arglead, ''\/.*[]^$~'')')
endfunction

" ============================================================================
" Public API Functions
" ============================================================================

function! git_open#legacy#open_repo(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'repo')
    call s:open_or_copy(l:url, a:0 > 0 && a:1)
endfunction

function! git_open#legacy#open_branch(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    " a:1 = branch (optional), a:2 = copy flag (optional)
    let l:branch = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2

    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'branch', l:branch)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_file(line1, line2, ...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    if empty(expand('%'))
        call s:warn('No file in current buffer')
        return
    endif

    let l:line_range = s:get_line_range(a:line1, a:line2)

    " a:1 = ref/branch (optional), a:2 = copy flag (optional)
    let l:ref = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2

    " extra[0]=file(empty=current), extra[1]=line_range, extra[2]=ref
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'file', '', l:line_range, l:ref)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_commit(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    " a:1 = commit (optional), a:2 = copy flag (optional)
    let l:commit = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2

    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'commit', l:commit)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_request(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    " First optional arg is req number, second is copy flag
    let l:number = a:0 > 0 && !empty(a:1) ? a:1 : s:parse_pr_mr_from_commit(l:info.provider)
    let l:copy = a:0 > 1 && a:2

    if empty(l:number)
        call s:warn('No request number specified and could not parse from commit message')
        return
    endif

    let l:type = l:info.provider ==# 'GitLab' ? 'mr' : 'pr'
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, l:type, l:number)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_file_last_change(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    let l:file_path = s:get_relative_path()
    if empty(l:file_path)
        call s:warn('Current file is not in a git repository')
        return
    endif

    let l:commit = s:git_command('log -1 --format=%H -- ' . shellescape(l:file_path))
    if empty(l:commit)
        call s:warn('No commits found for current file')
        return
    endif

    let l:message = s:git_command('log -1 --format=%B ' . l:commit)
    let l:pr_mr_number = s:parse_pr_mr_number(l:message, l:info.provider)

    if !empty(l:pr_mr_number)
        if l:info.provider ==# 'GitLab'
            let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'mr', l:pr_mr_number)
        else
            let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'pr', l:pr_mr_number)
        endif
    else
        let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'commit', l:commit)
    endif

    call s:open_or_copy(l:url, a:0 > 0 && a:1)
endfunction

function! git_open#legacy#open_my_requests(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    " a:1 = state arg (optional), a:2 = copy flag (optional)
    let l:state = s:parse_request_state(a:0 > 0 ? a:1 : '', l:info.provider)
    let l:copy = a:0 > 1 && a:2

    if l:info.provider ==# 'GitLab'
        let l:arg = tolower(trim(a:0 > 0 ? a:1 : ''))
        if l:arg ==# '-search'
            " -search: use search page scoped to author + optional state filter
            let l:url = l:info.base_url . '/dashboard/merge_requests/search?author_username=' . s:get_gitlab_username()
        elseif l:arg ==# '-closed' || l:arg ==# '-merged'
            let l:url = l:info.base_url . '/dashboard/merge_requests/merged'
        else
            " no flag / -open / -all: use the default dashboard page
            let l:url = l:info.base_url . '/dashboard/merge_requests'
        endif
    elseif l:info.provider ==# 'GitHub'
        " No flag/-open: /pulls is already scoped to current user when logged in
        " With state flag: append author:@me to keep scoped to current user
        let l:url = l:info.base_url . '/pulls' . (empty(l:state) ? '' : l:state . '+author%3A%40me')
    else
        " Codeberg: state is already a full query string or empty
        let l:url = l:info.base_url . '/pulls' . l:state
    endif

    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_requests(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif

    " a:1 = state arg (optional), a:2 = copy flag (optional)
    let l:state = s:parse_request_state(a:0 > 0 ? a:1 : '', l:info.provider)
    let l:copy = a:0 > 1 && a:2

    let l:repo_url = l:info.base_url . '/' . l:info.path
    if l:info.provider ==# 'GitLab'
        let l:url = l:repo_url . '/-/merge_requests' . l:state
    else
        " GitHub and Codeberg: state is already a full query string or empty
        let l:url = l:repo_url . '/pulls' . l:state
    endif

    call s:open_or_copy(l:url, l:copy)
endfunction

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
