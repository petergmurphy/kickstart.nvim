vim.keymap.set('n', '<leader>gs', ':G<cr>', { desc = 'Open git status' })

vim.keymap.set('n', '<leader>gd', ':Gvdiffsplit<cr>', { desc = 'Open git diff split veritically' })

return {
  'tpope/vim-fugitive',
}
