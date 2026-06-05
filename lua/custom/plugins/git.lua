return {
  {
    'tpope/vim-fugitive',
    keys = {
      { '<leader>gs', '<cmd>G<cr>', desc = 'Open git status' },
      { '<leader>gd', '<cmd>Gvdiffsplit<cr>', desc = 'Open git diff split vertically' },
    },
  },
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    cmd = 'Neogit',
    opts = {},
    config = function(_, opts)
      require('neogit').setup(opts)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'NeogitLogView',
        callback = function(event)
          vim.keymap.set('n', '?', function()
            local commit = require('neogit.buffers.log_view').instance.buffer.ui:get_commit_under_cursor()

            require('neogit.popups.help').create {
              branch = {},
              cherry_pick = { commits = commit and { commit } or {} },
              commit = { commit = commit },
              diff = { section = { name = 'log' }, item = { name = commit } },
              merge = { commit = commit },
              push = { commit = commit },
              rebase = { commit = commit },
              reset = { commit = commit },
              revert = { commits = commit and { commit } or {} },
              tag = { commit = commit },
            }
          end, { buffer = event.buf, desc = 'Open Neogit help' })
        end,
      })
    end,
    keys = {
      { '<leader>gn', '<cmd>Neogit<cr>', desc = 'Open Neogit' },
      {
        '<leader>gl',
        function()
          local popup = require('neogit.popups.log').create()
          popup:close()
          require('neogit.popups.log.actions').log_current(popup)
        end,
        desc = 'Open git commit log',
      },
    },
  },
}
