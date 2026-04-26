" autoload/git_open/github.vim - GitHub provider for vim-git-open
" Maintainer:   Phong Nguyen
" Version:      1.0.0

" ============================================================================
" Provider Interface
"
" Common interface implemented by every provider.
" `repo_info` is the repo info dict: { base_url, path, provider, domain }
"
"   git_open#<provider>#ParseRequestNumber(message)                        -> string
"   git_open#<provider>#BuildRepoUrl(repo_info)                            -> string
"   git_open#<provider>#BuildBranchUrl(repo_info, branch)                  -> string
"   git_open#<provider>#BuildFileUrl(repo_info, file, line_info, ref)      -> string
"   git_open#<provider>#BuildCommitUrl(repo_info, commit)                  -> string
"   git_open#<provider>#BuildRequestUrl(repo_info, number)                 -> string
"   git_open#<provider>#BuildRequestsUrl(repo_info, state_arg)             -> string
"   git_open#<provider>#BuildMyRequestsUrl(repo_info, state_arg)           -> string
"
" line_info: line number or range string (e.g. '10' or '10-20'), or empty.
" ref:       branch name or 40-char commit SHA; caller resolves empty ref to HEAD.
" state_arg: '', '-open', '-closed', '-merged', '-all' (provider-specific handling).
" ============================================================================

" ============================================================================
" URL pattern helpers
" ============================================================================

" {base_url}/{path} — root URL for all repo-scoped paths
function! s:RepoBase(repo_info) abort
    return a:repo_info.base_url . '/' . a:repo_info.path
endfunction

function! s:BranchPath(branch) abort
    return '/tree/' . a:branch
endfunction

function! s:FilePath(ref, file) abort
    return '/blob/' . a:ref . '/' . a:file
endfunction

function! s:CommitPath(commit) abort
    return '/commit/' . a:commit
endfunction

function! s:RequestPath(number) abort
    return '/pull/' . a:number
endfunction

function! s:RequestsPath() abort
    return '/pulls'
endfunction

" GitHub user-scoped PR list uses the same /pulls root as the repo list.
function! s:MyRequestsPath() abort
    return '/pulls'
endfunction

" Returns the query string (including '?') for a repo-scoped PR list, or ''.
" state_arg: '', '-open', '-closed', '-merged', '-all'
" GitHub uses search syntax: plain ?state= only targets the issues API.
function! s:RequestsQuery(state_arg) abort
    let l:arg = tolower(trim(a:state_arg))
    if l:arg ==# '-closed' || l:arg ==# '-merged'
        return '?q=is%3Apr+is%3Aclosed'
    elseif l:arg ==# '-all'
        return '?q=is%3Apr'
    endif
    return ''
endfunction

" Returns the query string (including '?') for a user-scoped PR list, or ''.
" GitHub scopes /pulls to the current user by default; state flags add author:@me.
function! s:MyRequestsQuery(state_arg) abort
    let l:arg = tolower(trim(a:state_arg))
    if l:arg ==# '-closed' || l:arg ==# '-merged'
        return '?q=is%3Apr+is%3Aclosed+author%3A%40me'
    elseif l:arg ==# '-all'
        return '?q=is%3Apr+author%3A%40me'
    endif
    return ''
endfunction

" ============================================================================
" Line anchor
" ============================================================================

" GitHub uses #L10 or #L10-L20 anchors
function! s:FormatLineAnchor(line_info) abort
    if empty(a:line_info)
        return ''
    endif
    if a:line_info =~# '-'
        let l:parts = split(a:line_info, '-')
        return '#L' . l:parts[0] . '-L' . l:parts[1]
    endif
    return '#L' . a:line_info
endfunction

" ============================================================================
" Public provider interface
" ============================================================================

" GitHub uses #1234 for PR references in commit messages
function! git_open#github#ParseRequestNumber(message) abort
    let l:match = matchlist(a:message, '#\(\d\+\)')
    return empty(l:match) ? '' : l:match[1]
endfunction

function! git_open#github#BuildRepoUrl(repo_info) abort
    return s:RepoBase(a:repo_info)
endfunction

function! git_open#github#BuildBranchUrl(repo_info, branch) abort
    return s:RepoBase(a:repo_info) . s:BranchPath(a:branch)
endfunction

" file      - relative path to file
" line_info - line number or range string (e.g. '10' or '10-20'), may be empty
" ref       - branch or commit hash; caller must resolve empty ref to HEAD commit
function! git_open#github#BuildFileUrl(repo_info, file, line_info, ref) abort
    let l:url = s:RepoBase(a:repo_info) . s:FilePath(a:ref, a:file)
    if !empty(a:line_info)
        let l:url .= s:FormatLineAnchor(a:line_info)
    endif
    return l:url
endfunction

function! git_open#github#BuildCommitUrl(repo_info, commit) abort
    return s:RepoBase(a:repo_info) . s:CommitPath(a:commit)
endfunction

function! git_open#github#BuildRequestUrl(repo_info, number) abort
    return s:RepoBase(a:repo_info) . s:RequestPath(a:number)
endfunction

function! git_open#github#BuildRequestsUrl(repo_info, state_arg) abort
    return s:RepoBase(a:repo_info) . s:RequestsPath() . s:RequestsQuery(a:state_arg)
endfunction

" GitHub /pulls is already scoped to the current user when logged in.
" A state flag appends author:@me to stay user-scoped.
function! git_open#github#BuildMyRequestsUrl(repo_info, state_arg) abort
    return a:repo_info.base_url . s:MyRequestsPath() . s:MyRequestsQuery(a:state_arg)
endfunction
