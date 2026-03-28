" plugin/git_open_legacy.vim - Open git resources in browser (legacy Vimscript)
" Maintainer:   Phong Nguyen
" Version:      1.0.0

if has('vim9script') || has('nvim') || exists('g:loaded_git_open')
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

if !exists('g:vim_git_open_browser_command')
    " Check for $BROWSER environment variable first
    if !empty($BROWSER)
        let g:vim_git_open_browser_command = $BROWSER
    elseif has('mac') || has('macunix')
        let g:vim_git_open_browser_command = 'open'
    elseif has('unix')
        let g:vim_git_open_browser_command = 'xdg-open'
    elseif has('win32') || has('win64')
        let g:vim_git_open_browser_command = 'start'
    else
        let g:vim_git_open_browser_command = ''
    endif
endif

" Commands
command! -bang -nargs=0 OpenGitRepo call git_open#legacy#open_repo(<bang>0)
command! -bang -nargs=? -range=0 -complete=customlist,git_open#legacy#complete_branch OpenGitBranch call git_open#legacy#open_branch(<q-args>, <bang>0, <count> > 0)
command! -bang -nargs=? -range -complete=customlist,git_open#legacy#complete_branch OpenGitFile call git_open#legacy#open_file(<line1>, <line2>, <q-args>, <bang>0)
command! -bang -nargs=? -range=0 OpenGitCommit call git_open#legacy#open_commit(<q-args>, <bang>0, <count> > 0)
command! -bang -nargs=? OpenGitRequest call git_open#legacy#open_request(<q-args>, <bang>0)
command! -bang -nargs=0 OpenGitFileLastChange call git_open#legacy#open_file_last_change(<bang>0)
command! -bang -nargs=? -complete=customlist,git_open#legacy#complete_my_request_state OpenGitMyRequests call git_open#legacy#open_my_requests(<q-args>, <bang>0)
command! -bang -nargs=? -complete=customlist,git_open#legacy#complete_request_state OpenGitRequests call git_open#legacy#open_requests(<q-args>, <bang>0)
command! -nargs=* -complete=customlist,git_open#legacy#complete_gitk_args OpenGitk call git_open#legacy#open_gitk(<q-args>)
command! -bang -nargs=* -complete=customlist,git_open#legacy#complete_gitk_branch OpenGitkFile call git_open#legacy#open_gitk_file(<q-args>, <bang>0)
command! -nargs=* -complete=customlist,git_open#legacy#complete_gitk_args Gitk call git_open#legacy#open_gitk(<q-args>)
command! -bang -nargs=* -complete=customlist,git_open#legacy#complete_gitk_branch GitkFile call git_open#legacy#open_gitk_file(<q-args>, <bang>0)
command! -bang -nargs=? -complete=customlist,git_open#legacy#complete_git_remote OpenGitRemote call git_open#legacy#open_git_remote(<q-args>, <bang>0)

" Register provider-named commands for each non-origin remote.
" The remote name is embedded as a literal quoted string in each command body
" so that <bang>0, <q-args> etc. expand correctly at invocation time.
function! s:register_multi_remote_commands() abort
    let l:remotes = git_open#legacy#get_all_remotes()
    if empty(l:remotes)
        return
    endif

    let l:provider_remote = {}
    let l:provider_domain = {}
    let l:overwritten = []

    for l:r in l:remotes
        let l:info = git_open#legacy#get_repo_info_for_remote(l:r)
        if empty(l:info)
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
                \ 'call git_open#legacy#open_repo_for_remote(' . l:rs . ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ '-complete=customlist,git_open#legacy#complete_branch'
                \ 'OpenGitHubBranch'
                \ 'call git_open#legacy#open_branch_for_remote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                \ '-complete=customlist,git_open#legacy#complete_branch'
                \ 'OpenGitHubFile'
                \ 'call git_open#legacy#open_file_for_remote(' . l:rs . ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ 'OpenGitHubCommit'
                \ 'call git_open#legacy#open_commit_for_remote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenGitHubPR'
                \ 'call git_open#legacy#open_request_for_remote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#legacy#complete_request_state'
                \ 'OpenGitHubPRs'
                \ 'call git_open#legacy#open_requests_for_remote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#legacy#complete_my_request_state'
                \ 'OpenGitHubMyPRs'
                \ 'call git_open#legacy#open_my_requests_for_remote(' . l:rs . ', <q-args>, <bang>0)'
        elseif l:p ==# 'GitLab'
            execute 'command! -bang -nargs=0 OpenGitLabRepo'
                \ 'call git_open#legacy#open_repo_for_remote(' . l:rs . ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ '-complete=customlist,git_open#legacy#complete_branch'
                \ 'OpenGitLabBranch'
                \ 'call git_open#legacy#open_branch_for_remote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                \ '-complete=customlist,git_open#legacy#complete_branch'
                \ 'OpenGitLabFile'
                \ 'call git_open#legacy#open_file_for_remote(' . l:rs . ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ 'OpenGitLabCommit'
                \ 'call git_open#legacy#open_commit_for_remote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenGitLabMR'
                \ 'call git_open#legacy#open_request_for_remote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#legacy#complete_request_state'
                \ 'OpenGitLabMRs'
                \ 'call git_open#legacy#open_requests_for_remote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#legacy#complete_my_request_state'
                \ 'OpenGitLabMyMRs'
                \ 'call git_open#legacy#open_my_requests_for_remote(' . l:rs . ', <q-args>, <bang>0)'
        elseif l:p ==# 'Codeberg'
            execute 'command! -bang -nargs=0 OpenCodebergRepo'
                \ 'call git_open#legacy#open_repo_for_remote(' . l:rs . ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ '-complete=customlist,git_open#legacy#complete_branch'
                \ 'OpenCodebergBranch'
                \ 'call git_open#legacy#open_branch_for_remote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                \ '-complete=customlist,git_open#legacy#complete_branch'
                \ 'OpenCodebergFile'
                \ 'call git_open#legacy#open_file_for_remote(' . l:rs . ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ 'OpenCodebergCommit'
                \ 'call git_open#legacy#open_commit_for_remote(' . l:rs . ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenCodebergPR'
                \ 'call git_open#legacy#open_request_for_remote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#legacy#complete_request_state'
                \ 'OpenCodebergPRs'
                \ 'call git_open#legacy#open_requests_for_remote(' . l:rs . ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#legacy#complete_my_request_state'
                \ 'OpenCodebergMyPRs'
                \ 'call git_open#legacy#open_my_requests_for_remote(' . l:rs . ', <q-args>, <bang>0)'
        endif
    endfor

    for l:msg in l:overwritten
        echohl WarningMsg
        echom l:msg
        echohl None
    endfor
    redraw!
endfunction

augroup git_open_multi_remote
    autocmd!
    autocmd VimEnter * ++once call s:register_multi_remote_commands()
augroup END

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
