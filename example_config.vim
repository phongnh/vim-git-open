" =============================================================================
" Example configuration for vim-git-open
" =============================================================================
" Add this to your .vimrc or init.vim

" -----------------------------------------------------------------------------
" Basic Configuration
" -----------------------------------------------------------------------------

" Set custom browser command (optional, auto-detected by default)
" macOS:
" let g:vim_git_open_browser_command = 'open'
" Linux:
" let g:vim_git_open_browser_command = 'xdg-open'
" Linux with specific browser:
" let g:vim_git_open_browser_command = 'firefox'
" let g:vim_git_open_browser_command = 'google-chrome'
" Windows:
" let g:vim_git_open_browser_command = 'start'

" -----------------------------------------------------------------------------
" Enterprise / Self-Hosted Git Configuration
" -----------------------------------------------------------------------------

" Map custom git domains to their web URLs
let g:vim_git_open_domains = {
            \ 'git.company.com': 'https://github.company.com',
            \ 'gitlab.internal': 'https://gitlab.internal.com',
            \ 'code.example.org': 'https://code.example.org',
            \ }

" Specify provider type for custom domains
let g:vim_git_open_providers = {
            \ 'git.company.com': 'GitHub',
            \ 'gitlab.internal': 'GitLab',
            \ 'code.example.org': 'Codeberg',
            \ }

" -----------------------------------------------------------------------------
" Keymaps (Recommended)
" -----------------------------------------------------------------------------

" Open repository home
nnoremap <leader>go :OpenGitRepo<CR>

" Open current branch
nnoremap <leader>gb :OpenGitBranch<CR>

" Open current file (normal mode: current line, visual mode: line range)
nnoremap <leader>gf :OpenGitFile<CR>
vnoremap <leader>gf :OpenGitFile<CR>

" Open current commit
nnoremap <leader>gc :OpenGitCommit<CR>

" Open PR/MR
nnoremap <leader>gp :OpenGitPR<CR>
nnoremap <leader>gm :OpenGitMR<CR>

" Alternative keymaps with git prefix
" nnoremap <leader>gor :OpenGitRepo<CR>
" nnoremap <leader>gob :OpenGitBranch<CR>
" nnoremap <leader>gof :OpenGitFile<CR>
" nnoremap <leader>goc :OpenGitCommit<CR>
" nnoremap <leader>gop :OpenGitPR<CR>
" nnoremap <leader>gom :OpenGitMR<CR>

" -----------------------------------------------------------------------------
" Lua Configuration (Neovim only)
" -----------------------------------------------------------------------------
" If using the Lua version, add this to your init.lua:

" lua << EOF
" require('git_open').setup({
"   -- Custom domain mappings
"   domains = {
"     ['git.company.com'] = 'https://github.company.com',
"     ['gitlab.internal'] = 'https://gitlab.internal.com',
"   },
"   
"   -- Provider detection
"   providers = {
"     ['git.company.com'] = 'GitHub',
"     ['gitlab.internal'] = 'GitLab',
"   },
"   
"   -- Browser command (optional)
"   browser_command = 'open',
" })
" 
" -- Keymaps
" vim.keymap.set('n', '<leader>go', '<cmd>OpenGitRepo<CR>', { desc = 'Open Git Repo' })
" vim.keymap.set('n', '<leader>gb', '<cmd>OpenGitBranch<CR>', { desc = 'Open Git Branch' })
" vim.keymap.set('n', '<leader>gf', '<cmd>OpenGitFile<CR>', { desc = 'Open Git File' })
" vim.keymap.set('v', '<leader>gf', '<cmd>OpenGitFile<CR>', { desc = 'Open Git File (range)' })
" vim.keymap.set('n', '<leader>gc', '<cmd>OpenGitCommit<CR>', { desc = 'Open Git Commit' })
" vim.keymap.set('n', '<leader>gp', '<cmd>OpenGitPR<CR>', { desc = 'Open Git PR' })
" vim.keymap.set('n', '<leader>gm', '<cmd>OpenGitMR<CR>', { desc = 'Open Git MR' })
" EOF
