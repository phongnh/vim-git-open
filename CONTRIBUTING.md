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
  - Use lowercase with underscores for function names
  - Prefix script-local functions with `s:`
  - Use `abort` on functions
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

To add a new Git provider:

1. **Implement URL builder function**:
   - Legacy Vimscript: `s:build_PROVIDER_url()` in `autoload/git_open.vim`
   - Vim9script: `BuildPROVIDERUrl()` in `vim9/autoload/git_open.vim`
   - Lua: `build_PROVIDER_url()` in `lua/git_open.lua`

2. **Add provider detection**:
   - Update the `detect_provider()` / `DetectProvider()` function

3. **Update URL builder dispatcher**:
   - Update the `build_url()` / `BuildUrl()` function

4. **Update documentation**:
   - README.md
   - doc/git_open.txt

5. **Test thoroughly**:
   - Test all commands with the new provider
   - Test with both SSH and HTTPS URLs

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
