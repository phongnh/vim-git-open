# Vim-Git-Open Development Skill

## Description
Expert skill for developing and maintaining the vim-git-open plugin — a Vim/Neovim plugin that opens git resources (files, branches, commits, PRs/MRs) in a web browser. Three separate implementations must always be kept in sync: Vim9script (default), Legacy Vimscript (fallback), and Lua (Neovim).

## When to Use This Skill
- Adding new features to vim-git-open
- Fixing bugs across all three implementations
- Refactoring code while maintaining feature parity
- Updating documentation
- Adding support for new git hosting providers

## Project Structure

```
vim-git-open/
├── plugin/
│   ├── git_open.vim          # Dispatcher: Vim9script or legacy (guards has('nvim'))
│   ├── git_open_legacy.vim   # Legacy Vimscript entry point
│   └── git_open.lua          # Lua entry point (Neovim autoloads this)
├── autoload/
│   ├── git_open.vim          # Vim9script core (~500 lines)
│   └── git_open/
│       └── legacy.vim        # Legacy Vimscript core (~600 lines)
├── lua/
│   └── git_open.lua          # Lua core (~580 lines)
├── doc/
│   └── git_open.txt          # Vim help documentation
├── .opencode/
│   ├── agent.md              # Agent instructions and discoveries
│   ├── conversation-log.md   # Full development history
│   ├── skill.md              # This file
│   └── conversation-transcript.md
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── example_config.vim
└── LICENSE
```

## Commands

| Command | Notes |
|---------|-------|
| `OpenGitRepo[!]` | Repository home page |
| `OpenGitBranch[!] [branch]` | Branch view; tab-completes branch names. Visual mode: selected text as branch name |
| `[range]OpenGitFile[!] [ref]` | File + line numbers; tab-completes branch names |
| `OpenGitCommit[!] [commit]` | Commit view. Visual mode: selected text as commit hash |
| `OpenGitRequest[!] [number]` | PR/MR (provider-agnostic; auto-parses from commit) |
| `OpenGitFileLastChange[!]` | PR/MR or commit that last changed current file |
| `OpenGitMyRequests[!] [state]` | My PRs/MRs; tab-completes state flags |
| `OpenGitRequests[!] [state]` | Repo PR/MR listing; tab-completes state flags |
| `OpenGitk [args]` | Launch gitk; tab-completes branches and tracked files |
| `OpenGitkFile[!]` | Launch gitk for current file. `!` shows full rename history via `git log --follow` |
| `Gitk [args]` | Alias for `OpenGitk` |
| `GitkFile[!]` | Alias for `OpenGitkFile` |
| `OpenGitRemote[!] [remote]` | Print/set/reset per-buffer remote. No args: print. With remote: validate+set. With `!`: reset |

**State flags for `OpenGitMyRequests`:** `-open`, `-closed`, `-merged`, `-all`, `-search`, `-search=open`, `-search=closed`, `-search=merged`, `-search=all`
**State flags for `OpenGitRequests`:** `-open`, `-closed`, `-merged`, `-all`

## Supported Providers

| Provider | Detection | Notes |
|----------|-----------|-------|
| GitHub | `domain =~# 'github\.com'` | Includes enterprise (substring match) |
| GitLab | `domain =~# 'gitlab\.com'` | Includes self-managed |
| Codeberg | `domain =~# 'codeberg\.org'` | Gitea-based |

Always use substring matching, never exact matching.

## Code Style

### Vim9script (`autoload/git_open.vim`)
```vim
vim9script  " after the legacy guard

export def FunctionName(arg: string, flag: bool = false): string
    var result = ''
    # 4-space indentation
    return result
enddef
```

### Legacy Vimscript (`autoload/git_open/legacy.vim`)
```vim
function! git_open#legacy#function_name(arg, ...) abort
    let l:result = ''
    " 4-space indentation
    " Explicit scoping: s: l: g: a:
    " Check exists('*matchfuzzy') before using it
    return l:result
endfunction
```

### Lua (`lua/git_open.lua`)
```lua
local M = {}

local function private_function(arg)
  -- 2-space indentation
  local result = ''
  return result
end

function M.public_function(arg)
  -- public API
end

return M
```

## Feature Parity Workflow

When adding any feature or fixing any bug:

1. **Vim9script** (`autoload/git_open.vim`)
2. **Legacy Vimscript** (`autoload/git_open/legacy.vim`)
3. **Lua** (`lua/git_open.lua`)
4. **Entry points** (only if commands change):
   - `plugin/git_open.vim`
   - `plugin/git_open_legacy.vim`
   - `plugin/git_open.lua`
5. **Copy to installed locations:**
   ```bash
   cp <files> ~/.cache/vim/plugged/vim-git-open/<dest>
   cp <files> ~/.local/share/nvim/site/pack/core/opt/vim-git-open/<dest>
   ```
6. **Commit and push**

## Common Patterns

### Git Command Execution
```vim
" Vim9script
var output = trim(system('git -C ' .. shellescape(git_root) .. ' ' .. args))
```
```lua
-- Lua
local output = vim.trim(vim.fn.system('git -C ' .. vim.fn.shellescape(git_root) .. ' ' .. args))
```

### Error Messages (no stack trace)
```vim
" Vim9script / Legacy
echohl ErrorMsg
echom 'git-open: message'
echohl None
```
```lua
vim.api.nvim_echo({{'git-open: message', 'ErrorMsg'}}, true, {})
```

### Opening Browser
```vim
call system(browser_cmd .. ' ' .. shellescape(url) .. ' > /dev/null 2>&1')
redraw!
echo 'Opened: ' .. url
```

### Bang Support (`copy vs open`)
```vim
" Entry point
command! -bang -nargs=? OpenGitFoo GitOpen.OpenFoo(<q-args>, <bang>0)
" Implementation
export def OpenFoo(arg: string = '', copy: bool = false)
    ...
    if copy
        " copy to clipboard
    else
        " open browser
    endif
enddef
```

### State Flag Parsing
```vim
" ParseRequestState(state_arg, provider) returns URL query string
" GitHub:   '-closed' → '?q=is%3Apr+is%3Aclosed'
" GitLab:   '-closed' → '?state=closed'
" Codeberg: '-closed' → '?state=closed'
```

### GetGitRoot — 3-Step Detection
All three implementations use this logic in order:

1. **`call('FugitiveGitDir', [])` via `try/catch`** — handles fugitive virtual buffers (`fugitive://`, `fugitiveblame`). Returns `fnamemodify(gitdir, ':h')`.
2. **`finddir('.git', expand('%:p:h') .. ';')`** — normal file buffers. Returns `fnamemodify(git_dir, ':p:h')`.
3. **`finddir('.git', getcwd() .. ';')`** — fallback for terminal/quickfix/empty buffers.

```vim
" Vim9script — CORRECT pattern (compile-time exists() always false in def)
def GetGitRoot(): string
    try
        var gitdir = '' .. call('FugitiveGitDir', [])
        if !empty(gitdir)
            return fnamemodify(gitdir, ':h')
        endif
    catch
    endtry
    var git_dir = finddir('.git', expand('%:p:h') .. ';')
    if empty(git_dir)
        git_dir = finddir('.git', getcwd() .. ';')
    endif
    if empty(git_dir)
        return ''
    endif
    return fnamemodify(git_dir, ':p:h')
enddef
```

**Why `try/catch` not `exists('*FugitiveGitDir')`:**
`exists('*FuncName')` inside a Vim9 `def` is resolved at compile time — always `false` for late-loaded plugins.

**Why `FugitiveGitDir()` not `FugitiveWorkTree()`:**
`FugitiveWorkTree()` triggers E15 in Vim 9.2. `FugitiveGitDir()` reads `b:git_dir` directly.

### Branch/Commit Fallback in OpenBranch/OpenCommitAfter the visual selection check, explicitly call the fallback if still empty:
```vim
" Vim9script
export def OpenBranch(branch: string = '', copy: bool = false)
    var b = branch
    if empty(b)
        b = GetVisualSelection()
    endif
    if empty(b)
        b = GetCurrentBranch()   # explicit fallback — do NOT rely on BuildUrl
    endif
    ...
enddef
```
This is necessary because `BuildUrl` checks `len(extra) > 0` — if `OpenBranch` passes even an empty string, the fallback inside `BuildUrl` is bypassed.

### Branch Completion
Two `for-each-ref` calls:
- Local: `--format='%(refname:short)' refs/heads/` (lstrip=2)
- Remote: `--format='%(refname:short)' refs/remotes/origin/` (lstrip=3)
- Sort by `-committerdate`, filter `HEAD`, deduplicate local-first
- Use `matchfuzzy()` in Vim9/Lua; check `exists('*matchfuzzy')` in legacy

### Per-Buffer Remote Resolution
Resolution order (first match wins):
1. `b:vim_git_open_remote` — already cached for this buffer
2. `g:vim_git_open_remote` — global preference (validated against actual remotes)
3. `origin` — if present in `git remote` output
4. First remote returned by `git remote`

`b:vim_git_open_remote` is set on first resolution and cached until `:OpenGitRemote!` resets it.
`g:vim_git_open_remote` is **never written** by the plugin — it is user-set only.
`b:vim_git_open_remote_warned` suppresses the invalid-remote warning to once per buffer.

```vim
" Vim9script — GetCurrentRemote pattern
def GetCurrentRemote(git_root: string): string
    if exists('b:vim_git_open_remote') && !empty(b:vim_git_open_remote)
        return b:vim_git_open_remote
    endif
    var all_remotes = GetAllRemoteNames(git_root)
    var preferred = get(g:, 'vim_git_open_remote', '')
    if !empty(preferred)
        if index(all_remotes, preferred) >= 0
            b:vim_git_open_remote = preferred
            return preferred
        elseif !get(b:, 'vim_git_open_remote_warned', false)
            b:vim_git_open_remote_warned = true
            echohl WarningMsg
            echom 'git-open: remote "' .. preferred .. '" not found, falling back'
            echohl None
        endif
    endif
    var remote = index(all_remotes, 'origin') >= 0 ? 'origin' : (empty(all_remotes) ? '' : all_remotes[0])
    b:vim_git_open_remote = remote
    return remote
enddef
```

## Documentation Requirements

When making changes, update:
1. `README.md` — user-facing docs (Usage Examples + Commands table)
2. `doc/git_open.txt` — Vim help file
3. `CHANGELOG.md` — version history
4. `example_config.vim` — if config variables added

## Important Reminders

1. **Feature parity is non-negotiable** — all three must behave identically
2. **Substring matching** for provider detection — not exact match
3. **`redraw!`** (not `redraw`) after `system()` calls
4. **`vim9script` guard order**: legacy guard first, then `vim9script` keyword
5. **`export type`** not supported in Vim 9.2.250 — use concrete types directly
6. **GitLab uses `opened`** (not `open`) in state params
7. **GitHub PRs use `?q=is%3Apr+...`** — not `?state=` (that hits the issues endpoint)
8. **`-search` flags** belong only in `CompleteMyRequestState`, not `CompleteRequestState`
9. **Copy files to both installed locations** before committing
10. **No emojis** unless explicitly requested
11. **`exists('*FuncName')` in Vim9 `def` is compile-time** — always `false` for late-loaded plugins. Use `try/catch call('FuncName', [])` instead.
12. **`GetGitRoot` must use 3-step detection** — FugitiveGitDir (try/catch) → finddir(bufname) → finddir(cwd). See the pattern in Common Patterns section above.
13. **`OpenBranch`/`OpenCommit` must set fallback explicitly** — do not rely on `BuildUrl`'s internal fallback, which is bypassed when any extra arg (even empty string) is passed.
