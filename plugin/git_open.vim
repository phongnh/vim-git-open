" plugin/git_open.vim - Open git resources in browser (Vim9script)
" Maintainer:   Phong Nguyen
" Version:      1.0.0

if !has('vim9script') || has('nvim') || exists('g:loaded_git_open')
    finish
endif

vim9script

g:loaded_git_open = 1

import autoload 'git_open.vim' as GitOpen

# User configuration
if !exists('g:vim_git_open_domains')
    g:vim_git_open_domains = {}
endif

if !exists('g:vim_git_open_providers')
    g:vim_git_open_providers = {}
endif

if !exists('g:vim_git_open_remote')
    g:vim_git_open_remote = ''
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
command! -bang -nargs=0 OpenGitRepo GitOpen.OpenRepo(<bang>0)
command! -bang -nargs=? -range=0 -complete=customlist,git_open#CompleteBranch OpenGitBranch GitOpen.OpenBranch(<q-args>, <bang>0, <count> > 0)
command! -bang -nargs=? -range -complete=customlist,git_open#CompleteBranch OpenGitFile GitOpen.OpenFile(<line1>, <line2>, <q-args>, <bang>0)
command! -bang -nargs=? -range=0 OpenGitCommit GitOpen.OpenCommit(<q-args>, <bang>0, <count> > 0)
command! -bang -nargs=? OpenGitRequest GitOpen.OpenRequest(<q-args>, <bang>0)
command! -bang -nargs=0 OpenGitFileLastChange GitOpen.OpenFileLastChange(<bang>0)
command! -bang -nargs=? -complete=customlist,git_open#CompleteMyRequestState OpenGitMyRequests GitOpen.OpenMyRequests(<q-args>, <bang>0)
command! -bang -nargs=? -complete=customlist,git_open#CompleteRequestState OpenGitRequests GitOpen.OpenRequests(<q-args>, <bang>0)
command! -nargs=* -complete=customlist,git_open#CompleteGitkArgs OpenGitk GitOpen.OpenGitk(<q-args>)
command! -bang -nargs=* -complete=customlist,git_open#CompleteGitkBranch OpenGitkFile GitOpen.OpenGitkFile(<q-args>, <bang>0)
command! -bang -nargs=* -complete=customlist,git_open#CompleteGitkArgs Gitk GitOpen.OpenGitk(<q-args>)
command! -bang -nargs=* -complete=customlist,git_open#CompleteGitkBranch GitkFile GitOpen.OpenGitkFile(<q-args>, <bang>0)
command! -bang -nargs=? -complete=customlist,git_open#CompleteGitRemote OpenGitRemote GitOpen.OpenGitRemote(<q-args>, <bang>0)

# Register provider-named commands for each non-origin remote.
# Uses execute so that <bang>0, <q-args> etc. are expanded at invocation time.
# The remote name is embedded as a literal string in the command body.
def RegisterMultiRemoteCommands()
    var remotes = GitOpen.GetAllRemotes()
    if empty(remotes)
        return
    endif

    # Track last remote per provider to warn about overwrites
    var provider_remote: dict<string> = {}
    var provider_domain: dict<string> = {}
    var overwritten: list<string> = []

    for r in remotes
        var info = GitOpen.GetRepoInfoForRemote(r)
        if empty(info)
            continue
        endif
        var p = info.provider
        if has_key(provider_remote, p)
            overwritten->add(printf(
                "git-open: Open%s* now points to remote '%s' (%s) — '%s' (%s) was overwritten",
                p, r, info.domain, provider_remote[p], provider_domain[p]
            ))
        endif
        provider_remote[p] = r
        provider_domain[p] = info.domain

        # Embed the remote name as a quoted literal in each command string.
        # <bang>0, <q-args>, <line1>, <line2>, <count> expand at invocation.
        var rs = string(r)   # e.g. "'upstream'"
        if p ==# 'GitHub'
            execute 'command! -bang -nargs=0 OpenGitHubRepo'
                \ 'call git_open#OpenRepoForRemote(' .. rs .. ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ '-complete=customlist,git_open#CompleteBranch'
                \ 'OpenGitHubBranch'
                \ 'call git_open#OpenBranchForRemote(' .. rs .. ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                \ '-complete=customlist,git_open#CompleteBranch'
                \ 'OpenGitHubFile'
                \ 'call git_open#OpenFileForRemote(' .. rs .. ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ 'OpenGitHubCommit'
                \ 'call git_open#OpenCommitForRemote(' .. rs .. ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenGitHubPR'
                \ 'call git_open#OpenRequestForRemote(' .. rs .. ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#CompleteRequestState'
                \ 'OpenGitHubPRs'
                \ 'call git_open#OpenRequestsForRemote(' .. rs .. ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#CompleteMyRequestState'
                \ 'OpenGitHubMyPRs'
                \ 'call git_open#OpenMyRequestsForRemote(' .. rs .. ', <q-args>, <bang>0)'
        elseif p ==# 'GitLab'
            execute 'command! -bang -nargs=0 OpenGitLabRepo'
                \ 'call git_open#OpenRepoForRemote(' .. rs .. ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ '-complete=customlist,git_open#CompleteBranch'
                \ 'OpenGitLabBranch'
                \ 'call git_open#OpenBranchForRemote(' .. rs .. ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                \ '-complete=customlist,git_open#CompleteBranch'
                \ 'OpenGitLabFile'
                \ 'call git_open#OpenFileForRemote(' .. rs .. ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ 'OpenGitLabCommit'
                \ 'call git_open#OpenCommitForRemote(' .. rs .. ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenGitLabMR'
                \ 'call git_open#OpenRequestForRemote(' .. rs .. ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#CompleteRequestState'
                \ 'OpenGitLabMRs'
                \ 'call git_open#OpenRequestsForRemote(' .. rs .. ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#CompleteMyRequestState'
                \ 'OpenGitLabMyMRs'
                \ 'call git_open#OpenMyRequestsForRemote(' .. rs .. ', <q-args>, <bang>0)'
        elseif p ==# 'Codeberg'
            execute 'command! -bang -nargs=0 OpenCodebergRepo'
                \ 'call git_open#OpenRepoForRemote(' .. rs .. ', <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ '-complete=customlist,git_open#CompleteBranch'
                \ 'OpenCodebergBranch'
                \ 'call git_open#OpenBranchForRemote(' .. rs .. ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? -range'
                \ '-complete=customlist,git_open#CompleteBranch'
                \ 'OpenCodebergFile'
                \ 'call git_open#OpenFileForRemote(' .. rs .. ', <line1>, <line2>, <q-args>, <bang>0)'
            execute 'command! -bang -nargs=? -range=0'
                \ 'OpenCodebergCommit'
                \ 'call git_open#OpenCommitForRemote(' .. rs .. ', <q-args>, <bang>0, <count> > 0)'
            execute 'command! -bang -nargs=? OpenCodebergPR'
                \ 'call git_open#OpenRequestForRemote(' .. rs .. ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#CompleteRequestState'
                \ 'OpenCodebergPRs'
                \ 'call git_open#OpenRequestsForRemote(' .. rs .. ', <q-args>, <bang>0)'
            execute 'command! -bang -nargs=?'
                \ '-complete=customlist,git_open#CompleteMyRequestState'
                \ 'OpenCodebergMyPRs'
                \ 'call git_open#OpenMyRequestsForRemote(' .. rs .. ', <q-args>, <bang>0)'
        endif
    endfor

    for msg in overwritten
        echohl WarningMsg
        echom msg
        echohl None
    endfor
enddef

augroup git_open_multi_remote
    autocmd!
    autocmd VimEnter * ++once call RegisterMultiRemoteCommands()
augroup END
