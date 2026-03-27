# Vim-Git-Open Development Skill

## Description
Expert skill for developing and maintaining the vim-git-open plugin - a Vim/Neovim plugin that opens git resources (files, branches, commits, PRs/MRs) in a web browser. This skill provides guidelines for working with three separate implementations: Legacy Vimscript (Vim 7.0+), Vim9script (Vim 9.0+), and Lua (Neovim).

## When to Use This Skill
- Adding new features to vim-git-open
- Fixing bugs across all three implementations
- Refactoring code while maintaining feature parity
- Updating documentation
- Adding support for new git hosting providers
- Improving git remote URL parsing
- Enhancing browser integration

## Project Structure

```
vim-git-open/
├── plugin/
│   ├── git_open.vim      # Legacy Vimscript loader (guards against Neovim)
│   └── git_open.lua      # Lua loader for Neovim
├── autoload/
│   └── git_open.vim      # Legacy Vimscript core (~410 lines)
├── lua/
│   └── git_open.lua      # Lua core (~414 lines)
├── vim9/
│   ├── plugin/
│   │   └── git_open.vim  # Vim9script loader
│   └── autoload/
│       └── git_open.vim  # Vim9script core (~394 lines)
├── doc/
│   └── git_open.txt      # Vim help documentation
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── example_config.vim
└── LICENSE
```

## Core Requirements

### Commands (All Implementations)
All three implementations must provide these commands:

1. `OpenGitRepo` - Open repository home page
2. `OpenGitBranch` - Open current branch view
3. `OpenGitFile` - Open current file with line number support
4. `OpenGitCommit` - Open current commit
5. `OpenGitPR [number]` - Open pull request (GitHub/Codeberg)
6. `OpenGitMR [number]` - Open merge request (GitLab)

### Supported Git Providers
- **GitHub** (github.com and enterprise instances)
- **GitLab** (gitlab.com and self-hosted)
- **Codeberg** (codeberg.org)
- **Custom** (via user configuration)

### Provider Detection Strategy
```vim
" Use substring matching for domains
if domain =~# 'github\.com'    " Matches github.com, enterprise.github.com, etc.
    return 'GitHub'
elseif domain =~# 'gitlab\.com'  " Matches gitlab.com, gitlab.company.com, etc.
    return 'GitLab'
elseif domain =~# 'codeberg\.org'
    return 'Codeberg'
endif
```

### Remote URL Parsing
Support all common git remote formats:
- SSH: `git@github.com:user/repo.git`
- SSH: `ssh://git@github.com/user/repo.git`
- HTTPS: `https://github.com/user/repo.git`

### Line Number Support
Format line numbers according to provider:
- **GitHub/Codeberg:** `#L10-L20` (dash separator)
- **GitLab:** `#L10-20` (no dash)

Support visual mode for range selection.

## Code Style Guidelines

### Indentation
- **Legacy Vimscript:** 4 spaces
- **Vim9script:** 4 spaces
- **Lua:** 2 spaces
- **Documentation examples:** Follow language-specific rules

### Vimscript Style
```vim
" Function names: Use snake_case with s: prefix for script-local
function! s:get_git_root() abort
    " Use 4-space indentation
    let l:result = finddir('.git', expand('%:p:h') . ';')
    return fnamemodify(l:result, ':h')
endfunction

" Use explicit scoping (s:, l:, g:, a:)
" Always use abort flag on functions
" Use exists() checks for optional features
```

### Vim9script Style
```vim
vim9script

# Use def for functions, explicit types when possible
def GetGitRoot(): string
    # Use 4-space indentation
    var git_dir = finddir('.git', expand('%:p:h') .. ';')
    return fnamemodify(git_dir, ':h')
enddef

# Use var/const for variables
# Use .. for string concatenation
# Add type annotations
```

### Lua Style
```lua
local M = {}

-- Use 2-space indentation
local function get_git_root()
  local git_dir = vim.fn.finddir('.git', vim.fn.expand('%:p:h') .. ';')
  return vim.fn.fnamemodify(git_dir, ':h')
end

-- Use local for module-private functions
-- Use vim.fn for Vim functions
-- Use vim.api for Neovim API
-- Use vim.g for global variables
```

## Configuration Variables

### User-Facing Configuration
```vim
" Legacy Vimscript / Vim9script
let g:vim_git_open_domains = {}        " Custom domain mappings
let g:vim_git_open_providers = {}      " Provider overrides
let g:vim_git_open_browser_command = '' " Browser command
```

```lua
-- Lua (Neovim)
vim.g.vim_git_open_domains = {}
vim.g.vim_git_open_providers = {}
vim.g.vim_git_open_browser_command = ''
```

### Browser Command Auto-Detection
- macOS: `open`
- Linux: `xdg-open`
- Windows: `start`

## Feature Parity Requirements

**CRITICAL:** When adding features or fixing bugs, you MUST update all three implementations:
1. Legacy Vimscript (`autoload/git_open.vim`)
2. Vim9script (`vim9/autoload/git_open.vim`)
3. Lua (`lua/git_open.lua`)

All implementations must provide identical functionality and behavior.

## Testing Strategy

### Manual Testing Checklist
Test each implementation with:
- [ ] Different git hosting providers (GitHub, GitLab, Codeberg)
- [ ] Enterprise/self-hosted instances
- [ ] SSH and HTTPS remote URLs
- [ ] Line number support (single line and range)
- [ ] Visual mode selection
- [ ] PR/MR number parsing from commits
- [ ] Manual PR/MR number specification
- [ ] All six commands
- [ ] Custom domain/provider mappings

### Compatibility Testing
- Legacy Vimscript: Test with Vim 7.0+
- Vim9script: Test with Vim 9.0+
- Lua: Test with Neovim 0.5+

## Loading Mechanism

### Current Approach
- **Vim/Classic Vim:** Loads `plugin/git_open.vim` (Vimscript)
- **Neovim:** Loads `plugin/git_open.lua` (Lua)
- `plugin/git_open.vim` has guard: `if has('nvim') | finish | endif`
- No duplicate loading

### Plugin Loader Structure
```vim
" plugin/git_open.vim (Legacy Vimscript loader)
if exists('g:loaded_git_open') || &compatible || has('nvim')
    finish
endif
let g:loaded_git_open = 1

" Initialize configuration variables
" Create user commands
" Call autoload functions
```

```lua
-- plugin/git_open.lua (Neovim loader)
if vim.g.loaded_git_open then
  return
end
vim.g.loaded_git_open = 1

local git_open = require('git_open')
git_open.setup()

-- Create user commands using vim.api.nvim_create_user_command
```

## Common Patterns

### Git Command Execution
Always use `git -C <repo_root>` to run commands:
```vim
" Vimscript
let l:cmd = 'git -C ' . shellescape(l:git_root) . ' ' . a:args
let l:output = system(l:cmd)
```

```lua
-- Lua
local cmd = string.format('git -C %s %s', vim.fn.shellescape(git_root), args)
local output = vim.fn.system(cmd)
```

### Error Handling
```vim
" Vimscript
if empty(l:repo_info)
    echohl ErrorMsg
    echomsg 'git-open: Could not detect git repository'
    echohl None
    return
endif
```

```lua
-- Lua
if not repo_info then
  vim.api.nvim_echo({{'git-open: Could not detect git repository', 'ErrorMsg'}}, true, {})
  return
end
```

### Opening Browser
```vim
" Vimscript
let l:cmd = g:vim_git_open_browser_command . ' ' . shellescape(a:url)
call system(l:cmd)
```

```lua
-- Lua
local cmd = string.format('%s %s', browser_cmd, vim.fn.shellescape(url))
vim.fn.system(cmd)
```

## Documentation Requirements

### When Adding Features
1. Update README.md with usage examples
2. Update doc/git_open.txt help file
3. Update CHANGELOG.md
4. Update example_config.vim if config options added
5. Add inline code comments for complex logic

### Documentation Style
- Keep examples concise and practical
- Use proper indentation (4-space Vimscript, 2-space Lua)
- Include both Vimscript and Lua examples where applicable
- Document edge cases and limitations

## Debugging Guidelines

### Common Issues
1. **Git root not found:** Check `.git` directory search
2. **Remote URL not parsed:** Verify regex patterns
3. **Provider not detected:** Check substring matching logic
4. **Browser not opening:** Verify browser command detection
5. **Line numbers wrong:** Check visual mode range handling

### Debug Output
Add temporary debug statements:
```vim
" Vimscript
echomsg 'DEBUG: repo_info = ' . string(l:repo_info)
```

```lua
-- Lua
print('DEBUG: repo_info = ' .. vim.inspect(repo_info))
```

## PR/MR Number Parsing

### Commit Message Patterns
- GitHub/Codeberg: `#123`, `PR #123`, `pr #123`
- GitLab: `!123`, `MR !123`, `mr !123`

### Implementation
```vim
" Vimscript
let l:pr_match = matchlist(l:message, '#\(\d\+\)')
if !empty(l:pr_match)
    return l:pr_match[1]
endif
```

```lua
-- Lua
local pr_num = message:match('#(%d+)')
if pr_num then
  return pr_num
end
```

## Versioning

Current version: **1.0.0**

Follow semantic versioning:
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes

Update version in:
- All plugin loader files
- CHANGELOG.md
- README.md (if major/minor)

## Git Workflow

### Commit Message Format
```
<type>: <short description>

<detailed description if needed>

<breaking changes if any>
```

Types: feat, fix, refactor, docs, style, test, chore

### Before Committing
1. Test all three implementations
2. Update documentation
3. Update CHANGELOG.md
4. Ensure code style is consistent
5. Run basic smoke tests

## Important Notes

- **Never break feature parity** between implementations
- **Always use substring matching** for provider detection (not exact match)
- **Guard Vimscript loader** with `has('nvim')` to prevent Neovim loading
- **Use proper indentation** (4-space Vimscript, 2-space Lua)
- **Test with real git repositories** and different providers
- **User preferences:** Avoid auto-detection of Vim variant (user rolled back this approach)

## Resources

- Repository: https://github.com/phongnh/vim-git-open.git
- License: MIT
- Maintainer: Phong Nguyen

## Quick Reference

### File Locations
- Legacy Vimscript: `autoload/git_open.vim`, `plugin/git_open.vim`
- Vim9script: `vim9/autoload/git_open.vim`, `vim9/plugin/git_open.vim`
- Lua: `lua/git_open.lua`, `plugin/git_open.lua`

### Key Functions (All Implementations)
- `parse_remote_url()` - Parse git remote URL
- `detect_provider()` - Detect git hosting provider
- `get_base_url()` - Get base URL for domain
- `get_current_branch()` - Get current git branch
- `get_current_commit()` - Get current commit hash
- `get_file_path()` - Get relative file path from repo root
- `get_line_range()` - Get line range (single or visual selection)
- `format_line_anchor()` - Format line anchor for provider
- `parse_pr_number()` / `parse_mr_number()` - Parse PR/MR from commit
- `open_browser()` - Open URL in browser
- `open_repo()` - Open repository home
- `open_branch()` - Open branch view
- `open_file()` - Open file with line numbers
- `open_commit()` - Open commit view
- `open_pr()` - Open pull request
- `open_mr()` - Open merge request
