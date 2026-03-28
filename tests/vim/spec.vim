let s:repo_root = fnamemodify(expand('<sfile>:p'), ':h:h:h')
let s:test_repo = tempname()
call mkdir(s:test_repo, 'p')
call writefile(['alpha', 'beta'], s:test_repo . '/README.md')
call system('git -C ' . shellescape(s:test_repo) . ' init -q')
call system('git -C ' . shellescape(s:test_repo) . ' config user.email test@example.com')
call system('git -C ' . shellescape(s:test_repo) . ' config user.name "Test User"')
call system('git -C ' . shellescape(s:test_repo) . ' add README.md')
call system('git -C ' . shellescape(s:test_repo) . ' commit -q -m "Initial (#7)"')
call system('git -C ' . shellescape(s:test_repo) . ' branch -M main')
call system('git -C ' . shellescape(s:test_repo) . ' remote add origin git@github.com:acme/demo.git')
let s:capture_script = s:repo_root . '/tests/helpers/capture_url.sh'
let s:capture_file = s:test_repo . '/captured_url.txt'
let g:vim_git_open_browser_command = s:capture_script
let $GIT_OPEN_CAPTURE_FILE = s:capture_file
set nomore
execute 'set rtp^=' . fnameescape(s:repo_root)
if has('vim9script')
    execute 'source ' . fnameescape(s:repo_root . '/plugin/git_open.vim')
else
    execute 'source ' . fnameescape(s:repo_root . '/plugin/git_open_legacy.vim')
endif
execute 'edit ' . fnameescape(s:test_repo . '/README.md')
let s:failed = []
function! s:assert_equal(name, expected, actual) abort
    if a:expected !=# a:actual
        call add(s:failed, a:name . ' expected=' . a:expected . ' actual=' . a:actual)
    endif
endfunction
function! s:last_url() abort
    if !filereadable(s:capture_file)
        return ''
    endif
    let l:lines = readfile(s:capture_file)
    return empty(l:lines) ? '' : l:lines[-1]
endfunction
OpenGitRepo
call s:assert_equal('repo-github', 'https://github.com/acme/demo', s:last_url())
let s:commit = substitute(system('git -C ' . shellescape(s:test_repo) . ' rev-parse HEAD'), '\n\+$', '', '')
1,2OpenGitFile
call s:assert_equal('file-range-github', 'https://github.com/acme/demo/blob/' . s:commit . '/README.md#L1-L2', s:last_url())
OpenGitRequest
call s:assert_equal('request-from-commit-github', 'https://github.com/acme/demo/pull/7', s:last_url())
call system('git -C ' . shellescape(s:test_repo) . ' remote set-url origin git@gitlab.com:acme/demo.git')
1,2OpenGitFile
call s:assert_equal('file-range-gitlab', 'https://gitlab.com/acme/demo/-/blob/' . s:commit . '/README.md#L1-2', s:last_url())
OpenGitRequest 12
call s:assert_equal('request-explicit-gitlab', 'https://gitlab.com/acme/demo/-/merge_requests/12', s:last_url())
if !empty(s:failed)
    for s:item in s:failed
        echom s:item
    endfor
    cquit 1
endif
qa!
