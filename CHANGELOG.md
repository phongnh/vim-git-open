# vim-git-open - CHANGELOG

## Version 1.1.0

### New Features

#### OpenGitFileLastChange Command
- **New command: `:OpenGitFileLastChange`** - Opens the last change (PR/MR or commit) for the current file
- Finds the latest commit that modified the current file
- If the commit message contains a PR/MR number, opens that PR/MR
- Otherwise, opens the commit itself
- Useful for quickly jumping to the pull/merge request that introduced changes to the file

#### Examples
```vim
" Open the last change for current file
:OpenGitFileLastChange

" If the file's latest commit message is "Fix bug (#456)", opens PR #456
" If the commit message has no PR/MR, opens the commit page
```

### Updated Files
- `autoload/git_open.vim` - Added `open_file_last_change()` function
- `plugin/git_open.vim` - Added `:OpenGitFileLastChange` command
- `vim9/autoload/git_open.vim` - Added `OpenFileLastChange()` function
- `vim9/plugin/git_open.vim` - Added `:OpenGitFileLastChange` command
- `lua/git_open.lua` - Added `open_file_last_change()` function
- `plugin/git_open.lua` - Added `:OpenGitFileLastChange` command (moved from lua_plugin/)
- `README.md` - Documented new command
- `doc/git_open.txt` - Updated help documentation
- `.opencode/conversation-log.md` - Updated with new feature details

### Implementation Details
The command executes the following logic:
1. Gets the file path relative to git root
2. Runs `git log -1 --format=%H -- <file>` to get latest commit hash
3. Runs `git log -1 --format=%B <commit>` to get commit message
4. Attempts to parse PR/MR number from commit message
5. Opens PR/MR if found, otherwise opens commit

### All Three Implementations
Feature is available in:
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
