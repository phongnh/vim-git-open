# vim-git-open - CHANGELOG

## Version 1.4.0

### New Features

#### Multi-Remote Support
- **Provider-named commands** are now automatically registered at startup for each non-origin remote
- At `VimEnter`, the plugin scans all configured remotes (excluding `origin`), detects the provider for each, and registers a full set of commands scoped to that remote
- **GitHub remote commands**: `OpenGitHubRepo[!]`, `OpenGitHubBranch[!]`, `OpenGitHubFile[!]`, `OpenGitHubCommit[!]`, `OpenGitHubPR[!]`, `OpenGitHubPRs[!]`, `OpenGitHubMyPRs[!]`
- **GitLab remote commands**: `OpenGitLabRepo[!]`, `OpenGitLabBranch[!]`, `OpenGitLabFile[!]`, `OpenGitLabCommit[!]`, `OpenGitLabMR[!]`, `OpenGitLabMRs[!]`, `OpenGitLabMyMRs[!]`
- **Codeberg remote commands**: `OpenCodebergRepo[!]`, `OpenCodebergBranch[!]`, `OpenCodebergFile[!]`, `OpenCodebergCommit[!]`, `OpenCodebergPR[!]`, `OpenCodebergPRs[!]`, `OpenCodebergMyPRs[!]`
- Commands are only registered for providers actually present in the repo — no extra commands for providers with no remote
- If two non-origin remotes resolve to the same provider, last-one-wins; a warning is printed at startup identifying which remote/domain the commands now point to and which was overwritten
- All commands support bang (`!`) for clipboard copy, visual mode for branch/commit selection, line range for file commands, and state flags for PR/MR listing — identical to the origin equivalents
- Tab-completion for branch names and state flags is wired to all provider-named commands

### Internal

#### ParseRemoteUrl Refactor
- `ParseRemoteUrl` (all three implementations) now accepts a `remote_name` parameter (default `'origin'`) instead of hardcoding `remote.origin.url`
- `GetRepoInfo` / `get_repo_info` explicitly passes `'origin'` — behaviour is identical to before
- New `GetAllRemotes` / `get_all_remotes`: returns list of all remote names excluding `origin`
- New `GetRepoInfoForRemote` / `get_repo_info_for_remote`: like `GetRepoInfo` but for a named remote; no error on missing remote (caller handles it)
- New per-remote public API functions: `OpenRepoForRemote`, `OpenBranchForRemote`, `OpenFileForRemote`, `OpenCommitForRemote`, `OpenRequestForRemote`, `OpenRequestsForRemote`, `OpenMyRequestsForRemote`
- These are thin wrappers — all URL-building logic stays in the existing `BuildUrl` / `BuildGithubUrl` / `BuildGitlabUrl` functions

### Updated Files
- `autoload/git_open.vim` — `ParseRemoteUrl` refactor; new `GetAllRemotes`, `GetRepoInfoForRemote`, per-remote API functions
- `autoload/git_open/legacy.vim` — same; new public functions exposed via `git_open#legacy#` namespace
- `lua/git_open.lua` — same; new `M.get_all_remotes`, `M.get_repo_info_for_remote`, per-remote API functions
- `plugin/git_open.vim` — dynamic command registration via `execute` + `VimEnter` autocommand
- `plugin/git_open_legacy.vim` — same; commands use `git_open#legacy#*` functions
- `plugin/git_open.lua` — dynamic command registration via `nvim_create_user_command` + `VimEnter` autocmd
- `README.md` — new "Multi-remote support" section with command tables
- `doc/git_open.txt` — new section 5 documenting all provider-named commands

---

## Version 1.3.0

### New Features

#### Gitk Commands
- **New commands: `:OpenGitk`, `:OpenGitkFile`, `:OpenGitkFileHistory`** — launch gitk for repository, current file, or full rename history
- **`:Gitk`** — alias for `:OpenGitk`
- **`:GitkFile`** — alias for `:OpenGitkFile`
- `:OpenGitk` tab-completes branches and tracked files
- `:OpenGitkFile!` adds `--follow` to trace rename history across renames
- `:OpenGitkFileHistory` resolves all historical paths via `git log --follow` and passes them to gitk

#### Visual Mode for OpenGitBranch and OpenGitCommit
- `:OpenGitBranch` now supports visual mode: selected text is used as the branch name
- `:OpenGitCommit` now supports visual mode: selected text is used as the commit hash
- In normal mode with no argument, both commands continue to use the current branch / HEAD commit

### Bug Fixes

#### GetGitRoot — Fugitive Virtual Buffer Support
- Fixed git root detection inside fugitive virtual buffers (`fugitive://` scheme, `fugitiveblame` filetype)
- **Root cause (Vim9script):** `exists('*FugitiveGitDir')` inside a `def` function is always `false` at compile time, even when vim-fugitive is loaded. Fixed by replacing the `exists()` guard with `try/catch` around `call('FugitiveGitDir', [])`.
- GetGitRoot now uses a 3-step detection strategy:
  1. `call('FugitiveGitDir', [])` via `try/catch` — handles fugitive virtual buffers
  2. `finddir('.git', expand('%:p:h') .. ';')` — handles normal file buffers
  3. `finddir('.git', getcwd() .. ';')` — fallback for terminal/quickfix/empty buffers

#### OpenGitBranch / OpenGitCommit Normal Mode Fallback
- Fixed: when called in normal mode with no argument, `OpenGitBranch` and `OpenGitCommit` now correctly fall back to the current branch / HEAD commit
- Previously, the fallback inside `BuildUrl` was bypassed because `OpenBranch`/`OpenCommit` always passed an explicit (empty) argument, making `len(extra) > 0` always true

### Internal

#### Completion Refactor
- Extracted `Unique(items)` helper (replaces `UniqueAdd` that mutated in-place) across all three implementations
- Extracted `FuzzyFilter(items, arg)` helper to consolidate fuzzy matching logic

### Updated Files
- `autoload/git_open.vim` — GetGitRoot fix, OpenBranch/OpenCommit fallback, visual selection, Gitk commands, completion refactor
- `autoload/git_open/legacy.vim` — same
- `lua/git_open.lua` — same; also removed duplicate `get_git_root()` function
- `plugin/git_open.vim` — added Gitk/GitkFile/GitkFileHistory commands and aliases
- `plugin/git_open_legacy.vim` — same
- `plugin/git_open.lua` — same
- `README.md` — documented new commands, visual mode, Gitk aliases, fugitive troubleshooting
- `doc/git_open.txt` — same

---

## Version 1.1.0

### New Features

#### OpenGitFileLastChange Command
- **New command: `:OpenGitFileLastChange`** - Opens the last change (PR/MR or commit) for the current file
- Finds the latest commit that modified the current file
- If the commit message contains a PR/MR number, opens that PR/MR
- Otherwise, opens the commit itself
- Useful for quickly jumping to the pull/merge request that introduced changes to the file

#### $BROWSER Environment Variable Support
- **Browser detection now checks `$BROWSER` first** before falling back to OS defaults
- Detection order:
  1. `g:vim_git_open_browser_command` (user override in config)
  2. `$BROWSER` environment variable (if set)
  3. OS-specific defaults (open/xdg-open/start)
- Follows standard Unix convention for browser selection
- Works across all three implementations

#### Examples
```vim
" Open the last change for current file
:OpenGitFileLastChange

" If the file's latest commit message is "Fix bug (#456)", opens PR #456
" If the commit message has no PR/MR, opens the commit page
```

```bash
# Set browser via environment variable
export BROWSER=firefox
```

### Bug Fixes
- Fixed undefined function errors in `OpenGitFileLastChange`:
  - Corrected `get_file_path()` → `get_relative_path()`
  - Added `parse_pr_mr_number()` helper function for message parsing

### Updated Files
- `autoload/git_open.vim` - Added `open_file_last_change()` and `parse_pr_mr_number()` functions
- `plugin/git_open.vim` - Added `:OpenGitFileLastChange` command, $BROWSER support
- `vim9/autoload/git_open.vim` - Added `OpenFileLastChange()` and `ParsePrMrNumber()` functions
- `vim9/plugin/git_open.vim` - Added `:OpenGitFileLastChange` command, $BROWSER support
- `lua/git_open.lua` - Added `open_file_last_change()` and `parse_pr_mr_number()` functions, $BROWSER support
- `plugin/git_open.lua` - Added `:OpenGitFileLastChange` command (moved from lua_plugin/)
- `README.md` - Documented new command and $BROWSER support
- `doc/git_open.txt` - Updated help documentation
- `.opencode/conversation-log.md` - Updated with new feature details

### Implementation Details
The command executes the following logic:
1. Gets the file path relative to git root
2. Runs `git log -1 --format=%H -- <file>` to get latest commit hash
3. Runs `git log -1 --format=%B <commit>` to get commit message
4. Attempts to parse PR/MR number from commit message
5. Opens PR/MR if found, otherwise opens commit

Browser detection priority:
1. User config (`g:vim_git_open_browser_command`)
2. Environment variable (`$BROWSER`)
3. OS default (open/xdg-open/start)

### All Three Implementations
All features available in:
- Legacy Vimscript (Vim 7.0+)
- Vim9script (Vim 9.0+)
- Lua (Neovim 0.5+)

---

## Version 1.0.0

### Features

#### Line Number Support
- **`:OpenGitFile`** now automatically includes the current line number when opening files
- Works in both normal mode (single line) and visual mode (line range)
- Format adapts to Git provider:
  - GitHub/Codeberg: `#L10` or `#L10-L20` for ranges
  - GitLab: `#L10` or `#L10-20` for ranges

#### Examples
```vim
" Open file at current line (e.g., line 42)
:OpenGitFile
" Opens: https://github.com/user/repo/blob/abc123/file.txt#L42

" Select lines 10-20 in visual mode, then:
:'<,'>OpenGitFile
" Opens: https://github.com/user/repo/blob/abc123/file.txt#L10-L20
```

### Code Quality Improvements
- **Legacy Vimscript**: Re-indented to 4 spaces for consistency
- **Vim9script**: Re-indented to 4 spaces for consistency
- **Lua**: Maintained 2-space indentation (standard Lua style)

### Updated Files
- `autoload/git_open.vim` - Added line number detection and formatting
- `plugin/git_open.vim` - Added `-range` support to OpenGitFile
- `vim9/autoload/git_open.vim` - Added line number support with 4-space indent
- `vim9/plugin/git_open.vim` - Added `-range` support with 4-space indent
- `lua/git_open.lua` - Added line number support (2-space indent)
- `lua_plugin/git_open.lua` - Added range support
- `README.md` - Documented line number feature
- `doc/git_open.txt` - Updated help documentation
- `example_config.vim` - Added visual mode keymap examples

## Implementation Details

### Line Number Detection
The plugin detects line numbers in two ways:
1. **Normal mode**: Uses `line('.')` to get current line
2. **Visual mode**: Uses `line("'<")` and `line("'>")` to get range

### Provider-Specific Formatting
- GitHub/Codeberg format: `#L{start}-L{end}`
- GitLab format: `#L{start}-{end}`

The formatting is automatically applied based on the detected Git provider.

### All Three Implementations
All features are available in:
- Legacy Vimscript (Vim 7.0+)
- Vim9script (Vim 9.0+)
- Lua (Neovim 0.5+)
