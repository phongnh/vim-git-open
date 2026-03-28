# vim-git-open

A Vim plugin to open git resources (files, branches, commits, PRs/MRs) in your browser. Works with GitHub, GitLab, Codeberg, and self-managed instances.

## Features

- Open repository home page
- Open current branch view
- Open current file at current commit with line numbers
- Open current commit
- Open pull requests (GitHub/Codeberg) or merge requests (GitLab)
- Open the last change (PR/MR or commit) for the current file
- Launch gitk for the repository or current file (with optional full rename history)
- Auto-detect provider from git remote URL
- Support for custom domain mappings
- Line number support (single line or visual selection range)
- Per-buffer remote selection with `:OpenGitRemote`
- Works with legacy Vim, Vim9script, and Neovim (Lua)

## Supported Git Providers

- GitHub / GitHub Enterprise
- GitLab / GitLab Self-Managed
- Codeberg
- Any Git hosting service with similar URL patterns

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'phongnh/vim-git-open'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim) (Neovim)

```lua
use 'phongnh/vim-git-open'
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (Neovim)

```lua
{ 'phongnh/vim-git-open' }
```

### Manual Installation

Copy the files to your `.vim` directory (or `~/.config/nvim` for Neovim):

```bash
git clone https://github.com/phongnh/vim-git-open.git
cp -r vim-git-open/plugin ~/.vim/
cp -r vim-git-open/autoload ~/.vim/
```

## Commands

All commands support a `!` (bang) variant that **copies the URL to the clipboard** instead of opening the browser.

| Command | Description |
|---------|-------------|
| `:OpenGitRepo[!]` | Open (or copy) the repository home page |
| `:OpenGitBranch[!] [branch]` | Open (or copy) a specified branch, or the current branch in normal mode. In visual mode, opens the selected text as the branch name |
| `:[range]OpenGitFile[!] [ref]` | Open (or copy) the current file at current commit, or at a specified branch/commit |
| `:OpenGitCommit[!] [commit]` | Open (or copy) a specified commit, or HEAD in normal mode. In visual mode, opens the selected text as the commit hash |
| `:OpenGitRequest[!] [number]` | Open (or copy) pull/merge request (auto-detects provider). Auto-parses from commit if no number given |
| `:OpenGitFileLastChange[!]` | Open (or copy) the PR/MR or commit that last changed the current file |
| `:OpenGitMyRequests[!] [state]` | Open (or copy) my pull/merge requests. Optional state: `-open`, `-closed`, `-merged`, `-all`. GitLab also accepts `-search` to use the search page |
| `:OpenGitRequests[!] [state]` | Open (or copy) the pull/merge requests page for the current repository. Optional state: `-open`, `-closed`, `-merged`, `-all` |
| `:OpenGitk [args]` | Launch `gitk` with optional free-form args (branch names, paths, etc.). Tab-completes branches and tracked files |
| `:OpenGitkFile[!]` | Launch `gitk -- <current-file>`. With `!`, shows the full rename history by resolving all historical paths via `git log --follow` |
| `:Gitk [args]` | Alias for `:OpenGitk` |
| `:GitkFile[!]` | Alias for `:OpenGitkFile` |
| `:OpenGitRemote[!] [remote]` | Print, set, or reset the active remote for the current buffer. No args: print current remote. With `[remote]`: validate and set. With `!`: reset so it re-resolves on next command |

### Line Number Support

`:OpenGitFile` automatically includes the current line number in the URL. You can also:
- Select lines in visual mode and run `:OpenGitFile` to open with a line range
- The format adapts to the Git provider (GitHub uses `#L10-L20`, GitLab uses `#L10-20`)

### Visual Mode Support for OpenGitBranch and OpenGitCommit

`:OpenGitBranch` and `:OpenGitCommit` support visual mode:
- In normal mode with no argument, they use the current branch / HEAD commit
- In visual mode, the selected text is used as the branch name or commit hash

## Configuration

### Custom Domain Mappings

For self-managed Git instances, you can map custom domains to their web URLs:

```vim
let g:vim_git_open_domains = {
    \ 'git.company.com': 'https://github.company.com',
    \ 'gitlab.internal': 'https://gitlab.internal.com',
    \ }
```

If no protocol is specified, `https://` is used by default:

```vim
let g:vim_git_open_domains = {
    \ 'git.example.com': 'github.example.com',
    \ }
```

### Custom Provider Detection

Override automatic provider detection:

```vim
let g:vim_git_open_providers = {
    \ 'git.company.com': 'GitLab',
    \ 'code.internal.com': 'GitHub',
    \ 'git.project.org': 'Codeberg',
    \ }
```

Supported provider values:
- `'GitHub'` - Uses GitHub URL structure
- `'GitLab'` - Uses GitLab URL structure
- `'Codeberg'` - Uses Codeberg/GitHub URL structure

### Custom Browser Command

By default, the plugin detects your browser in this order:
1. `$BROWSER` environment variable (if set)
2. OS-specific default:
   - macOS: `open`
   - Linux: `xdg-open`
   - Windows: `start`

To override, set:

```vim
let g:vim_git_open_browser_command = 'firefox'
```

Or set the `$BROWSER` environment variable in your shell:

```bash
export BROWSER=firefox
```

### GitLab Username

GitLab does not support a `@me` alias, so `:OpenGitMyRequests` needs your
username to filter MRs by author. It resolves the username in this order:

1. `g:vim_git_open_gitlab_username` (if set)
2. `$GITLAB_USER` environment variable (if set)
3. `$GLAB_USER` environment variable (if set, set by the [glab](https://gitlab.com/gitlab-org/cli) CLI)
4. `$USER` (system fallback)

To set it explicitly:

```vim
let g:vim_git_open_gitlab_username = 'your.username'
```

Or export the environment variable in your shell:

```bash
export GITLAB_USER=your.username
```

### Default Remote

Set a global default remote name. The plugin validates the name against the
actual remotes in the repository and falls back to `origin` (or the first
available remote) if not found:

```vim
let g:vim_git_open_remote = 'upstream'
```

Use `:OpenGitRemote` to override the remote for a specific buffer without
changing the global default.

## Usage Examples

### Basic Usage

```vim
" Open repository home page
:OpenGitRepo

" Copy repository URL to clipboard
:OpenGitRepo!

" Open current branch
:OpenGitBranch

" Open a specific branch
:OpenGitBranch main

" Open a branch by selecting its name in visual mode and running:
:'<,'>OpenGitBranch

" Open current file in browser (includes current line number)
:OpenGitFile

" Open current file at a specific branch or commit
:OpenGitFile main
:OpenGitFile abc1234

" Copy current file URL to clipboard
:OpenGitFile!

" Open current file with line range (use visual selection)
" Select lines 10-20 in visual mode, then:
:'<,'>OpenGitFile

" Open current commit
:OpenGitCommit

" Open a specific commit
:OpenGitCommit abc1234

" Open a commit by selecting its hash in visual mode:
:'<,'>OpenGitCommit

" Copy current commit URL to clipboard
:OpenGitCommit!
```

### Working with Requests (PRs/MRs)

```vim
" Open specific PR/MR number (auto-detects provider)
:OpenGitRequest 123

" Copy PR/MR URL to clipboard
:OpenGitRequest! 123

" Auto-parse PR/MR from commit message (e.g., "Fix bug (#456)" or "Merge !234")
:OpenGitRequest

" Open the last change for current file
" If the file's latest commit has a PR/MR number, opens that PR/MR
" Otherwise, opens the commit
:OpenGitFileLastChange

" Copy last change URL to clipboard
:OpenGitFileLastChange!

" Open my PRs/MRs for current git provider (defaults to open)
:OpenGitMyRequests

" Filter my PRs/MRs by state (GitHub/Codeberg)
:OpenGitMyRequests -closed
:OpenGitMyRequests -merged
:OpenGitMyRequests -all

" GitLab: use search page scoped to current user
:OpenGitMyRequests -search

" Open PRs/MRs page for current repository (defaults to open)
:OpenGitRequests

" Filter repository PRs/MRs by state
:OpenGitRequests -closed
:OpenGitRequests -merged
:OpenGitRequests -all
```

### Working with gitk

```vim
" Open gitk for the whole repository
:OpenGitk

" Open gitk for a specific branch
:OpenGitk main

" Open gitk for the current file
:OpenGitkFile

" Open gitk with full rename history of the current file
:OpenGitkFile!
```

### Per-Buffer Remote Selection

```vim
" Check which remote is active for this buffer
:OpenGitRemote

" Switch this buffer to use 'upstream'
:OpenGitRemote upstream

" Reset so the plugin re-resolves on the next command
:OpenGitRemote!

" Set a global default remote in vimrc
let g:vim_git_open_remote = 'upstream'
```

### Example Keymaps

Add to your `.vimrc` or `init.vim`:

```vim
" Open repository
nnoremap <leader>go :OpenGitRepo<CR>

" Copy repository URL
nnoremap <leader>gO :OpenGitRepo!<CR>

" Open current branch
nnoremap <leader>gb :OpenGitBranch<CR>
" Open branch under visual selection
vnoremap <leader>gb :OpenGitBranch<CR>

" Open current file
nnoremap <leader>gf :OpenGitFile<CR>
" Also works in visual mode for line ranges
vnoremap <leader>gf :OpenGitFile<CR>

" Copy current file URL
nnoremap <leader>gF :OpenGitFile!<CR>
vnoremap <leader>gF :OpenGitFile!<CR>

" Open current commit
nnoremap <leader>gc :OpenGitCommit<CR>
" Open commit hash under visual selection
vnoremap <leader>gc :OpenGitCommit<CR>

" Open PR/MR (auto-detects provider)
nnoremap <leader>gp :OpenGitRequest<CR>

" Open last change for current file
nnoremap <leader>gl :OpenGitFileLastChange<CR>

" Open my PRs/MRs
nnoremap <leader>gP :OpenGitMyRequests<CR>

" Open PRs/MRs for current repo
nnoremap <leader>gR :OpenGitRequests<CR>
```

## How It Works

1. **Remote Detection**: Parses `.git/config` to find the remote origin URL
2. **Provider Detection**: Identifies the Git provider (GitHub, GitLab, Codeberg) from the domain
3. **URL Building**: Constructs the appropriate web URL based on the provider
4. **Browser Opening**: Uses the system's default browser command to open the URL

### Remote URL Formats Supported

SSH format:
```
git@github.com:user/repo.git
ssh://git@gitlab.com/user/repo.git
```

HTTPS format:
```
https://github.com/user/repo.git
https://gitlab.com/user/repo
```

## Advanced Configuration

### Example for Enterprise Setup

```vim
" Map internal git server to external GitHub Enterprise
let g:vim_git_open_domains = {
    \ 'git.mycompany.com': 'https://github.mycompany.com',
    \ 'gitlab.internal': 'https://gitlab.mycompany.com',
    \ }

" Specify providers for custom domains
let g:vim_git_open_providers = {
    \ 'git.mycompany.com': 'GitHub',
    \ 'gitlab.internal': 'GitLab',
    \ }
```

## Versions

The plugin ships all three implementations in a single branch and selects the right one automatically at startup — no configuration required:

| Implementation | File | Loaded when |
|---|---|---|
| Vim9script | `plugin/git_open.vim` | Vim with `vim9script` support (Vim 9.0+) |
| Legacy Vimscript | `plugin/git_open_legacy.vim` | Vim without `vim9script` support (Vim 7.0+) |
| Lua | `plugin/git_open.lua` | Neovim |

All three implementations have full feature parity.

## Troubleshooting

### "Not a git repository" error in fugitive buffers

If you get this error inside a fugitive blame view (`fugitive://` buffers or `fugitiveblame` filetype), the plugin now automatically detects the git root via `FugitiveGitDir()`. Make sure [vim-fugitive](https://github.com/tpope/vim-fugitive) is installed and loaded.

### "Not a git repository" error

Make sure you're inside a git repository with a configured remote:

```bash
git remote -v
```

### Browser doesn't open

Check your browser command:

```vim
:echo g:vim_git_open_browser_command
```

Set it manually if needed:

```vim
let g:vim_git_open_browser_command = 'google-chrome'
```

### Wrong provider detected

Manually specify the provider:

```vim
let g:vim_git_open_providers = {'your.domain': 'GitLab'}
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

MIT License

## Credits

Created by Phong Nguyen
