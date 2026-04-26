" autoload/git_open/codeberg.vim - Codeberg (Gitea/Forgejo) provider for vim-git-open
" Maintainer:   Phong Nguyen
" Version:      1.0.0

" ============================================================================
" Provider Interface — see autoload/git_open/github.vim for the full contract
"
" Codeberg URL differences from GitHub:
"   branch view:          /src/branch/{branch}
"   file at branch:       /src/branch/{branch}/{file}
"   file at commit:       /src/commit/{commit}/{file}
"   single PR:            /pulls/{number}   (not /pull/)
"   commit:               /commit/{hash}    (same as GitHub)
"   PR list state param:  ?state=open|closed  (Gitea API; no 'merged' state)
" ============================================================================

" ============================================================================
" URL pattern helpers
" ============================================================================

" {base_url}/{path} — root URL for all repo-scoped paths
function! s:RepoBase(repo_info) abort
    return a:repo_info.base_url . '/' . a:repo_info.path
endfunction

function! s:BranchPath(branch) abort
    return '/src/branch/' . a:branch
endfunction

" ref may be a 40-char commit hash or a branch name — Codeberg requires
" different path segments for each (/src/commit/ vs /src/branch/)
function! s:FilePath(ref, file) abort
    let l:ref_type = a:ref =~# '^[0-9a-f]\{40\}$' ? 'commit' : 'branch'
    return '/src/' . l:ref_type . '/' . a:ref . '/' . a:file
endfunction

function! s:CommitPath(commit) abort
    return '/commit/' . a:commit
endfunction

" Codeberg uses /pulls/{number} (plural), unlike GitHub's /pull/{number}
function! s:RequestPath(number) abort
    return '/pulls/' . a:number
endfunction

function! s:RequestsPath() abort
    return '/pulls'
endfunction

" Codeberg user-scoped PR list uses the same /pulls root as the repo list.
function! s:MyRequestsPath() abort
    return '/pulls'
endfunction

" Returns the query string (including '?') for a repo-scoped PR list, or ''.
" state_arg: '', '-open', '-closed', '-merged', '-all'
" Codeberg (Gitea) uses ?state=open|closed; no 'merged' state — '-merged' maps to closed.
" '-all' shows all PRs without a state filter.
function! s:RequestsQuery(state_arg) abort
    let l:arg = tolower(trim(a:state_arg))
    if l:arg ==# '-closed' || l:arg ==# '-merged'
        return '?state=closed'
    endif
    return ''
endfunction

" Returns the query string (including '?') for a user-scoped PR list, or ''.
" state_arg: '', '-open', '-closed', '-merged', '-all'
" Codeberg uses type=created_by to filter to the current user.
function! s:MyRequestsQuery(state_arg) abort
    let l:arg = tolower(trim(a:state_arg))
    if l:arg ==# '-closed' || l:arg ==# '-merged'
        return '?type=created_by&state=closed'
    elseif l:arg ==# '-all'
        return '?type=created_by'
    endif
    return ''
endfunction

" ============================================================================
" Line anchor
" ============================================================================

" Codeberg uses #L10 or #L10-L20 anchors (same format as GitHub)
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

" Codeberg uses #1234 for PR references in commit messages (same as GitHub)
function! git_open#codeberg#ParseRequestNumber(message) abort
    let l:match = matchlist(a:message, '#\(\d\+\)')
    return empty(l:match) ? '' : l:match[1]
endfunction

function! git_open#codeberg#BuildRepoUrl(repo_info) abort
    return s:RepoBase(a:repo_info)
endfunction

function! git_open#codeberg#BuildBranchUrl(repo_info, branch) abort
    return s:RepoBase(a:repo_info) . s:BranchPath(a:branch)
endfunction

function! git_open#codeberg#BuildFileUrl(repo_info, file, line_info, ref) abort
    let l:url = s:RepoBase(a:repo_info) . s:FilePath(a:ref, a:file)
    if !empty(a:line_info)
        let l:url .= s:FormatLineAnchor(a:line_info)
    endif
    return l:url
endfunction

function! git_open#codeberg#BuildCommitUrl(repo_info, commit) abort
    return s:RepoBase(a:repo_info) . s:CommitPath(a:commit)
endfunction

function! git_open#codeberg#BuildRequestUrl(repo_info, number) abort
    return s:RepoBase(a:repo_info) . s:RequestPath(a:number)
endfunction

" '-merged' is treated as '-closed' (Gitea has no 'merged' state param).
" '-all' returns bare /pulls with no state filter.
function! git_open#codeberg#BuildRequestsUrl(repo_info, state_arg) abort
    return s:RepoBase(a:repo_info) . s:RequestsPath() . s:RequestsQuery(a:state_arg)
endfunction

" Codeberg personal PR page uses type=created_by to filter to current user.
"   no flag / -open  → /pulls            (Gitea already scopes to open PRs)
"   -all             → /pulls?type=created_by
"   -closed/-merged  → /pulls?type=created_by&state=closed
function! git_open#codeberg#BuildMyRequestsUrl(repo_info, state_arg) abort
    return a:repo_info.base_url . s:MyRequestsPath() . s:MyRequestsQuery(a:state_arg)
endfunction
