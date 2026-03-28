# vim-git-open Development Log

Chronological log of all user requests, requirements, and implementation decisions.

---

## Session 1: Initial Setup and Complete Implementation
**Date:** 2026-03-27

### Request 1: Project Overview
- Provided summary of initial goals: build a Vim plugin to open git resources in browser
- Three implementations: Legacy Vimscript, Vim9script, and Lua/Neovim
- All core features completed and pushed to GitHub (77b3c5b)

### Request 2: Switch Remote to SSH
- Updated remote from HTTPS to SSH: `git@github.com:phongnh/vim-git-open.git`
- Successfully pushed to GitHub

### Request 3: Neovim Loading Improvement
- Added `has('nvim')` guard to `plugin/git_open.vim` to prevent loading in Neovim
- Moved `lua_plugin/git_open.lua` → `plugin/git_open.lua` for native Neovim autoload
- **Commit:** 76dfcad

### Request 4: Save Conversation and Generate Skill/Agent Files
- Created `.opencode/conversation-log.md`, `.opencode/skill.md`, `.opencode/agent.md`
- **Commit:** 11a92c4

### Request 5: Save Full Transcript
- Created `.opencode/conversation-transcript.md`
- **Commit:** 154759f

---

## Session 2: Bug Fixes and Feature Additions
**Date:** 2026-03-27 (continued)

### Fix: get_git_root in Lua
- Lua `get_git_root()` was returning a path with `.git` suffix
- Fixed to return the parent directory (absolute path without `.git`)
- **Commit:** c15bf7d

### Fix: get_relative_path in Lua
- Used string comparison instead of regex for robustness
- **Commit:** 204be87

### Fix: get_git_root in Vimscript and Vim9script
- **Commit:** d36d7eb

### Fix: OpenGitFile (Vimscript and Vim9script)
- Two bugs fixed in line number handling
- **Commit:** 566ddfc

### Feature: OpenGitFileLastChange (v1.1.0)
- New command that opens the PR/MR or commit that last changed the current file
- Added `parse_pr_mr_number()` helper
- All three implementations updated
- **Commits:** a04c0d8, 71089e0, 4459260

### Feature: $BROWSER environment variable support
- Plugin now checks `$BROWSER` env var before OS defaults
- **Commit:** 3e2f868

### Feature: OpenGitMyPRs (v1.2.0)
- New command to open current user's PRs/MRs
- **Commit:** 336d147

### Feature: OpenGitPRs
- New command to open repo's PR/MR listing page
- **Commit:** ed2bdf8

### Refactor: Dispatcher pattern for plugin loading
- `plugin/git_open.vim` became a dispatcher that selects Vim9script or legacy
- **Commit:** 123ec46

### Fix: Vim9script loading and missing functions
- **Commit:** be61a76

### Fix: Vim9script type annotations
- Removed unsupported `export type` declarations (Vim 9.2.250 incompatibility)
- **Discovery:** `export type` keyword not supported in Vim 9.2.250
- **Commit:** e6d1579

### Fix: Terminal escape sequences in OpenBrowser
- **Commit:** 2ca77a2

### Refactor: Unify PR/MR into provider-agnostic interface
- Merged `OpenGitPR` / `OpenGitMR` into single `OpenGitRequest` command
- Auto-detects provider and uses appropriate URL structure
- **Commit:** 649630c

### Refactor: Restructure plugin — Vim9script default, legacy in autoload/git_open/legacy.vim
- Vim9script is now the primary implementation
- Legacy Vimscript moved to `autoload/git_open/legacy.vim`
- **Commit:** 842a889

### Fix: plugin/git_open.vim — move vim9script declaration after legacy guard
- **Discovery:** `vim9script` at top of file errors on old Vim; `if !has('vim9script') | finish | endif` guard must come first
- **Commit:** c6041e1

### Fix: Vim9script variadic forwarding in BuildUrl
- **Discovery:** Use `call(FuncRef, [args] + extra)` instead of `...extra` spread
- **Commit:** 82d8ca2

### Fix: Replace echoerr with friendly red messages
- **Discovery:** `echoerr` shows stack trace; use `echohl ErrorMsg` + `echom` + `echohl None`
- Applied to all three implementations
- **Commit:** df4224b

### Fix: OpenFile range — pass line1/line2 as explicit parameters
- **Discovery:** `range` attribute invalid in Vim9script; use `-range` flag and pass `<line1>`, `<line2>` as args
- **Discovery:** `<line1>,<line2>FuncCall()` syntax invalid in Vim9script (E1050)
- **Discovery:** `mode()` always returns `'n'` inside `:` command; use `-range` + `<line1>`,`<line2>`
- **Commit:** 46f792b

### Fix: Quoted line numbers in OpenGitFile URL
- **Discovery:** `string()` in Vim9script adds quotes around numbers; use `'' .. value` for plain coercion
- **Commit:** 97a8a2b

### Feature: Bang support — copy URL to clipboard instead of opening browser
- Added `!` variant to all commands
- **Discovery:** `<bang>0` evaluates to `0` (no bang) or `1` (bang used)
- **Commit:** 45d8627

### Feature: Optional args to OpenGitBranch, OpenGitFile, OpenGitCommit
- `OpenGitBranch [branch]`, `OpenGitFile [ref]`, `OpenGitCommit [commit]`
- **Discovery:** URL builder `file` type extra argument slots: `extra[0]` = file path, `extra[1]` = line info, `extra[2]` = ref
- **Commit:** 059d717

### Feature: Branch tab-completion for OpenGitBranch and OpenGitFile
- **Commit:** 24194da

### Fix: Branch completion — bare names without remote prefix
- **Discovery:** `lstrip=2` for local (`refs/heads/`), `lstrip=3` for remote (`refs/remotes/`) to get bare names
- **Commit:** 27d0e67, 14d51a5

### Improve: Branch completion — sort by committerdate, use matchfuzzy
- **Discovery:** `matchfuzzy()` always available in Vim9script and Neovim/Lua; check `exists('*matchfuzzy')` in legacy
- **Commit:** 95c12c4

### Docs: Update Versions section
- Single branch, auto-loaded by implementation
- **Commit:** 406770e

---

## Session 3: State Filtering for Requests
**Date:** 2026-03-28

### Feature: State flag for OpenGitRequests and OpenGitMyRequests (GitHub/Codeberg)
- Added `-open`, `-closed`, `-merged`, `-all` flags to both commands
- **Commit:** 26bc4da

### Fix: GitHub/Codeberg pulls URL — use is:pr query param
- **Discovery:** `?state=closed` routes to issues endpoint; must use `?q=is%3Apr+is%3Aclosed` for PRs
- **Commit:** d67c734

### Fix: Codeberg state filtering — pass provider to parse_request_state
- **Discovery:** Codeberg uses `?state=open|closed|all` param (Gitea simple API); no `is:pr` needed
- Fixed Lua `open_my_requests` and `open_requests` to pass `info.provider` to `parse_request_state`
- **Commit:** 61d452c

### Feature: Tab-completion for state flags
- Added `CompleteRequestState` / `complete_request_state` / `M.complete_request_state` in all three implementations
- **Commit:** ee26d90

### Feature: GitLab state filtering for OpenGitRequests/OpenGitMyRequests
- Added `?state=merged|closed|all` to `ParseRequestState` for GitLab
- **Discovery:** GitLab state param uses `opened` (not `open`); `-open` falls through to `''`
- **Commit:** e4e6b2e

### Refactor: Drop redundant GitLab -open case
- `-open` is redundant for GitLab (default is already opened)
- **Commit:** be49193

### Fix: GitHub OpenGitMyRequests — author:@me injection
- No flag / `-open` → bare `/pulls`; with state → append `+author%3A%40me` to `q` param
- **Discovery:** GitHub `OpenGitMyRequests`: no flag/`-open` → bare `/pulls`; with state flag → append `+author%3A%40me`
- **Commit:** 2db1cf5, 8f131c1, 314ec6c

### Fix: Terminal escape sequences
- `redraw` → `redraw!` in `OpenBrowser` and `CopyToClipboard` (Vim9script + legacy)
- **Discovery:** `> /dev/null 2>&1` on browser `system()` call + `redraw!` before `echo` suppresses escape sequences
- **Commit:** cb1412b

### Feature: GetGitLabUsername helper
- GitLab does not support `@me` alias — username must be resolved explicitly
- Resolution order: `g:vim_git_open_gitlab_username` → `$GITLAB_USER` → `$GLAB_USER` → `$USER`
- Added `GetGitLabUsername()` / `get_gitlab_username()` / `get_gitlab_username()` in all three implementations
- **Commit:** c20be3b

### Feature/Rework: GitLab OpenGitMyRequests — dashboard page routing
- No flag / `-open` / `-all` → `/dashboard/merge_requests`
- `-closed` / `-merged` → `/dashboard/merge_requests/merged`
- `-search` → `/dashboard/merge_requests/search?author_username=<user>`
- **Discovery:** GitLab dashboard page `/dashboard/merge_requests` shows MRs authored by current user by default
- **Commits:** c0c9d91, 10f267a

### Feature: CompleteMyRequestState — separate from CompleteRequestState
- `CompleteMyRequestState` adds `-search`, `-search=open`, `-search=closed`, `-search=merged`, `-search=all`
- `CompleteRequestState` only has `-open`, `-closed`, `-merged`, `-all`
- `-search=<state>` compound flag: split on `=`, append `&state=<value>` to search URL
- **Discovery:** Separate completion functions needed; `-search` belongs only in MyRequests completion
- **Commit:** 97348da

### Docs: Update README usage section
- Updated Commands table with `[state]` argument for OpenGitMyRequests and OpenGitRequests
- Expanded "Working with Requests" examples to show state filtering and `-search` flag
- **Commit:** 0ea5cd7

---

## Session 4: Gitk Commands, Visual Selection, and GetGitRoot Fixes
**Date:** 2026-03-28 (continued)

### Feature: OpenGitk, OpenGitkFile, OpenGitkFileHistory
- New commands to launch gitk for repository, current file, or full rename history
- `:OpenGitkFile!` adds `--follow` for rename tracking
- `:OpenGitkFileHistory` resolves all historical paths via `git log --follow`
- All three implementations updated
- **Commit:** f4958d8

### Fix: OpenGitk — shellescape in Launch path
- Don't double-shellescape args when using `:Launch` path
- **Commit:** 2c8c39f

### Fix: Launch path — silent lcd
- Use `silent lcd` to suppress directory echo
- **Commit:** 7afa8fd

### Redesign: OpenGitkFile
- Bang variant adds `--follow` (previously showed full rename history)
- Full rename history now lives in `:OpenGitkFileHistory`
- **Commits:** fb99375, 1c0098d

### Refactor: CompleteGitkBranch
- Replaced `CompleteGitkArgs` with `CompleteGitkBranch` for `OpenGitk` and `OpenGitkFile`
- **Commit:** 15954a0

### Feature: File completion for OpenGitk
- Added tracked file completion to `CompleteGitkArgs`
- **Commit:** f65379f

### Refactor: Completion helpers
- Extracted `UniqueAdd` / `FuzzyFilter` helpers across all three implementations
- **Commit:** caacf35

### Refactor: Unique helper
- Renamed `UniqueAdd` → `Unique(items)`, returns new list instead of mutating
- **Commit:** 6ecff94

### Feature: Gitk and GitkFile command aliases
- `:Gitk` = alias for `:OpenGitk`
- `:GitkFile` = alias for `:OpenGitkFile`
- **Commit:** 0ab5f8e

### Feature: Visual selection for OpenGitBranch and OpenGitCommit
- In visual mode, selected text is used as branch name / commit hash
- **Commit:** 586b859

### Fix: GetGitRoot — fugitive virtual buffer support (step 1)
- Added `FugitiveGitDir()` detection for `fugitive://` and `fugitiveblame` buffers
- **Commit:** c09d49b

### Fix: GetGitRoot — Vim9script compile errors
- Fixed `var [_, l1, c1, _]` repeated `_` discard (not allowed in Vim9)
- Fixed bare `getregion()` call (use `call('getregion', [...])`)
- **Commit:** 8d7b7ce

### Fix: GetGitRoot — use call() string for FugitiveWorkTree
- **Commit:** da5b2c1

### Fix: GetGitRoot — use FugitiveGitDir instead of FugitiveWorkTree
- `FugitiveWorkTree()` triggers E15 in Vim 9.2; `FugitiveGitDir()` reads `b:git_dir` directly
- **Discovery:** Use `FugitiveGitDir()` not `FugitiveWorkTree()` for fugitive root detection
- **Commit:** f53adf7

### Fix: GetGitRoot — 3-step detection with getcwd() fallback
- Step 1: `FugitiveGitDir()` via try/catch; Step 2: finddir(bufname); Step 3: finddir(cwd)
- **Commit:** 35e395b

### Debug: GetGitRoot debug logging (temporary, reverted)
- Added `g:vim_git_open_debug` gated logging (added then removed same session)
- **Commits:** e663e36, 0de4cfa

### Fix: GetGitRoot Vim9script — replace exists() with try/catch
- `exists('*FugitiveGitDir')` inside a `def` is always `false` at compile time
- **Discovery:** `exists('*FuncName')` in Vim9 `def` is resolved at compile time — always false for late-loaded plugins. Use `try/catch call('FuncName', [])` instead.
- **Commit:** 07fbac3

### Fix: Duplicate get_git_root in Lua
- Removed leftover duplicate `get_git_root()` function from `lua/git_open.lua`
- **Commit:** 0de4cfa

### Fix: OpenBranch/OpenCommit normal mode fallback
- In normal mode with no arg, now correctly falls back to current branch / HEAD commit
- **Root cause:** `OpenBranch`/`OpenCommit` passed explicit (empty) arg to `BuildUrl`, making `len(extra) > 0` always true, bypassing the fallback inside `BuildUrl`
- **Discovery:** `OpenBranch`/`OpenCommit` must call `GetCurrentBranch()`/`GetCurrentCommit()` explicitly; do not rely on `BuildUrl`'s internal fallback
- **Commit:** f6e2a6e

---

## Session 5: Remove OpenGitkFileHistory, doc/usage cleanup
**Date:** 2026-03-28 (continued)

### Fix: doc — remove OpenGitkFileHistory section, clean up formatting
- Removed backtick inline code from `doc/git_open.txt` (not valid Vim help syntax)
- **Commit:** 631f320

### Fix: doc — condense OpenGitkFileHistory to single-line entry
- Reduced the full section to a compact command entry
- **Commit:** 7131793

### Fix: doc — remove OpenGitkFileHistory entirely, correct OpenGitkFile! description
- `:OpenGitkFileHistory` does not exist as a command; `!` on `:OpenGitkFile` is what shows full rename history
- Updated `:OpenGitkFile[!]` description: "With [!], shows the full rename history of the current file across all renames by resolving all historical paths via git log --follow"
- Updated `:GitkFile` alias description accordingly
- **Commit:** 975dd90

### Docs: Update README, doc, agent, skill, conversation files
- `README.md`: removed `:OpenGitkFileHistory` row from commands table and usage examples; updated `:OpenGitkFile[!]` description; updated Features list
- `doc/git_open.txt`: removed `:OpenGitkFileHistory` from requirements; fixed `:GitkFile` alias wording; fixed backticks in troubleshooting section; updated features list
- `.opencode/agent.md`: commands table updated (removed `OpenGitkFileHistory`, corrected `OpenGitkFile[!]` notes)
- `.opencode/skill.md`: commands table updated (same); also added gitk/alias commands which were missing entirely; updated `OpenGitBranch`/`OpenGitCommit` notes with visual mode info

---

## Key Discoveries (Cumulative)

1. `string()` in Vim9script adds quotes around numbers — use `'' .. value`
2. Vim9script variadic forwarding: use `call(FuncRef, [args] + extra)`
3. `range` attribute invalid in Vim9script — pass `<line1>` and `<line2>` as explicit args
4. `<line1>,<line2>FuncCall()` syntax invalid in Vim9script (E1050)
5. `mode()` always returns `'n'` inside `:` command
6. `vim9script` at top of file errors on old Vim — guard must come first
7. `echoerr` shows stack trace — use `echohl ErrorMsg` + `echom` + `echohl None`
8. `> /dev/null 2>&1` + `redraw!` before `echo` suppresses terminal escape sequences
9. `export type` keyword not supported in Vim 9.2.250
10. `<bang>0` evaluates to `0` (no bang) or `1` (bang used)
11. URL builder `file` extra slots: `extra[0]`=path, `extra[1]`=line info, `extra[2]`=ref
12. Legacy Vimscript variadic args: `a:000` passed directly via `call()`
13. `%(refname:short)` in zsh must be single-quoted to avoid glob interpretation
14. Branch completion: `lstrip=2` for local, `lstrip=3` for remote bare names
15. `matchfuzzy()` always available in Vim9script/Lua; check `exists('*matchfuzzy')` in legacy
16. GitHub PR state filtering: must use `?q=is%3Apr+is%3Aclosed` (not `?state=closed`)
17. Codeberg PR state filtering: uses `?state=open|closed|all` (Gitea simple API)
18. `ParseRequestState` takes provider as second arg
19. GitLab state param uses `opened` (not `open`)
20. GitHub `OpenGitMyRequests`: no flag/`-open` → bare `/pulls`; with state → `+author%3A%40me`
21. GitLab does not support `@me` alias — resolve username explicitly
22. GitLab `OpenGitMyRequests` uses `/dashboard/merge_requests` family of URLs
23. Separate `CompleteMyRequestState` needed; `-search` only belongs in MyRequests completion
24. `-search=<state>` parsing: split on `=`, map second part to `&state=<value>`
25. `exists('*FuncName')` in Vim9 `def` is compile-time — always false for late-loaded plugins; use `try/catch call('FuncName', [])` instead
26. `FugitiveGitDir()` not `FugitiveWorkTree()` — the latter triggers E15 in Vim 9.2
27. `GetGitRoot` must use 3-step detection: FugitiveGitDir (try/catch) → finddir(bufname) → finddir(cwd)
28. `OpenBranch`/`OpenCommit` must set fallback explicitly — `BuildUrl`'s internal fallback is bypassed when any extra arg is passed
29. `var [_, l1, c1, _]` repeated `_` discard not allowed in Vim9script — use distinct names

---

## Repository Information

- **SSH URL:** git@github.com:phongnh/vim-git-open.git
- **Branch:** main
- **License:** MIT
- **Maintainer:** Phong Nguyen

## Commit History (All Sessions)

| Commit | Description |
|--------|-------------|
| 77b3c5b | Initial release v1.0.0 |
| 76dfcad | Improve Neovim loading: prevent duplicate loading |
| 11a92c4 | Add OpenCode configuration files |
| 154759f | Add complete conversation transcript |
| c15bf7d | Fix get_git_root in Lua |
| 204be87 | Fix get_relative_path in Lua |
| d36d7eb | Fix get_git_root in Vimscript and Vim9script |
| 566ddfc | Fix OpenGitFile in Vimscript and Vim9script |
| a04c0d8 | Add OpenGitFileLastChange command (v1.1.0) |
| 71089e0 | Fix OpenGitFileLastChange: use correct function names |
| 4459260 | Fix OpenGitFileLastChange: add parse_pr_mr_number helper |
| 3e2f868 | Add $BROWSER environment variable support |
| 336d147 | Add OpenGitMyPRs command (v1.2.0) |
| ed2bdf8 | Add OpenGitPRs command |
| 123ec46 | Refactor plugin/git_open.vim as dispatcher |
| be61a76 | Fix Vim9script plugin loading and missing functions |
| e6d1579 | Fix Vim9script: remove export type declarations |
| 2ca77a2 | Fix Vim9script type annotations and terminal escape sequences |
| 649630c | Unify PR/MR commands into provider-agnostic interface |
| 842a889 | Restructure plugin: Vim9script default, legacy in autoload/git_open/legacy.vim |
| c6041e1 | Fix plugin/git_open.vim: move vim9script declaration after legacy guard |
| 82d8ca2 | Fix Vim9script variadic forwarding in BuildUrl |
| df4224b | Replace echoerr with friendly red message helper |
| 46f792b | Fix OpenFile range: pass line1/line2 as explicit parameters |
| 97a8a2b | Fix quoted line numbers in OpenGitFile URL |
| 45d8627 | Add bang support: copy URL to clipboard |
| 059d717 | Add optional args to OpenGitBranch, OpenGitFile, OpenGitCommit |
| 24194da | Add branch tab-completion |
| 27d0e67 | Fix branch completion: quote %(refname:short) |
| 14d51a5 | Fix branch completion: list bare branch names |
| 95c12c4 | Improve branch completion: sort by committerdate, use matchfuzzy |
| 406770e | Update Versions section |
| 26bc4da | Add state flag to OpenGitRequests and OpenGitMyRequests |
| d67c734 | Fix GitHub/Codeberg pulls URL: use is:pr query param |
| 61d452c | Fix Codeberg state filtering: pass provider to parse_request_state |
| ee26d90 | Add tab-completion for state flags |
| e4e6b2e | Add GitLab state filtering |
| be49193 | Refactor GitLab state: drop -open (redundant) |
| 2db1cf5 | Fix GitHub OpenGitMyRequests: only add author:@me when state flag given |
| 8f131c1 | Simplify GitHub OpenGitMyRequests |
| 314ec6c | Fix OpenGitMyRequests for GitHub |
| cb1412b | Fix terminal escape sequences: use redraw! |
| c20be3b | Resolve GitLab username for OpenGitMyRequests |
| c0c9d91 | Update GitLab my requests URL |
| 10f267a | Rework GitLab OpenGitMyRequests: dashboard page, -search flag |
| 97348da | Add CompleteMyRequestState and -search=<state> compound flag |
| 0ea5cd7 | Update README usage: document state flags |
| cee21de | Update .opencode files: sync conversation log, transcript, agent, and skill |
| f4958d8 | Add OpenGitk, OpenGitkFile, OpenGitkFileHistory commands |
| 2c8c39f | Fix OpenGitk: don't shellescape args in :Launch path |
| 7afa8fd | Fix :Launch path: use silent lcd to suppress directory echo |
| fb99375 | Redesign OpenGitkFile: always show full rename history |
| 1c0098d | Redesign OpenGitkFile: bang for full rename history |
| 15954a0 | Replace CompleteGitkArgs with CompleteGitkBranch for OpenGitk and OpenGitkFile |
| f65379f | Add file completion to OpenGitk via CompleteGitkArgs |
| caacf35 | Refactor completion functions: extract UniqueAdd/FuzzyFilter helpers |
| 6ecff94 | Refactor: rename UniqueAdd->Unique, return new list instead of mutating |
| 0ab5f8e | Add Gitk and GitkFile as aliases for OpenGitk and OpenGitkFile |
| 586b859 | Add visual selection support to OpenGitBranch and OpenGitCommit |
| c09d49b | Fix git root detection in fugitive virtual buffers |
| 8d7b7ce | Fix Vim9script compile errors in GetGitRoot and GetVisualSelection |
| da5b2c1 | Fix Vim9script compile error: use call() string for FugitiveWorkTree |
| f53adf7 | Fix GetGitRoot: use FugitiveGitDir() instead of FugitiveWorkTree() |
| 35e395b | Simplify GetGitRoot: 3-step detection with getcwd() fallback |
| e663e36 | Add debug logging to GetGitRoot (gated by g:vim_git_open_debug) |
| 07fbac3 | Fix GetGitRoot step 1: replace exists() guard with try/catch in Vim9script |
| 0de4cfa | Remove debug logging helpers and fix duplicate get_git_root in Lua |
| f6e2a6e | Fix OpenBranch/OpenCommit: use current branch/HEAD when no arg given |
| f742d7a | Update docs and .opencode: Session 4 gitk commands, visual selection, GetGitRoot fixes |
| 631f320 | doc: clean up OpenGitkFileHistory section formatting |
| 7131793 | doc: condense OpenGitkFileHistory to single-line command entry |
| 975dd90 | doc: remove OpenGitkFileHistory entry, update OpenGitkFile! description |
