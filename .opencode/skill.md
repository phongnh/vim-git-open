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
│   ├── git_open.vim          # Unified dispatcher: adds vim9/ to rtp, sources vim9/plugin; falls through to legacy
│   └── git_open.lua          # Lua entry point (Neovim autoloads this)
├── vim9/
│   ├── autoload/
│   │   └── git_open.vim      # Vim9script core (~1088 lines)
│   └── plugin/
│       └── git_open.vim      # Vim9script commands/autocmds
├── autoload/
│   └── git_open.vim          # Legacy Vimscript core (~1093 lines)
├── lua/
│   └── git_open.lua          # Lua core (~900+ lines)
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
├── stylua.toml
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

**Provider-named commands** (registered dynamically at startup for non-origin remotes):
- GitHub: `OpenGitHubRepo/Branch/File/Commit/PR/PRs/MyPRs[!]`
- GitLab: `OpenGitLabRepo/Branch/File/Commit/MR/MRs/MyMRs[!]`
- Codeberg: `OpenCodebergRepo/Branch/File/Commit/PR/PRs/MyPRs[!]`

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

### Vim9script (`vim9/autoload/git_open.vim`)
```vim
vim9script  " first line (no legacy guard needed — vim9/plugin/git_open.vim guards before sourcing)

export def FunctionName(arg: string, flag: bool = false): string
    var result = ''
    # 4-space indentation
    return result
enddef
```

### Legacy Vimscript (`autoload/git_open.vim`)
```vim
function! git_open#function_name(arg, ...) abort
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

1. **Vim9script** (`vim9/autoload/git_open.vim`)
2. **Legacy Vimscript** (`autoload/git_open.vim`)
3. **Lua** (`lua/git_open.lua`)
4. **Entry points** (only if commands change):
   - `vim9/plugin/git_open.vim`
   - `plugin/git_open.vim`
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
" Vim9script — silent suppresses escape sequences from stderr
silent var output = system('git -C ' .. shellescape(git_root) .. ' ' .. args)
```
```lua
-- Lua — use vim.system (not vim.fn.system); pass args as list, not shell string
local unpack = table.unpack or unpack

local function system(cmd, opts)
  local result = vim.system(cmd, vim.list_extend(opts or {}, { text = true })):wait()
  return result.code == 0 and vim.trim(result.stdout) or ""
end

-- Usage (no shellescape needed):
local output = system({ "git", "-C", git_root, "log", "--oneline" })
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
" Codeberg: '-closed' → '?state=closed'  (used by OpenRequests only)
"
" OpenMyRequests Codeberg assembles its own query — does NOT use ParseRequestState output:
"   no flag / -open → /pulls
"   -all            → /pulls?type=created_by
"   -closed/-merged → /pulls?type=created_by&state=closed
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

### Startup Deferral for `system()` Calls

Multi-remote scanning calls `system()` at startup. Calling it synchronously during `VimEnter`
briefly suspends the TUI, causing the terminal's DECRQM response (`^[[?12;1$y`) to print as
raw text. Always defer:

**Vim / Legacy Vimscript** — wrap in `timer_start(0, ...)`:
```vim
" Vim9script
autocmd VimEnter * timer_start(0, (_) => RegisterMultiRemoteCommands())

" Legacy
autocmd VimEnter * call timer_start(0, {-> s:register_multi_remote_commands()})
```

**Neovim / Lua** — use `UIEnter` (fires after the built-in TUI is fully attached):
```lua
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    register_multi_remote_commands()
  end,
})
```

`UIEnter` does NOT fire in `--headless` mode. `timer_start(0, ...)` defers by exactly one
event-loop tick — equivalent to `vim.schedule()` but available in Vim.

### stylua Formatting

All Lua files must be formatted with `stylua` before committing. Project config is in
`stylua.toml` at the repo root:

```toml
column_width = 120
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
line_endings = "Unix"
```

Run:
```bash
stylua plugin/git_open.lua lua/git_open.lua
```

A local `.git/hooks/pre-commit` hook (not committed) does this automatically for staged `.lua`
files. `column_width = 120` avoids wrapping long Neovim API calls.
### Multi-Remote Provider Commands

At startup (deferred past TUI handshake), the plugin registers provider-named commands for each
non-origin remote whose domain differs from origin's domain:

```vim
" Vim9script (vim9/plugin/git_open.vim)
def RegisterMultiRemoteCommands()
    var remotes = GitOpen.GetAllRemotes()
    var origin_info = GitOpen.GetRepoInfo()
    var origin_domain = empty(origin_info) ? '' : origin_info.domain
    for r in remotes
        var info = GitOpen.GetRepoInfoForRemote(r)
        if empty(info) || (!empty(origin_domain) && info.domain ==# origin_domain)
            continue
        endif
        var rs = string(r)   # e.g. "'upstream'"
        if info.provider ==# 'GitHub'
            execute 'command! -bang -nargs=0 OpenGitHubRepo'
                        \ 'call git_open#OpenRepoForRemote(' .. rs .. ', <bang>0)'
            # ... etc for Branch, File, Commit, PR, PRs, MyPRs
        endif
    endfor
enddef

autocmd VimEnter * ++once call timer_start(0, (_) => RegisterMultiRemoteCommands())
```

Key points:
- Remote name is embedded as a **quoted literal** in each `execute`d command string
- `<bang>0`, `<q-args>`, `<line1>`, `<line2>`, `<count>` expand at **invocation time**
- `GetRepoInfo()` and `GetRepoInfoForRemote(remote)` must be exported from the autoload module
- Skip remotes sharing origin's domain to avoid duplicate provider commands
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
4. **`vim9script` is the first line** in `vim9/autoload/git_open.vim` — no legacy guard needed there
5. **`export type`** not supported in Vim 9.2.250 — use concrete types directly
6. **GitLab uses `opened`** (not `open`) in state params
7. **GitHub PRs use `?q=is%3Apr+...`** — not `?state=` (that hits the issues endpoint)
8. **`-search` flags** belong only in `CompleteMyRequestState`, not `CompleteRequestState`
9. **Copy files to both installed locations** before committing
10. **No emojis** unless explicitly requested
11. **`exists('*FuncName')` in Vim9 `def` is compile-time** — always `false` for late-loaded plugins. Use `try/catch call('FuncName', [])` instead.
12. **`GetGitRoot` must use 3-step detection** — FugitiveGitDir (try/catch) → finddir(bufname) → finddir(cwd). See the pattern in Common Patterns section above.
13. **`OpenBranch`/`OpenCommit` must set fallback explicitly** — do not rely on `BuildUrl`'s internal fallback, which is bypassed when any extra arg (even empty string) is passed.
14. **`cpoptions` guard not needed in `autoload/` files** — Vim resets `cpoptions` before sourcing autoload files. Only needed in `plugin/`, `ftplugin/`, `syntax/` etc.
15. **Never run `gg=G` on files with `\` continuation lines** — Vim's indenter re-indents them destructively.
16. **Defer `system()` calls at startup** — use `timer_start(0, ...)` (Vim) or `UIEnter` autocmd (Neovim) to avoid TUI escape sequence leakage. See "Startup Deferral" pattern above.
17. **`UIEnter` does not fire in `--headless` mode** — only fires when a UI is attached.
18. **Run `stylua` on all modified Lua files before committing** — see `stylua.toml` and the "stylua Formatting" pattern above.
19. **`vim.system` not `vim.fn.system` in Lua** — use `vim.system({...}, {text=true}):wait()` with args as a list for proper subprocess handling and exit-code checking.
20. **Vim9script uses relative import** — `import autoload '../autoload/git_open.vim' as GitOpen` resolves from `vim9/plugin/` to `vim9/autoload/`; no extra runtimepath manipulation needed inside the Vim9 files themselves.
21. **`silent` before `system()` in Vim9script/legacy** — suppresses stderr escape sequences from appearing in the command-line area.
22. **Multi-remote commands embed remote name as string literal** — use `string(r)` to produce `'remote_name'` and interpolate into `execute`d command strings; `<bang>0` etc. expand at invocation.
