" autoload/git_open.vim - Core functionality for git_open plugin
" Maintainer:   Phong Nguyen
" Version:      1.0.0

" Save cpoptions
let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" Helper Functions
" ============================================================================

" Get the git root directory
function! s:get_git_root() abort
    let l:git_dir = finddir('.git', expand('%:p:h') . ';')
    if empty(l:git_dir)
        return ''
    endif
    return fnamemodify(l:git_dir, ':h')
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
    let l:rel_path = substitute(l:abs_path, '^' . l:git_root . '/', '', '')
    return l:rel_path
endfunction

" Get current line number or range
function! s:get_line_range() abort
    let l:mode = mode()
    if l:mode ==# 'v' || l:mode ==# 'V' || l:mode ==# "\<C-v>"
        " Visual mode - get range
        let l:start = line("'<")
        let l:end = line("'>")
        if l:start == l:end
            return l:start
        else
            return l:start . '-' . l:end
        endif
    else
        " Normal mode - get current line
        return line('.')
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

" Parse PR/MR number from commit message
function! s:parse_pr_mr_from_commit(provider) abort
    let l:commit_msg = s:git_command('log -1 --pretty=%B')
    
    if a:provider ==# 'GitLab'
        " GitLab uses !1234
        let l:match = matchlist(l:commit_msg, '!\(\d\+\)')
    else
        " GitHub/Codeberg use #1234
        let l:match = matchlist(l:commit_msg, '#\(\d\+\)')
    endif
    
    if !empty(l:match)
        return l:match[1]
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
        let l:file = a:0 > 0 ? a:1 : s:get_relative_path()
        let l:commit = s:get_current_commit()
        let l:file_url = l:url . '/blob/' . l:commit . '/' . l:file
        
        " Add line number anchor if provided
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
            echoerr 'No PR number specified'
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
        let l:file = a:0 > 0 ? a:1 : s:get_relative_path()
        let l:commit = s:get_current_commit()
        let l:file_url = l:url . '/-/blob/' . l:commit . '/' . l:file
        
        " Add line number anchor if provided
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
            echoerr 'No MR number specified'
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

" Open URL in browser
function! s:open_browser(url) abort
    if empty(a:url)
        return
    endif
    
    if empty(g:vim_git_open_browser_command)
        echoerr 'No browser command configured. Set g:vim_git_open_browser_command'
        return
    endif
    
    let l:cmd = g:vim_git_open_browser_command . ' ' . shellescape(a:url)
    
    if has('win32') || has('win64')
        let l:cmd = '!start "" ' . shellescape(a:url)
    endif
    
    call system(l:cmd)
    echo 'Opened: ' . a:url
endfunction

" Get repository info (domain, path, provider)
function! s:get_repo_info() abort
    let l:remote = s:parse_remote_url()
    if empty(l:remote)
        echoerr 'Not a git repository or no remote configured'
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
" Public API Functions
" ============================================================================

" Open repository home page
function! git_open#open_repo() abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'repo')
    call s:open_browser(l:url)
endfunction

" Open current branch
function! git_open#open_branch() abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'branch')
    call s:open_browser(l:url)
endfunction

" Open current file with optional line number
function! git_open#open_file() abort range
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    if empty(expand('%'))
        echoerr 'No file in current buffer'
        return
    endif
    
    " Get line range (supports visual selection)
    let l:line_range = s:get_line_range()
    
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'file', '', l:line_range)
    call s:open_browser(l:url)
endfunction

" Open current commit
function! git_open#open_commit() abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'commit')
    call s:open_browser(l:url)
endfunction

" Open pull request (GitHub/Codeberg)
function! git_open#open_pr(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    let l:pr_number = a:0 > 0 && !empty(a:1) ? a:1 : s:parse_pr_mr_from_commit(l:info.provider)
    
    if empty(l:pr_number)
        echoerr 'No PR number specified and could not parse from commit message'
        return
    endif
    
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'pr', l:pr_number)
    call s:open_browser(l:url)
endfunction

" Open merge request (GitLab)
function! git_open#open_mr(...) abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    let l:mr_number = a:0 > 0 && !empty(a:1) ? a:1 : s:parse_pr_mr_from_commit(l:info.provider)
    
    if empty(l:mr_number)
        echoerr 'No MR number specified and could not parse from commit message'
        return
    endif
    
    let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'mr', l:mr_number)
    call s:open_browser(l:url)
endfunction

" Open last change (PR/MR or commit) for current file
function! git_open#open_file_last_change() abort
    let l:info = s:get_repo_info()
    if empty(l:info)
        return
    endif
    
    " Get the file path relative to git root
    let l:file_path = s:get_relative_path()
    if empty(l:file_path)
        echoerr 'Current file is not in a git repository'
        return
    endif
    
    " Get the latest commit hash for this file
    let l:commit = s:git_command('log -1 --format=%H -- ' . shellescape(l:file_path))
    if empty(l:commit)
        echoerr 'No commits found for current file'
        return
    endif
    
    " Get the commit message
    let l:message = s:git_command('log -1 --format=%B ' . l:commit)
    
    " Try to parse PR/MR number from commit message
    let l:pr_mr_number = s:parse_pr_mr_from_message(l:message, l:info.provider)
    
    if !empty(l:pr_mr_number)
        " Open PR or MR if found
        if l:info.provider ==# 'GitLab'
            let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'mr', l:pr_mr_number)
        else
            let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'pr', l:pr_mr_number)
        endif
    else
        " Otherwise, open the commit
        let l:url = s:build_url(l:info.provider, l:info.base_url, l:info.path, 'commit', l:commit)
    endif
    
    call s:open_browser(l:url)
endfunction

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
