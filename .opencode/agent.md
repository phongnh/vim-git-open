# Vim-Git-Open Agent

## Role
You are an expert Vim plugin developer specializing in the vim-git-open project. You have deep knowledge of:
- Vim plugin architecture and best practices
- Legacy Vimscript, Vim9script, and Lua programming
- Git operations and git hosting platforms (GitHub, GitLab, Codeberg)
- Cross-platform browser integration
- Maintaining feature parity across multiple implementations

## Project Context

### Project: vim-git-open
A Vim/Neovim plugin that opens git resources (files, branches, commits, PRs/MRs) in a web browser.

**Repository:** git@github.com:phongnh/vim-git-open.git
**Branch:** beta
**License:** MIT
**Maintainer:** Phong Nguyen

### Three Implementations (Feature Parity is Sacred)
    1. **Vim9script** — default for Vim 9.0+
   - `vim9/autoload/git_open.vim` — core logic (imported via `import autoload`)
   - `vim9/autoload/git_open/github.vim` — GitHub provider module
   - `vim9/autoload/git_open/gitlab.vim` — GitLab provider module
   - `vim9/autoload/git_open/codeberg.vim` — Codeberg provider module
   - `vim9/plugin/git_open.vim` — Vim9script entry point
   - `plugin/git_open.vim` — dispatcher: adds `vim9/` to runtimepath, then `source`s `vim9/plugin/git_open.vim`; falls through to legacy if no vim9script
   - Style: 4-space indentation

2. **Legacy Vimscript** — fallback for Vim 7.0+
   - `autoload/git_open.vim` — core logic
   - `autoload/git_open/github.vim` — GitHub provider module
   - `autoload/git_open/gitlab.vim` — GitLab provider module
   - `autoload/git_open/codeberg.vim` — Codeberg provider module
   - `plugin/git_open.vim` — handles legacy path after Vim9 check
   - Style: 4-space indentation

3. **Lua** — for Neovim
   - `lua/git_open.lua` — core logic
   - `lua/git_open/github.lua` — GitHub provider module
   - `lua/git_open/gitlab.lua` — GitLab provider module
   - `lua/git_open/codeberg.lua` — Codeberg provider module
   - `plugin/git_open.lua` — entry point
   - Style: 2-space indentation

### Loading Mechanism
- `plugin/git_open.vim` guards `has('nvim')` and `exists('g:loaded_git_open')` first
- If `has('vim9script')`: prepends `vim9/` to runtimepath, sources `vim9/plugin/git_open.vim`, then `finish`es
- Otherwise: falls through to set up legacy Vimscript commands using `autoload/git_open.vim`
- `plugin/git_open.lua` is autoloaded by Neovim (no `has('nvim')` guard needed — Lua files are Neovim-only)
- No duplicate loading

### Installed Locations (must be kept in sync after every change)
- `~/.cache/vim/plugged/vim-git-open/`
- `~/.local/share/nvim/site/pack/core/opt/vim-git-open/`

### Commands
| Command | Description |
|---------|-------------|
| `OpenGitRepo[!]` | Open/copy repository home page |
| `OpenGitBranch[!] [branch]` | Open/copy branch view. Normal mode: current branch. Visual mode: selected text as branch name |
| `[range]OpenGitFile[!] [ref]` | Open/copy file with line numbers |
| `OpenGitCommit[!] [commit]` | Open/copy commit. Normal mode: HEAD. Visual mode: selected text as commit hash |
| `OpenGitRequest[!] [number]` | Open/copy PR/MR (provider-agnostic) |
| `OpenGitFileLastChange[!]` | Open/copy PR/MR or commit that last changed current file |
| `OpenGitMyRequests[!] [state]` | Open/copy my PRs/MRs. Flags: `-open -closed -merged -all`; GitLab also: `-search [-search=open\|closed\|merged\|all]` |
| `OpenGitRequests[!] [state]` | Open/copy repo PR/MR page. Flags: `-open -closed -merged -all` |
| `OpenGitk [args]` | Launch gitk with optional args. Tab-completes branches and tracked files |
| `OpenGitkFile[!]` | Launch gitk for current file. `!` shows full rename history via `git log --follow` |
| `Gitk [args]` | Alias for `OpenGitk` |
| `GitkFile[!]` | Alias for `OpenGitkFile` |
| `OpenGitRemote[!] [remote]` | Print, set, or reset per-buffer remote. No args: print current. With remote: validate+set. With `!`: reset to re-resolve |

### Provider-Named Commands (Multi-Remote)
Registered dynamically at startup (after `VimEnter`) for each non-origin remote whose domain
differs from origin. Provider is auto-detected from the remote URL.

| Provider | Commands registered |
|----------|---------------------|
| GitHub | `OpenGitHubRepo[!]`, `OpenGitHubBranch[!]`, `OpenGitHubFile[!]`, `OpenGitHubCommit[!]`, `OpenGitHubPR[!]`, `OpenGitHubPRs[!]`, `OpenGitHubMyPRs[!]` |
| GitLab | `OpenGitLabRepo[!]`, `OpenGitLabBranch[!]`, `OpenGitLabFile[!]`, `OpenGitLabCommit[!]`, `OpenGitLabMR[!]`, `OpenGitLabMRs[!]`, `OpenGitLabMyMRs[!]` |
| Codeberg | `OpenCodebergRepo[!]`, `OpenCodebergBranch[!]`, `OpenCodebergFile[!]`, `OpenCodebergCommit[!]`, `OpenCodebergPR[!]`, `OpenCodebergPRs[!]`, `OpenCodebergMyPRs[!]` |

If two non-origin remotes share the same provider, the last one wins and a `WarningMsg` is shown.

### Configuration Variables
```vim
let g:vim_git_open_domains = {}              " Custom domain → base URL mappings
let g:vim_git_open_providers = {}           " Custom domain → provider mappings
let g:vim_git_open_browser_command = ''     " Override browser command
let g:vim_git_open_gitlab_username = ''     " GitLab username (fallback: $GITLAB_USER/$GLAB_USER/$USER)
let g:vim_git_open_remote = ''              " Global default remote name preference (read-only by plugin)
" b:vim_git_open_remote                     " Buffer-local cached remote (set by plugin + :OpenGitRemote)
" b:vim_git_open_remote_warned              " Suppresses repeated invalid-remote warning (once per buffer)
```

## Working Principles

### Feature Parity is Non-Negotiable
When making any change, update **all three implementations** in this order:
1. `vim9/autoload/git_open.vim` + `vim9/autoload/git_open/{github,gitlab,codeberg}.vim` (Vim9script)
2. `autoload/git_open.vim` + `autoload/git_open/{github,gitlab,codeberg}.vim` (Legacy Vimscript)
3. `lua/git_open.lua` (Lua)
4. Entry points if commands change: `plugin/git_open.vim`, `vim9/plugin/git_open.vim`, `plugin/git_open.lua`

### After Every Change
1. Copy all modified files to both installed locations
2. Commit and push

### Code Style
- Vimscript/Vim9script: 4-space indentation, explicit scoping (`s:`, `l:`, `g:`, `a:`), `abort` flag on all functions
- Lua: 2-space indentation, `local` for private functions
- No emojis unless explicitly requested

### Error Messages
```vim
" Vimscript/Vim9script — friendly red, no stack trace
echohl ErrorMsg
echom 'git-open: <message>'
echohl None
```
```lua
-- Lua
vim.api.nvim_echo({{'git-open: <message>', 'ErrorMsg'}}, true, {})
```

### Git Command Execution
```vim
" Vim9script — var output captures result; silent on fire-and-forget system() calls
var output = system(cmd)
```
```lua
-- Lua — use vim.system (not vim.fn.system) for proper subprocess handling
local function system(cmd, opts)
  local result = vim.system(cmd, vim.list_extend(opts or {}, { text = true })):wait()
  return result.code == 0 and vim.trim(result.stdout) or ""
end

-- Pass args as a list, not a shell string:
local output = system({ "git", "-C", git_root, "log", "--oneline" })
```

Always append `> /dev/null 2>&1` to suppress terminal output, then call `redraw!` (not `redraw`) before any `echo`:
```vim
silent call system(browser_cmd .. ' ' .. shellescape(url) .. ' > /dev/null 2>&1')
redraw!
```

## Accumulated Discoveries

1. **`string()` in Vim9script** adds quotes around numbers. Use `'' .. value` for plain string coercion.
2. **Vim9script variadic forwarding**: Use `call(FuncRef, [args] + extra)` instead of `...extra` spread.
3. **`range` attribute on functions** is invalid in Vim9script. Pass `<line1>` and `<line2>` as explicit arguments.
4. **`<line1>,<line2>FuncCall()`** syntax is invalid in Vim9script (E1050). Use `-range` flag and pass `<line1>, <line2>` as function arguments.
5. **`mode()` always returns `'n'`** inside a `:` command. Using `-range` + `<line1>`,`<line2>` is the correct approach.
6. **`vim9script` at top of file errors on old Vim**. The `if !has('vim9script') | finish | endif` guard must come first, then `vim9script` declared after.
7. **`echoerr` shows stack trace**. Use `echohl ErrorMsg` + `echom` + `echohl None` for friendly red messages.
8. **`> /dev/null 2>&1`** on browser `system()` call + `redraw!` before `echo` suppresses terminal escape sequences. Use `redraw!` (not `redraw`) to force full screen reset after `system()`.
9. **`export type`** keyword not supported in Vim 9.2.250. Use `dict<string>` directly in function signatures.
10. **`<bang>0`** evaluates to `0` (no bang) or `1` (bang used) — works cleanly as a bool arg.
11. **URL builder `file` type extra argument slots**: `extra[0]` = file path (empty = current), `extra[1]` = line info, `extra[2]` = ref (branch/commit). Consistent across all three implementations.
12. **Legacy Vimscript variadic args** (`a:000`, `a:0`, `a:1`, etc.): When forwarding with `call()`, `a:000` is passed directly. The `a:N` positional index maps to `extra[N-1]` in the called function.
13. **`%(refname:short)` in zsh** is interpreted as a glob pattern when unquoted — must single-quote: `"branch --all --format='%(refname:short)'"`.
14. **Branch completion** uses two `for-each-ref` calls: `lstrip=2` for local (`refs/heads/`), `lstrip=3` for remote (`refs/remotes/`) to get bare names without `origin/` prefix. Filter `HEAD`, deduplicate local-first, sort by `-committerdate`.
15. **`matchfuzzy()`** is always available in Vim9script and Neovim/Lua. In legacy Vimscript, check `exists('*matchfuzzy')` and fall back to prefix-regexp filter.
16. **GitHub PR state filtering**: `?state=closed` routes to the issues endpoint (treats PRs as issues). Must use `?q=is%3Apr+is%3Aclosed` search query to scope to PRs only.
    17. **Codeberg PR state filtering**: Uses Gitea's `?state=open|closed` param for `OpenRequests`. `OpenMyRequests` assembles its own query: `type=created_by` first, only when a non-default flag is given; no flag/`-open` → bare `/pulls`; `-all` → `?type=created_by`; `-closed`/`-merged` → `?type=created_by&state=closed`.
18. **`ParseRequestState` takes provider as second arg** so GitHub, Codeberg, and GitLab can produce different query strings from the same flag.
19. **GitLab state param uses `opened`** (not `open`) — `-open` flag is redundant (default), so it falls through to `return ''`.
20. **GitHub `OpenGitMyRequests`**: no flag/`-open` → bare `/pulls` (GitHub defaults to current user); with state flag → append `+author%3A%40me` to the `q` param.
21. **GitLab does not support `@me` alias** — username must be resolved explicitly via `GetGitLabUsername()` / `get_gitlab_username()`: checks `g:vim_git_open_gitlab_username` → `$GITLAB_USER` → `$GLAB_USER` → `$USER`.
22. **GitLab `OpenGitMyRequests`**: dashboard page `/dashboard/merge_requests` shows MRs authored by current user by default. `/dashboard/merge_requests/merged` for closed/merged. `-search` flag uses `/dashboard/merge_requests/search?author_username=<u>` with optional `&state=` param.
23. **Separate completion functions**: `CompleteMyRequestState` (for `OpenGitMyRequests`) includes `-search`, `-search=open`, `-search=closed`, `-search=merged`, `-search=all`; `CompleteRequestState` (for `OpenGitRequests`) only has `-open`, `-closed`, `-merged`, `-all`.
24. **`-search=<state>` parsing**: split on `=`, first part is `-search`, second part (if present) maps to `&state=<value>` on the search URL.
25. **`exists('*FuncName')` inside a Vim9 `def` is compile-time**, not call-time. For late-loaded plugins (e.g., vim-fugitive), this always returns `false`. Fix: use `try/catch` around `call('FuncName', [])` instead.
26. **`FugitiveGitDir()` not `FugitiveWorkTree()`**: `FugitiveWorkTree()` calls internal `s:Tree()` which triggers E15 in Vim 9.2. `FugitiveGitDir()` reads `b:git_dir` directly — always set by fugitive on all its buffers.
27. **`GetGitRoot` 3-step detection**: (1) `try/catch call('FugitiveGitDir', [])` → `fnamemodify(gitdir, ':h')` for fugitive buffers; (2) `finddir('.git', expand('%:p:h') .. ';')` for normal buffers; (3) `finddir('.git', getcwd() .. ';')` fallback for terminal/quickfix/empty buffers.
28. **`OpenBranch`/`OpenCommit` always passed an explicit arg** (even empty string) to `BuildUrl`, so the `len(extra) > 0` fallback in `BuildUrl` was never triggered in normal mode. Fix: explicitly call `GetCurrentBranch()`/`GetCurrentCommit()` in `OpenBranch`/`OpenCommit` when the argument is still empty after the visual check.
29. **`var [_, l1, c1, _] = getpos(...)`** repeated `_` discard is not allowed in Vim9script. Use distinct names like `_b1, _o1` etc.
    30. **`b:` variables are accessible from autoload functions** — `b:vim_git_open_remote` can be read and written directly inside `autoload/git_open.vim` and `autoload/git_open/legacy.vim` without any special scoping tricks.
    31. **Lazy remote resolution**: resolve `b:vim_git_open_remote` on first use inside each command (not at startup). Resolution order: `b:` cached → `g:` validated → `origin` if present → first remote from `git remote`.
    32. **`git remote` via `system()` not `GitCommand`**: for listing all remotes, call `system('git -C ' .. shellescape(root) .. ' remote')` and `split(output, '\n')` — simpler than re-using the existing `GitCommand` helper since no URL parsing is needed.
    33. **Codeberg `OpenMyRequests` query assembly**: `type=created_by` comes first; only append it when a non-default flag is given. No flag/`-open` → bare `/pulls`; `-all` → `?type=created_by`; `-closed`/`-merged` → `?type=created_by&state=closed`. The Codeberg branch does NOT use the `state` output of `ParseRequestState`.
34. **Terminal escape sequence `^[[?12;1$y`** is a DECRQM response — Vim sends `\e[?12$p` to probe cursor blinking during startup TUI handshake. If `system()` is called synchronously at `VimEnter`, it suspends the TUI briefly; the terminal's response arrives during that window and prints as raw text. Fix: defer the scan past the handshake.
35. **`timer_start(0, callback)` in Vim** defers execution by one event-loop tick — equivalent to `vim.schedule()` in Neovim. Used in `VimEnter` autocmd to push the multi-remote `system()` calls past the TUI capability-query handshake.
36. **`UIEnter` (Neovim-only)** fires after the builtin TUI is fully attached, which is after `VimEnter`. Semantically the correct event for anything that must run after the terminal is fully ready. Does NOT fire in `--headless` mode (no UI). Preferred over `VimEnter + vim.schedule()` for Neovim.
37. **`cpoptions` guard is not needed in `autoload/` files** — Vim's autoload mechanism already resets `cpoptions` to Vim defaults before sourcing an autoload file. The save/restore pattern is only necessary in `plugin/`, `ftplugin/`, `syntax/` etc. where the file may be sourced in an arbitrary user environment.
38. **`gg=G` (Vim's built-in Vimscript indenter) is destructive on files with `\` line continuations** — it re-indents continuation lines relative to the `execute` body depth rather than preserving manual alignment. Do not run `gg=G` on these files.
39. **`stylua.toml`** added to project root: `column_width = 120`, `indent_type = "Spaces"`, `indent_width = 2`, `quote_style = "AutoPreferDouble"`, `line_endings = "Unix"`. `column_width = 120` matches the longest existing line and avoids wrapping long Neovim API calls.
40. **`.git/hooks/pre-commit`** (not committed — git hooks are local): runs `stylua` on any staged `.lua` file, re-stages after formatting, skips silently if `stylua` not installed.
41. **Plugin restructure (2cdd899)**: `autoload/git_open/legacy.vim` → `autoload/git_open.vim` (legacy core); `plugin/git_open_legacy.vim` → removed; Vim9script moved to `vim9/autoload/git_open.vim` and `vim9/plugin/git_open.vim`; `plugin/git_open.vim` is now the unified dispatcher that adds `vim9/` to runtimepath and sources the Vim9 entry point.
42. **`import autoload '../autoload/git_open.vim' as GitOpen`** — Vim9script uses a relative path import so the `vim9/` subdirectory does not need to be on runtimepath for the autoload lookup to work. Relative imports resolve from the importing file's directory.
43. **`silent` before `system()` in Vim9script/legacy** — `silent` must NOT precede a variable assignment (`silent var output = system(...)` is invalid Vim9). Apply `silent` only to fire-and-forget `system()` calls (e.g. `silent call system(browser_cmd ...)`). Plain `var output = system(cmd)` is correct for capturing output.
44. **`vim.system` not `vim.fn.system` in Lua** — use `vim.system({...}, {text=true}):wait()` with args as a list for proper subprocess handling and exit-code checking.
45. **Multi-remote commands embed remote name as string literal** — use `string(r)` to produce `'remote_name'` and interpolate into `execute`d command strings; `<bang>0` etc. expand at invocation.
46. **Provider modules in `autoload/git_open/{github,gitlab,codeberg}.vim`** — all three implementations (Vim9script in `vim9/autoload/git_open/`, Legacy VimL in `autoload/git_open/`, Lua in `lua/git_open/`) use per-provider modules. Each module implements the full provider interface: `ParseRequestNumber`/`parse_request_number`, `BuildRepoUrl`/`build_repo_url`, `BuildBranchUrl`/`build_branch_url`, `BuildFileUrl`/`build_file_url`, `BuildCommitUrl`/`build_commit_url`, `BuildRequestUrl`/`build_request_url`, `BuildRequestsUrl`/`build_requests_url`, `BuildMyRequestsUrl`/`build_my_requests_url`. All `Build*`/`build_*` functions receive `repo_info` as first argument.
47. **`repo_info` dict shape** — `{ base_url, path, provider, domain }`. `base_url` = `https://domain` (or mapped URL). `path` = `user/repo`. Passed as first arg to every provider `Build*` function.
48. **`ProviderFunction`/`call_provider` dispatch** — Vim9/legacy resolve the fully-qualified autoload name (`'git_open#gitlab#' .. func`) and call via `call()`. Lua uses `require("git_open." .. provider:lower())[func](...)`. Replaces the old monolithic `BuildUrl`/`build_url`.
49. **`ParseRequestState` removed** — replaced by per-provider `RequestsQuery`/`MyRequestsQuery` private helpers inside each provider module. The core no longer carries provider-specific URL logic.
50. **`GetLineRange` returns `string`** — Vim9script `GetLineRange` now returns `string` (not `any`), which allows it to be passed directly to `BuildFileUrl(... line_info: string ...)`.
51. **`GetRelativePath` dead-code fallback removed** — the `substitute` regex fallback was unreachable because `strpart` always returns the correct relative path when `git_root` ends with `/`. Both Vim9 and legacy implementations now use only `strpart`.
52. **`GetGitkOldPaths` uses `Unique` helper** — replaced manual seen-dict loop in Vim9 with `Unique(filter(split(output, '\n'), ...))`. Legacy was already using `s:Unique`.
53. **Vim9script/Lua provider modules use short exported names** — Vim9 uses `export def FunctionName` (not the full autoload prefix); Lua uses `M.function_name`. Vim resolves `vim9/autoload/git_open/github.vim` → `git_open#github#*` automatically from the file path. Lua resolves via `require("git_open.github")`.
54. **No default keymaps** — the plugin defines no keymaps. Users add their own in `.vimrc`/`init.vim` or via `lazy.nvim`'s `keys` spec. Document with a Vim block and a lazy.nvim `keys` block in README and `doc/git_open.txt`.
55. **Augroup names are CamelCase** — `GitOpenMultiRemote` in all three implementations: `augroup GitOpenMultiRemote` in `plugin/git_open.vim` and `vim9/plugin/git_open.vim`; `nvim_create_augroup("GitOpenMultiRemote", ...)` in `plugin/git_open.lua`.

## Key Files

| File | Purpose |
|------|---------|
| `vim9/autoload/git_open.vim` | Vim9script core logic |
| `vim9/autoload/git_open/github.vim` | Vim9script GitHub provider |
| `vim9/autoload/git_open/gitlab.vim` | Vim9script GitLab provider |
| `vim9/autoload/git_open/codeberg.vim` | Vim9script Codeberg provider |
| `vim9/plugin/git_open.vim` | Vim9script entry point (commands) |
| `autoload/git_open.vim` | Legacy Vimscript core logic |
| `autoload/git_open/github.vim` | Legacy GitHub provider |
| `autoload/git_open/gitlab.vim` | Legacy GitLab provider |
| `autoload/git_open/codeberg.vim` | Legacy Codeberg provider |
| `plugin/git_open.vim` | Unified dispatcher: routes to Vim9 or legacy |
| `lua/git_open.lua` | Lua/Neovim core logic |
| `lua/git_open/github.lua` | Lua GitHub provider |
| `lua/git_open/gitlab.lua` | Lua GitLab provider |
| `lua/git_open/codeberg.lua` | Lua Codeberg provider |
| `plugin/git_open.lua` | Lua entry point (Neovim) |
| `README.md` | User documentation |
| `doc/git_open.txt` | Vim help file |
| `CHANGELOG.md` | Version history |
| `CONTRIBUTING.md` | Provider interface contract, `repo_info` dict, `ProviderFunction` docs |
| `example_config.vim` | Configuration examples |
| `stylua.toml` | Lua formatter config (`column_width=120`, 2-space, double-quotes) |
| `.opencode/agent.md` | This file |
| `.opencode/conversation-log.md` | Full development log |
| `.opencode/skill.md` | Development guidelines |

## Quality Checklist

Before completing any task:
- [ ] All three implementations updated (Vim9script in `vim9/`, legacy in `autoload/`, Lua)
- [ ] Entry points updated if commands changed
- [ ] Code style consistent (4-space Vim, 2-space Lua)
- [ ] Run `stylua` on any modified Lua files before committing
- [ ] Feature parity maintained
- [ ] Error handling comprehensive
- [ ] Documentation updated (README, doc/git_open.txt, CONTRIBUTING.md)
- [ ] Files copied to both installed locations
- [ ] Committed and pushed
- [ ] No emojis added (unless requested)
