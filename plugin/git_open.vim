" plugin/git_open_legacy.vim - Open git resources in browser (legacy Vimscript)
" Maintainer:   Phong Nguyen
" Version:      1.0.0

if has('nvim') || exists('g:loaded_git_open')
    finish
endif

" Use Vim9script implementation if available, otherwise fall back to legacy
if has('vim9script')
    " Add vim9/ subdirectory to runtimepath so vim9/autoload/git_open.vim
    " is found when the Vim9script plugin sources it via 'import autoload'
    let s:vim9dir = fnamemodify(resolve(expand('<sfile>:p')), ':h:h') .. '/vim9'
    if &runtimepath !~# s:vim9dir
        execute 'set runtimepath^=' . fnameescape(s:vim9dir)
    endif
    unlet! s:vim9dir
    source <sfile>:p:h:h/vim9/plugin/git_open.vim
    finish
endif

let g:loaded_git_open = 1

" Save cpoptions
let s:save_cpo = &cpoptions
set cpoptions&vim

" User configuration
if !exists('g:vim_git_open_domains')
    let g:vim_git_open_domains = {}
endif

if !exists('g:vim_git_open_providers')
    let g:vim_git_open_providers = {}
endif

if !exists('g:vim_git_open_remote')
    let g:vim_git_open_remote = ''
endif

if !exists('g:vim_git_open_browser_command') || empty(g:vim_git_open_browser_command)
    if has('mac') || has('macunix')
        let g:vim_git_open_browser_command = 'open'
    elseif has('win32') || has('win64')
        let g:vim_git_open_browser_command = 'start'
    else
        let g:vim_git_open_browser_command = 'xdg-open'
    endif
endif
if !empty($BROWSER)
    let g:vim_git_open_browser_command = $BROWSER
endif

" Commands
command! -bang -nargs=0 OpenGitRepo call git_open#OpenRepo(<bang>0)
command! -bang -nargs=? -range=0 -complete=customlist,git_open#CompleteBranch OpenGitBranch call git_open#OpenBranch(<q-args>, <bang>0, <count> > 0)
command! -bang -nargs=? -range -complete=customlist,git_open#CompleteBranch OpenGitFile call git_open#OpenFile(<line1>, <line2>, <q-args>, <bang>0)
command! -bang -nargs=? -range=0 OpenGitCommit call git_open#OpenCommit(<q-args>, <bang>0, <count> > 0)
command! -bang -nargs=? OpenGitRequest call git_open#OpenRequest(<q-args>, <bang>0)
command! -bang -nargs=0 OpenGitFileLastChange call git_open#OpenFileLastChange(<bang>0)
command! -bang -nargs=? -complete=customlist,git_open#CompleteMyRequestState OpenGitMyRequests call git_open#OpenMyRequests(<q-args>, <bang>0)
command! -bang -nargs=? -complete=customlist,git_open#CompleteRequestState OpenGitRequests call git_open#OpenRequests(<q-args>, <bang>0)
command! -nargs=* -complete=customlist,git_open#CompleteGitkArgs OpenGitk call git_open#OpenGitk(<q-args>)
command! -bang -nargs=* -complete=customlist,git_open#CompleteGitkBranch OpenGitkFile call git_open#OpenGitkFile(<q-args>, <bang>0)
command! -nargs=* -complete=customlist,git_open#CompleteGitkArgs Gitk call git_open#OpenGitk(<q-args>)
command! -bang -nargs=* -complete=customlist,git_open#CompleteGitkBranch GitkFile call git_open#OpenGitkFile(<q-args>, <bang>0)
command! -bang -nargs=? -complete=customlist,git_open#CompleteGitRemote OpenGitRemote call git_open#OpenGitRemote(<q-args>, <bang>0)

" Register provider-named commands for each non-origin remote.
" The remote name is embedded as a literal quoted string in each command body
" so that <bang>0, <q-args> etc. expand correctly at invocation time.
function! s:register_multi_remote_commands() abort
    let l:remotes = git_open#GetAllRemotes()
    if empty(l:remotes)
        return
    endif

    " Skip remotes that share the same domain as origin — they would produce
    " identical provider-named commands for an already-covered hosting service.
    let l:origin_info = git_open#GetRepoInfo()
    let l:origin_domain = empty(l:origin_info) ? '' : l:origin_info.domain

    let l:provider_remote = {}
    let l:provider_domain = {}
    let l:overwritten = []

    for l:r in l:remotes
        let l:info = git_open#GetRepoInfoForRemote(l:r)
        if empty(l:info)
            continue
        endif
        " Same domain as origin → already covered by the origin-based commands
        if !empty(l:origin_domain) && l:info.domain ==# l:origin_domain
            continue
        endif
        let l:p = l:info.provider
        if has_key(l:provider_remote, l:p)
            call add(l:overwritten, printf(
                        \ "git-open: Open%s* now points to remote '%s' (%s) — '%s' (%s) was overwritten",
                        \ l:p, l:r, l:info.domain, l:provider_remote[l:p], l:provider_domain[l:p]
                        \ ))
        endif
        let l:provider_remote[l:p] = l:r
        let l:provider_domain[l:p] = l:info.domain

        " Embed the remote name as a quoted literal in each command string.
        let l:rs = string(l:r)
        if l:p ==# 'GitHub'
            execute 'command! -bang -nargs=0 OpenGitHubRepo'
                        \ 'call git_open#OpenRepoForRemote(' . l:rs . ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                        \ '-complete=customlist,git_open#CompleteBranch'
                        \ 'OpenGitHubBranch'
                        \ 'call git_open#OpenBranchForRemote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                        \ '-complete=customlist,git_open#CompleteBranch'
                        \ 'OpenGitHubFile'
                        \ 'call git_open#OpenFileForRemote(' . l:rs . ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                        \ 'OpenGitHubCommit'
                        \ 'call git_open#OpenCommitForRemote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenGitHubPR'
                        \ 'call git_open#OpenRequestForRemote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                        \ '-complete=customlist,git_open#CompleteRequestState'
                        \ 'OpenGitHubPRs'
                        \ 'call git_open#OpenRequestsForRemote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                        \ '-complete=customlist,git_open#CompleteMyRequestState'
                        \ 'OpenGitHubMyPRs'
                        \ 'call git_open#OpenMyRequestsForRemote(' . l:rs . ', <q-args>, <bang>0)'
        elseif l:p ==# 'GitLab'
            execute 'command! -bang -nargs=0 OpenGitLabRepo'
                        \ 'call git_open#OpenRepoForRemote(' . l:rs . ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                        \ '-complete=customlist,git_open#CompleteBranch'
                        \ 'OpenGitLabBranch'
                        \ 'call git_open#OpenBranchForRemote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                        \ '-complete=customlist,git_open#CompleteBranch'
                        \ 'OpenGitLabFile'
                        \ 'call git_open#OpenFileForRemote(' . l:rs . ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                        \ 'OpenGitLabCommit'
                        \ 'call git_open#OpenCommitForRemote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenGitLabMR'
                        \ 'call git_open#OpenRequestForRemote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                        \ '-complete=customlist,git_open#CompleteRequestState'
                        \ 'OpenGitLabMRs'
                        \ 'call git_open#OpenRequestsForRemote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                        \ '-complete=customlist,git_open#CompleteMyRequestState'
                        \ 'OpenGitLabMyMRs'
                        \ 'call git_open#OpenMyRequestsForRemote(' . l:rs . ', <q-args>, <bang>0)'
        elseif l:p ==# 'Codeberg'
            execute 'command! -bang -nargs=0 OpenCodebergRepo'
                        \ 'call git_open#OpenRepoForRemote(' . l:rs . ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                        \ '-complete=customlist,git_open#CompleteBranch'
                        \ 'OpenCodebergBranch'
                        \ 'call git_open#OpenBranchForRemote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                        \ '-complete=customlist,git_open#CompleteBranch'
                        \ 'OpenCodebergFile'
                        \ 'call git_open#OpenFileForRemote(' . l:rs . ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                        \ 'OpenCodebergCommit'
                        \ 'call git_open#OpenCommitForRemote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenCodebergPR'
                        \ 'call git_open#OpenRequestForRemote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                        \ '-complete=customlist,git_open#CompleteRequestState'
                        \ 'OpenCodebergPRs'
                        \ 'call git_open#OpenRequestsForRemote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                        \ '-complete=customlist,git_open#CompleteMyRequestState'
                        \ 'OpenCodebergMyPRs'
                        \ 'call git_open#OpenMyRequestsForRemote(' . l:rs . ', <q-args>, <bang>0)'
        endif
    endfor

    for l:msg in l:overwritten
        echohl WarningMsg
        echom l:msg
        echohl None
    endfor
endfunction

augroup GitOpenMultiRemote
    autocmd!
    autocmd VimEnter * ++once call timer_start(0, {-> s:register_multi_remote_commands()})
augroup END

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
