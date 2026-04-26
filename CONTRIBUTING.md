# Contributing to vim-git-open

Thank you for considering contributing to vim-git-open! We welcome contributions from everyone.

## Ways to Contribute

- Report bugs
- Suggest new features or enhancements
- Submit pull requests with bug fixes or new features
- Improve documentation
- Share the plugin with others

## Reporting Bugs

When reporting bugs, please include:

1. Your Vim/Neovim version (`vim --version` or `:version`)
2. Your operating system
3. Steps to reproduce the bug
4. Expected behavior
5. Actual behavior
6. Any error messages (`:messages` in Vim)
7. Your git remote URL format (e.g., SSH or HTTPS)

## Suggesting Features

When suggesting features, please:

1. Check if the feature already exists
2. Explain the use case and why it would be valuable
3. Provide examples of how it would work
4. Consider backward compatibility

## Submitting Pull Requests

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/vim-git-open.git
   cd vim-git-open
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Code Guidelines

- **Vimscript (Legacy)**: Follow standard Vimscript conventions
  - Use CamelCase for public autoload functions (e.g. `git_open#github#BuildRepoUrl`)
  - Prefix script-local functions with `s:`
  - Use `abort` on all functions
  - Add comments for complex logic

- **Vim9script**: Follow Vim9script conventions
  - Use PascalCase for function names
  - Use type annotations where appropriate
  - Use `def` and `enddef` for functions

- **Lua**: Follow Lua conventions
  - Use snake_case for function names
  - Use local functions where appropriate
  - Add comments for complex logic

### Testing

Before submitting a PR:

1. Test with different Git providers (GitHub, GitLab, Codeberg)
2. Test with both SSH and HTTPS remote URLs
3. Test all commands
4. Ensure backward compatibility

### Committing Changes

1. Write clear, descriptive commit messages
2. Keep commits focused on a single change
3. Reference issues in commit messages when applicable

Example commit message:
```
Add support for Bitbucket provider

- Implement URL builder for Bitbucket
- Add provider detection for bitbucket.org
- Update documentation

Closes #123
```

### Pull Request Process

1. Update the README.md if needed
2. Update documentation (doc/git_open.txt) if adding features
3. Ensure all versions (Vimscript, Vim9script, Lua) have the same features
4. Write a clear PR description explaining:
   - What changes you made
   - Why you made them
   - How to test them

5. Wait for review and address any feedback

## Code of Conduct

- Be respectful and constructive
- Welcome newcomers and help them learn
- Focus on the code, not the person
- Accept constructive criticism gracefully

## Adding New Git Providers

Provider modules live in `autoload/git_open/{provider}.vim` (lowercase filename,
e.g. `autoload/git_open/bitbucket.vim`). Each module must implement the
following interface. `repo_info` is the dict returned by `s:GetRepoInfo()` /
`s:GetRepoInfoForRemote()` and has the keys `domain`, `path`, `provider`,
`base_url`.

```vim
" Required — called by s:CallProvider()
function! git_open#bitbucket#ParseRequestNumber(message)   abort | ... | endfunction
function! git_open#bitbucket#BuildRepoUrl(repo_info)                          abort | ... | endfunction
function! git_open#bitbucket#BuildBranchUrl(repo_info, branch)                abort | ... | endfunction
function! git_open#bitbucket#BuildFileUrl(repo_info, file, line_info, ref)    abort | ... | endfunction
function! git_open#bitbucket#BuildCommitUrl(repo_info, commit)                abort | ... | endfunction
function! git_open#bitbucket#BuildRequestUrl(repo_info, number)               abort | ... | endfunction
function! git_open#bitbucket#BuildRequestsUrl(repo_info, state_arg)           abort | ... | endfunction
function! git_open#bitbucket#BuildMyRequestsUrl(repo_info, state_arg)         abort | ... | endfunction
```

`line_info` is a string: a single line number (`'10'`) or a range (`'10-20'`),
or empty. `ref` is a branch name or a 40-character commit SHA. `state_arg` is
one of `''`, `'-open'`, `'-closed'`, `'-merged'`, `'-all'` (handling is
provider-specific).

The same interface must also be implemented in Vim9script and Lua. The Lua
module (`lua/git_open/bitbucket.lua`) must return a table `M` with snake_case
equivalents:

```lua
local M = {}

function M.parse_request_number(message)           ... end
function M.build_repo_url(repo_info)               ... end
function M.build_branch_url(repo_info, branch)     ... end
function M.build_file_url(repo_info, file, line_info, ref) ... end
function M.build_commit_url(repo_info, commit)     ... end
function M.build_request_url(repo_info, number)    ... end
function M.build_requests_url(repo_info, state_arg) ... end
function M.build_my_requests_url(repo_info, state_arg) ... end

return M
```

`repo_info` is a Lua table with keys: `domain`, `path`, `provider`,
`base_url`. `line_info`, `ref`, `state_arg` have the same semantics as the
VimL versions above.

To wire up the new provider:

1. **Create** `autoload/git_open/bitbucket.vim` (Legacy VimL) implementing the
   interface above.

2. **Create** `vim9/autoload/git_open/bitbucket.vim` (Vim9script) with
   `export def` equivalents (PascalCase names).

3. **Create** `lua/git_open/bitbucket.lua` (Lua) with the `M` table above.

4. **Add provider detection** in all three core files:
   - `autoload/git_open.vim` → `s:DetectProvider()` + `s:ProviderFunction()`
   - `vim9/autoload/git_open.vim` → `DetectProvider()` + `ProviderFunction()`
   - `lua/git_open.lua` → `detect_provider()` (the `require("git_open." ..
     provider:lower())` dispatch handles the rest automatically)

5. **Update documentation**:
   - `README.md` — mention the new provider in the features list.
   - `doc/git_open.txt` — add the provider to the `g:vim_git_open_providers`
     supported values list.

6. **Test thoroughly**:
   - Test all commands with the new provider.
   - Test with both SSH and HTTPS remote URLs.

## Version Parity

When making changes, ensure all three implementations have the same features:
- Legacy Vimscript (main version)
- Vim9script version
- Lua version

## Questions?

If you have questions about contributing, feel free to:
- Open an issue for discussion
- Check existing issues and PRs
- Reach out to the maintainer

## License

By contributing to vim-git-open, you agree that your contributions will be licensed under the MIT License.
