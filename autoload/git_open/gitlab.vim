" autoload/git_open/gitlab.vim - GitLab provider for vim-git-open
" Maintainer:   Phong Nguyen
" Version:      1.0.0

" ============================================================================
" Provider Interface — see autoload/git_open/github.vim for the full contract
" ============================================================================

" ============================================================================
" URL pattern helpers
" ============================================================================

" {base_url}/{path} — root URL for all repo-scoped paths
function! s:RepoBase(repo_info) abort
    return a:repo_info.base_url . '/' . a:repo_info.path
endfunction

function! s:BranchPath(branch) abort
    return '/-/tree/' . a:branch
endfunction

function! s:FilePath(ref, file) abort
    return '/-/blob/' . a:ref . '/' . a:file
endfunction

function! s:CommitPath(commit) abort
    return '/-/commit/' . a:commit
endfunction

function! s:RequestPath(number) abort
    return '/-/merge_requests/' . a:number
endfunction

function! s:RequestsPath() abort
    return '/-/merge_requests'
endfunction

function! s:MyRequestsPath() abort
    return '/dashboard/merge_requests'
endfunction

" Returns the query string (including '?') for a repo-scoped MR list, or ''.
" state_arg: '', '-open', '-closed', '-merged', '-all'
" GitLab uses ?state=opened|closed|merged|all; '-open' is the default (no query needed).
function! s:RequestsQuery(state_arg) abort
    let l:arg = tolower(trim(a:state_arg))
    if l:arg ==# '-merged'
        return '?state=merged'
    elseif l:arg ==# '-closed'
        return '?state=closed'
    elseif l:arg ==# '-all'
        return '?state=all'
    endif
    return ''
endfunction

" ============================================================================
" Line anchor
" ============================================================================

" GitLab uses #L10 or #L10-20 anchors (no second 'L' before the end line)
function! s:FormatLineAnchor(line_info) abort
    if empty(a:line_info)
        return ''
    endif
    return '#L' . a:line_info
endfunction

" ============================================================================
" Public provider interface
" ============================================================================

" GitLab uses !1234 for MR references in commit messages
function! git_open#gitlab#ParseRequestNumber(message) abort
    let l:match = matchlist(a:message, '!\(\d\+\)')
    return empty(l:match) ? '' : l:match[1]
endfunction

function! git_open#gitlab#BuildRepoUrl(repo_info) abort
    return s:RepoBase(a:repo_info)
endfunction

function! git_open#gitlab#BuildBranchUrl(repo_info, branch) abort
    return s:RepoBase(a:repo_info) . s:BranchPath(a:branch)
endfunction

function! git_open#gitlab#BuildFileUrl(repo_info, file, line_info, ref) abort
    let l:url = s:RepoBase(a:repo_info) . s:FilePath(a:ref, a:file)
    if !empty(a:line_info)
        let l:url .= s:FormatLineAnchor(a:line_info)
    endif
    return l:url
endfunction

function! git_open#gitlab#BuildCommitUrl(repo_info, commit) abort
    return s:RepoBase(a:repo_info) . s:CommitPath(a:commit)
endfunction

function! git_open#gitlab#BuildRequestUrl(repo_info, number) abort
    return s:RepoBase(a:repo_info) . s:RequestPath(a:number)
endfunction

function! git_open#gitlab#BuildRequestsUrl(repo_info, state_arg) abort
    return s:RepoBase(a:repo_info) . s:RequestsPath() . s:RequestsQuery(a:state_arg)
endfunction

" state_arg: '', '-open', '-closed', '-merged', '-all', '-search', '-search=<state>'
" GitLab's dashboard MR page shows the current user's MRs by default.
"   no flag / -open / -all → /dashboard/merge_requests
"   -closed / -merged      → /dashboard/merge_requests/merged
"   -search[=<state>]      → /dashboard/merge_requests/search?author_username=<user>[&state=<state>]
function! git_open#gitlab#BuildMyRequestsUrl(repo_info, state_arg) abort
    let l:arg = tolower(trim(a:state_arg))
    if l:arg =~# '^-search'
        let l:parts = split(l:arg, '=')
        let l:search_state = len(l:parts) > 1 ? l:parts[1] : ''
        let l:url = a:repo_info.base_url . s:MyRequestsPath() . '/search?author_username=' . s:GetGitlabUsername()
        if l:search_state ==# 'closed' || l:search_state ==# 'merged'
            let l:url .= '&state=' . l:search_state
        elseif l:search_state ==# 'all'
            let l:url .= '&state=all'
        elseif l:search_state ==# 'open'
            let l:url .= '&state=opened'
        endif
        return l:url
    elseif l:arg ==# '-closed' || l:arg ==# '-merged'
        return a:repo_info.base_url . s:MyRequestsPath() . '/merged'
    endif
    " no flag / -open / -all: default dashboard page
    return a:repo_info.base_url . s:MyRequestsPath()
endfunction

" Resolve the GitLab username for use in -search URLs.
" Resolution order:
"   1. g:vim_git_open_gitlab_username
"   2. $GITLAB_USER
"   3. $GLAB_USER
"   4. $USER
function! s:GetGitlabUsername() abort
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
