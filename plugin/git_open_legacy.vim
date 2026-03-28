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
command! -nargs=0 OpenGitRepo call git_open#legacy#open_repo()
command! -nargs=0 OpenGitBranch call git_open#legacy#open_branch()
command! -nargs=0 -range OpenGitFile <line1>,<line2>call git_open#legacy#open_file()
command! -nargs=0 OpenGitCommit call git_open#legacy#open_commit()
command! -nargs=? OpenGitRequest call git_open#legacy#open_request(<q-args>)
command! -nargs=0 OpenGitFileLastChange call git_open#legacy#open_file_last_change()
command! -nargs=0 OpenGitMyRequests call git_open#legacy#open_my_requests()
command! -nargs=0 OpenGitRequests call git_open#legacy#open_requests()

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
