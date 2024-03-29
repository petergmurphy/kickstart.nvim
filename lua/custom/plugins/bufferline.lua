-- Buffer navigation controls

local builtin = require 'telescope.builtin'
vim.keymap.set('n', '<leader>bb', builtin.buffers, { desc = 'Find existing buffers' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<cr>', { silent = true, noremap = true })

vim.keymap.set('n', '<C-L>', '<cmd>bnext<cr>', { silent = true, noremap = true })
vim.keymap.set('n', '<C-H>', '<cmd>bprevious<cr>', { silent = true, noremap = true })

return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = function()
    require('bufferline').setup {
      options = {
        numbers = 'none',
        close_command = 'bdelete! %d', -- can be a string | function, see "Mouse actions"
        right_mouse_command = 'bdelete! %d', -- can be a string | function, see "Mouse actions"
        left_mouse_command = 'buffer %d', -- can be a string | function, see "Mouse actions"
        middle_mouse_command = nil, -- can be a string | function, see "Mouse actions"
        -- Other options
      },
    }
  end,
}
