return {
  'christoomey/vim-tmux-navigator',
  lazy = false,
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  config = function()
    local navigation_config = vim.fn.expand '~/Sandbox/vim-herdr-navigation/editor/nvim.lua'

    if vim.fn.filereadable(navigation_config) == 1 then
      dofile(navigation_config)
    else
      vim.notify('Herdr navigation config not found: ' .. navigation_config, vim.log.levels.WARN)
    end
  end,
}
