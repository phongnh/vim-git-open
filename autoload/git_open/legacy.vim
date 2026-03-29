" autoload/git_open/legacy.vim - Core functionality for git_open plugin (legacy Vimscript)
" Maintainer:   Phong Nguyen
" Version:      1.0.0

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
function! s:get_all_remote_names(git_root) abort
    let l:output = trim(system('git -C ' . shellescape(a:git_root) . ' remote'))
    if empty(l:output)
        return []
    endif
    return filter(split(l:output, '\n'), '!empty(v:val)')
endfunction

function! s:get_current_remote(git_root) abort
    " Step 1: already resolved for this buffer
    if exists('b:vim_git_open_remote') && !empty(b:vim_git_open_remote)
        return b:vim_git_open_remote
    endif

    let l:remotes = s:get_all_remote_names(a:git_root)
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
                call s:warn("git-open: remote '" . g:vim_git_open_remote . "' not found, falling back")
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

" Parse remote URL using per-buffer remote resolution (GetCurrentRemote)
function! s:parse_remote_url() abort
    let l:git_root = s:get_git_root()
    let l:remote_name = empty(l:git_root) ? '' : s:get_current_remote(l:git_root)
    if empty(l:remote_name)
        return {}
    endif
    let l:remote = s:git_command('config --get remote.' . l:remote_name . '.url')
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

" Build URL for Codeberg (Gitea/Forgejo) — different paths from GitHub:
"   branch view: /src/branch/{branch}
"   file at commit: /src/commit/{commit}/{file}
"   file at branch: /src/branch/{branch}/{file}
"   single PR: /pulls/{number}  (not /pull/)
"   commit: /commit/{hash}  (same as GitHub)
function! s:build_codeberg_url(base_url, path, type, ...) abort
    let l:url = a:base_url . '/' . a:path

    if a:type ==# 'repo'
        return l:url
    elseif a:type ==# 'branch'
        let l:branch = a:0 > 0 ? a:1 : s:get_current_branch()
        return l:url . '/src/branch/' . l:branch
    elseif a:type ==# 'file'
        let l:file = (a:0 > 0 && !empty(a:1)) ? a:1 : s:get_relative_path()
        " a:3 (extra[2]) is an optional branch/commit ref; fall back to HEAD commit
        let l:ref = (a:0 > 2 && !empty(a:3)) ? a:3 : s:get_current_commit()
        " Determine whether ref looks like a commit hash (40 hex chars) or a branch name
        let l:ref_type = l:ref =~# '^[0-9a-f]\{40\}$' ? 'commit' : 'branch'
        let l:file_url = l:url . '/src/' . l:ref_type . '/' . l:ref . '/' . l:file

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
        return l:url . '/pulls/' . l:pr
    endif

    return l:url
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

" Parse remote URL for a specific named remote (bypasses per-buffer resolution)
function! s:parse_remote_url_for_name(remote_name) abort
    let l:remote = s:git_command('config --get remote.' . a:remote_name . '.url')
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

" Get all non-origin remote names
function! s:get_all_remotes() abort
    let l:output = s:git_command('remote')
    if empty(l:output)
        return []
    endif
    return filter(split(l:output, '\n'), 'v:val !=# ''origin''')
endfunction

" Get repository info for a specific remote
function! s:get_repo_info_for_remote(remote_name) abort
    let l:remote = s:parse_remote_url_for_name(a:remote_name)
    if empty(l:remote)
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

function! s:get_visual_selection() abort
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

function! s:unique(items) abort
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

function! s:fuzzy_filter(result, arglead) abort
    if empty(a:arglead)
        return a:result
    endif
    if exists('*matchfuzzy')
        return matchfuzzy(a:result, a:arglead)
    endif
    return filter(copy(a:result), 'v:val =~# ''^'' . escape(a:arglead, ''\/.*[]^$~'')')
endfunction

function! git_open#legacy#complete_branch(arglead, cmdline, cursorpos) abort
    " Local branches sorted by most recent commit (-committerdate)
    let l:local_raw = s:git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    " Remote branches sorted by most recent commit, strip refs/remotes/<remote>/
    let l:remote_raw = s:git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/")
    let l:local = empty(l:local_raw) ? [] : split(l:local_raw, '\n')
    let l:remote = empty(l:remote_raw) ? [] : filter(split(l:remote_raw, '\n'), 'v:val !=# ''HEAD''')
    return s:fuzzy_filter(s:unique(l:local + l:remote), a:arglead)
endfunction

function! git_open#legacy#complete_gitk_branch(arglead, cmdline, cursorpos) abort
    " Local branches (plain name), then remote branches with full remote/ prefix
    let l:local_raw = s:git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/heads/")
    let l:remote_raw = s:git_command("for-each-ref --sort=-committerdate --format='%(refname:lstrip=2)' refs/remotes/")
    let l:local = empty(l:local_raw) ? [] : split(l:local_raw, '\n')
    let l:remote = empty(l:remote_raw) ? [] : filter(split(l:remote_raw, '\n'), 'v:val !~# ''/HEAD$''')
    return s:fuzzy_filter(s:unique(l:local + l:remote), a:arglead)
endfunction

function! git_open#legacy#complete_gitk_args(arglead, cmdline, cursorpos) abort
    " Branches (local plain + remote with prefix) then tracked files
    let l:branches = git_open#legacy#complete_gitk_branch('', '', 0)
    let l:files_raw = s:git_command('ls-files')
    let l:files = empty(l:files_raw) ? [] : split(l:files_raw, '\n')
    return s:fuzzy_filter(s:unique(l:branches + l:files), a:arglead)
endfunction

function! git_open#legacy#complete_request_state(arglead, cmdline, cursorpos) abort
    return s:fuzzy_filter(['-open', '-closed', '-merged', '-all'], a:arglead)
endfunction

function! git_open#legacy#complete_my_request_state(arglead, cmdline, cursorpos) abort
    return s:fuzzy_filter(['-open', '-closed', '-merged', '-all',
                \ '-search', '-search=open', '-search=closed', '-search=merged', '-search=all'], a:arglead)
endfunction

function! git_open#legacy#complete_git_remote(arglead, cmdline, cursorpos) abort
    let l:git_root = s:get_git_root()
    if empty(l:git_root)
        return []
    endif
    return s:fuzzy_filter(s:get_all_remote_names(l:git_root), a:arglead)
endfunction

function! git_open#legacy#open_git_remote(name, reset) abort
    let l:git_root = s:get_git_root()
    if empty(l:git_root)
        call s:warn('git-open: not a git repository')
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
        let l:current = s:get_current_remote(l:git_root)
        if empty(l:current)
            call s:warn('git-open: no remotes found')
        else
            echo "git-open: current remote is '" . l:current . "'"
        endif
        return
    endif

    let l:remotes = s:get_all_remote_names(l:git_root)
    if index(l:remotes, a:name) < 0
        call s:warn("git-open: remote '" . a:name . "' not found (available: " . join(l:remotes, ', ') . ')')
        return
    endif
    let b:vim_git_open_remote = a:name
    if exists('b:vim_git_open_remote_warned')
        unlet b:vim_git_open_remote_warned
    endif
    echo "git-open: remote set to '" . a:name . "' for this buffer"
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

    " a:1 = branch (optional), a:2 = copy flag (optional), a:3 = visual flag (optional)
    let l:branch = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3

    if empty(l:branch) && l:visual
        let l:branch = s:get_visual_selection()
    endif
    if empty(l:branch)
        let l:branch = s:get_current_branch()
    endif

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

    " a:1 = commit (optional), a:2 = copy flag (optional), a:3 = visual flag (optional)
    let l:commit = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3

    if empty(l:commit) && l:visual
        let l:commit = s:get_visual_selection()
    endif
    if empty(l:commit)
        let l:commit = s:get_current_commit()
    endif

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
        " Check for -search or -search=<state>
        if l:arg =~# '^-search'
            let l:parts = split(l:arg, '=')
            let l:search_state = len(l:parts) > 1 ? l:parts[1] : ''
            let l:search_url = l:info.base_url . '/dashboard/merge_requests/search?author_username=' . s:get_gitlab_username()
            if l:search_state ==# 'closed' || l:search_state ==# 'merged'
                let l:search_url .= '&state=' . l:search_state
            elseif l:search_state ==# 'all'
                let l:search_url .= '&state=all'
            endif
            let l:url = l:search_url
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
        " Codeberg: no flag/-open → bare /pulls; -all → ?type=created_by;
        " -closed/-merged → ?type=created_by&state=closed
        let l:cb_arg = tolower(trim(a:0 > 0 ? a:1 : ''))
        if l:cb_arg ==# '-closed' || l:cb_arg ==# '-merged'
            let l:url = l:info.base_url . '/pulls?type=created_by&state=closed'
        elseif l:cb_arg ==# '-all'
            let l:url = l:info.base_url . '/pulls?type=created_by'
        else
            let l:url = l:info.base_url . '/pulls'
        endif
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

" ============================================================================
" Gitk Functions
" ============================================================================

function! s:launch_gitk(args, git_root) abort
    if !executable('gitk')
        call s:warn('git-open: gitk not found in PATH')
        return
    endif
    if has('job')
        " Vim 8.0+ job_start with cwd support
        call job_start(['gitk'] + a:args, {'cwd': a:git_root, 'stoponexit': ''})
    else
        " Vim 7 fallback: shell background
        let l:escaped = join(map(copy(a:args), 'shellescape(v:val)'))
        call system('cd ' . shellescape(a:git_root) . ' && gitk ' . l:escaped . ' &')
        redraw!
    endif
endfunction

function! s:get_gitk_old_paths(rel_path) abort
    " Collect all historical paths this file has had (follows renames)
    let l:output = s:git_command('log --follow --name-only --format= -- ' . shellescape(a:rel_path))
    if empty(l:output)
        return [a:rel_path]
    endif
    let l:seen = {}
    let l:paths = []
    for l:p in split(l:output, '\n')
        if !empty(l:p) && !has_key(l:seen, l:p)
            let l:seen[l:p] = 1
            call add(l:paths, l:p)
        endif
    endfor
    return empty(l:paths) ? [a:rel_path] : l:paths
endfunction

function! git_open#legacy#open_gitk(...) abort
    let l:git_root = s:get_git_root()
    if empty(l:git_root)
        call s:warn('git-open: not a git repository')
        return
    endif
    let l:args_str = a:0 > 0 ? a:1 : ''
    let l:args = empty(l:args_str) ? [] : split(l:args_str)
    call s:launch_gitk(l:args, l:git_root)
endfunction

function! git_open#legacy#open_gitk_file(...) abort
    let l:git_root = s:get_git_root()
    if empty(l:git_root)
        call s:warn('git-open: not a git repository')
        return
    endif
    if empty(expand('%'))
        call s:warn('git-open: no file in current buffer')
        return
    endif
    let l:opts_str = a:0 > 0 ? a:1 : ''
    let l:history  = a:0 > 1 ? a:2 : 0
    let l:rel_path = s:get_relative_path()
    let l:paths = l:history ? s:get_gitk_old_paths(l:rel_path) : [l:rel_path]
    let l:extra_args = empty(l:opts_str) ? [] : split(l:opts_str)
    call s:launch_gitk(l:extra_args + ['--'] + l:paths, l:git_root)
endfunction

" ============================================================================
" Multi-Remote Public API
" ============================================================================

function! git_open#legacy#get_all_remotes() abort
    return s:get_all_remotes()
endfunction

function! git_open#legacy#get_repo_info_for_remote(remote_name) abort
    return s:get_repo_info_for_remote(a:remote_name)
endfunction

function! git_open#legacy#get_repo_info() abort
    return s:get_repo_info()
endfunction

function! git_open#legacy#open_repo_for_remote(remote_name, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'repo')
    call s:open_or_copy(l:url, a:0 > 0 && a:1)
endfunction

function! git_open#legacy#open_branch_for_remote(remote_name, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:branch = a:0 > 0 ? a:1 : ''
    let l:copy   = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3
    if empty(l:branch) && l:visual
        let l:branch = s:get_visual_selection()
    endif
    if empty(l:branch)
        let l:branch = s:get_current_branch()
    endif
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'branch', l:branch)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_file_for_remote(remote_name, line1, line2, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    if empty(expand('%'))
        call s:warn('No file in current buffer')
        return
    endif
    let l:line_range = s:get_line_range(a:line1, a:line2)
    let l:ref  = a:0 > 0 ? a:1 : ''
    let l:copy = a:0 > 1 && a:2
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'file', '', l:line_range, l:ref)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_commit_for_remote(remote_name, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:commit = a:0 > 0 ? a:1 : ''
    let l:copy   = a:0 > 1 && a:2
    let l:visual = a:0 > 2 && a:3
    if empty(l:commit) && l:visual
        let l:commit = s:get_visual_selection()
    endif
    if empty(l:commit)
        let l:commit = s:get_current_commit()
    endif
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'commit', l:commit)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_request_for_remote(remote_name, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:number = a:0 > 0 && !empty(a:1) ? a:1 : s:parse_pr_mr_from_commit(l:info.provider)
    let l:copy   = a:0 > 1 && a:2
    if empty(l:number)
        call s:warn('No request number specified and could not parse from commit message')
        return
    endif
    let l:type = l:info.provider ==# 'GitLab' ? 'mr' : 'pr'
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, l:type, l:number)
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_requests_for_remote(remote_name, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:state = s:parse_request_state(a:0 > 0 ? a:1 : '', l:info.provider)
    let l:copy  = a:0 > 1 && a:2
    let l:repo_url = l:info.base_url . '/' . l:info.path
    if l:info.provider ==# 'GitLab'
        let l:url = l:repo_url . '/-/merge_requests' . l:state
    else
        let l:url = l:repo_url . '/pulls' . l:state
    endif
    call s:open_or_copy(l:url, l:copy)
endfunction

function! git_open#legacy#open_my_requests_for_remote(remote_name, ...) abort
    let l:info = s:get_repo_info_for_remote(a:remote_name)
    if empty(l:info)
        call s:warn('No remote configured for: ' . a:remote_name)
        return
    endif
    let l:state_arg = a:0 > 0 ? a:1 : ''
    let l:copy      = a:0 > 1 && a:2
    let l:state = s:parse_request_state(l:state_arg, l:info.provider)
    if l:info.provider ==# 'GitLab'
        let l:arg = tolower(trim(l:state_arg))
        if l:arg =~# '^-search'
            let l:parts = split(l:arg, '=')
            let l:search_state = len(l:parts) > 1 ? l:parts[1] : ''
            let l:search_url = l:info.base_url . '/dashboard/merge_requests/search?author_username=' . s:get_gitlab_username()
            if l:search_state ==# 'closed' || l:search_state ==# 'merged'
                let l:search_url .= '&state=' . l:search_state
            elseif l:search_state ==# 'all'
                let l:search_url .= '&state=all'
            endif
            let l:url = l:search_url
        elseif l:arg ==# '-closed' || l:arg ==# '-merged'
            let l:url = l:info.base_url . '/dashboard/merge_requests/merged'
        else
            let l:url = l:info.base_url . '/dashboard/merge_requests'
        endif
    elseif l:info.provider ==# 'GitHub'
        let l:url = l:info.base_url . '/pulls' . (empty(l:state) ? '' : l:state . '+author%3A%40me')
    else
        " Codeberg: no flag/-open → bare /pulls; -all → ?type=created_by;
        " -closed/-merged → ?type=created_by&state=closed
        let l:cb_arg = tolower(trim(l:state_arg))
        if l:cb_arg ==# '-closed' || l:cb_arg ==# '-merged'
            let l:url = l:info.base_url . '/pulls?type=created_by&state=closed'
        elseif l:cb_arg ==# '-all'
            let l:url = l:info.base_url . '/pulls?type=created_by'
        else
            let l:url = l:info.base_url . '/pulls'
        endif
    endif
    call s:open_or_copy(l:url, l:copy)
endfunction
