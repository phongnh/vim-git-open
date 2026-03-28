local fn = vim.fn
local repo_root = fn.fnamemodify(fn.expand('<sfile>:p'), ':h:h:h')
local test_repo = fn.tempname()
fn.mkdir(test_repo, 'p')
fn.writefile({ 'alpha', 'beta' }, test_repo .. '/README.md')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' init -q')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' config user.email test@example.com')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' config user.name "Test User"')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' add README.md')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' commit -q -m "Initial (#7)"')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' branch -M main')
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' remote add origin git@github.com:acme/demo.git')
local capture_script = repo_root .. '/tests/helpers/capture_url.sh'
local capture_file = test_repo .. '/captured_url.txt'
vim.env.GIT_OPEN_CAPTURE_FILE = capture_file
fn.setenv('GIT_OPEN_CAPTURE_FILE', capture_file)
local git_open = require('git_open')
git_open.setup({ browser_command = capture_script })
vim.cmd('edit ' .. fn.fnameescape(test_repo .. '/README.md'))
local failures = {}
local function last_url()
  if fn.filereadable(capture_file) == 0 then
    return ''
  end
  local lines = fn.readfile(capture_file)
  if #lines == 0 then
    return ''
  end
  return lines[#lines]
end
local function assert_equal(name, expected, actual)
  if expected ~= actual then
    table.insert(failures, string.format('%s expected=%s actual=%s', name, expected, actual))
  end
end
git_open.open_repo()
assert_equal('repo-github', 'https://github.com/acme/demo', last_url())
local commit = vim.trim(fn.system('git -C ' .. fn.shellescape(test_repo) .. ' rev-parse HEAD'))
git_open.open_file(1, 2)
assert_equal('file-range-github', 'https://github.com/acme/demo/blob/' .. commit .. '/README.md#L1-L2', last_url())
git_open.open_request('')
assert_equal('request-from-commit-github', 'https://github.com/acme/demo/pull/7', last_url())
fn.system('git -C ' .. fn.shellescape(test_repo) .. ' remote set-url origin git@gitlab.com:acme/demo.git')
git_open.open_file(1, 2)
assert_equal('file-range-gitlab', 'https://gitlab.com/acme/demo/-/blob/' .. commit .. '/README.md#L1-2', last_url())
git_open.open_request('12')
assert_equal('request-explicit-gitlab', 'https://gitlab.com/acme/demo/-/merge_requests/12', last_url())
if #failures > 0 then
  for _, msg in ipairs(failures) do
    io.stderr:write(msg .. '\n')
  end
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
