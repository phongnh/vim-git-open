vim9script

# git_open.vim - Open git resources in browser (Vim9script version)
# Maintainer:   Phong Nguyen
# Version:      1.0.0

if exists('g:loaded_git_open')
    finish
endif
g:loaded_git_open = 1

# User configuration
if !exists('g:vim_git_open_domains')
    g:vim_git_open_domains = {}
endif

if !exists('g:vim_git_open_providers')
    g:vim_git_open_providers = {}
endif

if !exists('g:vim_git_open_browser_command')
    # Check for $BROWSER environment variable first
    if !empty($BROWSER)
        g:vim_git_open_browser_command = $BROWSER
    elseif has('mac') || has('macunix')
        g:vim_git_open_browser_command = 'open'
    elseif has('unix')
        g:vim_git_open_browser_command = 'xdg-open'
    elseif has('win32') || has('win64')
        g:vim_git_open_browser_command = 'start'
    else
        g:vim_git_open_browser_command = ''
    endif
endif

# Commands
command! -nargs=0 OpenGitRepo git_open#OpenRepo()
command! -nargs=0 OpenGitBranch git_open#OpenBranch()
command! -nargs=0 -range OpenGitFile <line1>,<line2>git_open#OpenFile()
command! -nargs=0 OpenGitCommit git_open#OpenCommit()
command! -nargs=? OpenGitPR git_open#OpenPR(<q-args>)
command! -nargs=? OpenGitMR git_open#OpenMR(<q-args>)
command! -nargs=0 OpenGitFileLastChange git_open#OpenFileLastChange()
