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

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
