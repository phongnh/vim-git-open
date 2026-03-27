" git_open.vim - Open git resources in browser
" Maintainer:   Phong Nguyen
" Version:      1.0.0

if exists('g:loaded_git_open') || &compatible || has('nvim')
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
command! -nargs=0 OpenGitRepo call git_open#open_repo()
command! -nargs=0 OpenGitBranch call git_open#open_branch()
command! -nargs=0 -range OpenGitFile <line1>,<line2>call git_open#open_file()
command! -nargs=0 OpenGitCommit call git_open#open_commit()
command! -nargs=? OpenGitPR call git_open#open_pr(<q-args>)
command! -nargs=? OpenGitMR call git_open#open_mr(<q-args>)
command! -nargs=0 OpenGitFileLastChange call git_open#open_file_last_change()
command! -nargs=0 OpenGitMyPRs call git_open#open_my_prs()
command! -nargs=0 OpenGitPRs call git_open#open_prs()

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo
