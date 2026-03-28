# vim-git-open

A Vim plugin to open git resources (files, branches, commits, PRs/MRs) in your browser. Works with GitHub, GitLab, Codeberg, and self-managed instances.

## Features

- Open repository home page
- Open current branch view
- Open current file at current commit with line numbers
- Open current commit
- Open pull requests (GitHub/Codeberg) or merge requests (GitLab)
- Open the last change (PR/MR or commit) for the current file
- Auto-detect provider from git remote URL
- Support for custom domain mappings
- Line number support (single line or visual selection range)
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

| Command | Description |
|---------|-------------|
| `:OpenGitRepo` | Open the repository home page |
| `:OpenGitBranch` | Open the current branch in browser |
| `:OpenGitFile` | Open the current file at current commit (supports line numbers) |
| `:OpenGitCommit` | Open the current commit |
| `:OpenGitRequest [number]` | Open pull/merge request (auto-detects provider). Auto-parses from commit if no number given |
| `:OpenGitFileLastChange` | Open the PR/MR or commit that last changed the current file |
| `:OpenGitMyRequests` | Open all my pull requests / merge requests for the current git provider |
| `:OpenGitRequests` | Open the pull requests / merge requests page for the current repository |

### Line Number Support

`:OpenGitFile` automatically includes the current line number in the URL. You can also:
- Select lines in visual mode and run `:OpenGitFile` to open with a line range
- The format adapts to the Git provider (GitHub uses `#L10-L20`, GitLab uses `#L10-20`)

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

## Usage Examples

### Basic Usage

```vim
" Open repository home page
:OpenGitRepo

" Open current branch
:OpenGitBranch

" Open current file in browser (includes current line number)
:OpenGitFile

" Open current file with line range (use visual selection)
" Select lines 10-20 in visual mode, then:
:'<,'>OpenGitFile

" Open current commit
:OpenGitCommit
```

### Working with Requests (PRs/MRs)

```vim
" Open specific PR/MR number (auto-detects provider)
:OpenGitRequest 123

" Auto-parse PR/MR from commit message (e.g., "Fix bug (#456)" or "Merge !234")
:OpenGitRequest

" Open the last change for current file
" If the file's latest commit has a PR/MR number, opens that PR/MR
" Otherwise, opens the commit
:OpenGitFileLastChange

" Open my PRs/MRs for current git provider
:OpenGitMyRequests

" Open PRs/MRs page for current repository
:OpenGitRequests
```

### Example Keymaps

Add to your `.vimrc` or `init.vim`:

```vim
" Open repository
nnoremap <leader>go :OpenGitRepo<CR>

" Open current branch
nnoremap <leader>gb :OpenGitBranch<CR>

" Open current file
nnoremap <leader>gf :OpenGitFile<CR>
" Also works in visual mode for line ranges
vnoremap <leader>gf :OpenGitFile<CR>

" Open current commit
nnoremap <leader>gc :OpenGitCommit<CR>

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

This plugin is available in three implementations:

- **master branch**: Legacy Vimscript (compatible with Vim 7.0+)
- **vim9 branch**: Vim9script (requires Vim 9.0+)
- **lua branch**: Lua (Neovim only)

All versions have the same features and API. Use the master branch for maximum compatibility.

## Troubleshooting

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
