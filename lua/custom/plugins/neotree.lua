vim.keymap.set('n', '<C-Z>', ':Neotree toggle<cr>', { desc = 'Open Neotree on left side' })

-- vim.keymap.set('n', '<leader>bt', ':Neotree float buffers<cr>', { desc = 'Show git status in Neotree' }) DIDNT SEEM TO WORK

vim.keymap.set('n', '<leader>gt', ':Neotree float git_status<cr>', { desc = 'Show git status in Neotree' })

return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
    -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
  },
  opts = {
    filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
  },
}
