vim9script

# plugin/git_open.vim - Open git resources in browser (Vim9script)
# Maintainer:   Phong Nguyen
# Version:      1.0.0

if !has('vim9script') || has('nvim') || exists('g:loaded_git_open')
    finish
endif
g:loaded_git_open = 1

import autoload 'git_open.vim' as GitOpen

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
command! -nargs=0 OpenGitRepo GitOpen.OpenRepo()
command! -nargs=0 OpenGitBranch GitOpen.OpenBranch()
command! -nargs=0 -range OpenGitFile <line1>,<line2>GitOpen.OpenFile()
command! -nargs=0 OpenGitCommit GitOpen.OpenCommit()
command! -nargs=? OpenGitRequest GitOpen.OpenRequest(<q-args>)
command! -nargs=0 OpenGitFileLastChange GitOpen.OpenFileLastChange()
command! -nargs=0 OpenGitMyRequests GitOpen.OpenMyRequests()
command! -nargs=0 OpenGitRequests GitOpen.OpenRequests()
