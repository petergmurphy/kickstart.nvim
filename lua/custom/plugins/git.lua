local function system_lines(cmd)
  local result = vim.system(cmd, { text = true }):wait()

  if result.code ~= 0 then
    local stderr = result.stderr or ''
    local stdout = result.stdout or ''
    return nil, vim.trim(stderr ~= '' and stderr or stdout)
  end

  return vim.split(result.stdout or '', '\n', { trimempty = true })
end

local function commit_url(remote, commit)
  remote = vim.trim(remote):gsub('%.git$', '')

  local host, path = remote:match '^git@([^:]+):(.+)$'
  if not host then
    host, path = remote:match '^ssh://git@([^/]+)/(.+)$'
  end

  if host and path then
    local separator = host:match 'gitlab' and '/-/commit/' or '/commit/'
    return string.format('https://%s/%s%s%s', host, path, separator, commit)
  end

  if remote:match '^https?://' then
    local separator = remote:match 'gitlab' and '/-/commit/' or '/commit/'
    return remote .. separator .. commit
  end
end

local function line_commit()
  local file = vim.api.nvim_buf_get_name(0)

  if file == '' then
    vim.notify('No file for current buffer', vim.log.levels.WARN)
    return
  end

  local cwd = vim.fs.dirname(file)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local blame_cmd = { 'git', '-C', cwd, 'blame', '--line-porcelain', '-L', line .. ',' .. line }
  local blame, blame_error = system_lines(vim.list_extend(vim.deepcopy(blame_cmd), { '--', file }))

  if not blame then
    vim.notify('Could not blame current line: ' .. blame_error, vim.log.levels.ERROR)
    return
  end

  local commit = blame[1] and blame[1]:match '^(%x+)'

  if commit and commit:match '^0+$' then
    blame, blame_error = system_lines(vim.list_extend(vim.deepcopy(blame_cmd), { 'HEAD', '--', file }))

    if not blame then
      vim.notify('Could not blame current line at HEAD: ' .. blame_error, vim.log.levels.ERROR)
      return
    end

    commit = blame[1] and blame[1]:match '^(%x+)'
  end

  if not commit or commit:match '^0+$' then
    vim.notify('Current line has no committed blame yet', vim.log.levels.WARN)
    return
  end

  return commit, cwd
end

local function open_line_commit()
  local commit, cwd = line_commit()

  if not commit then
    return
  end

  local remote, remote_error = system_lines { 'git', '-C', cwd, 'remote', 'get-url', 'origin' }

  if not remote then
    vim.notify('Could not read origin remote: ' .. remote_error, vim.log.levels.ERROR)
    return
  end

  local url = commit_url(remote[1], commit)

  if not url then
    vim.notify('Unsupported origin remote URL: ' .. remote[1], vim.log.levels.ERROR)
    return
  end

  vim.ui.open(url)
end

local function open_line_commit_split()
  local commit, cwd = line_commit()

  if not commit then
    return
  end

  require('neogit.lib.git.repository').instance(cwd)
  require('neogit.buffers.commit_view').new(commit):open 'vsplit'
end

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
        '<leader>go',
        open_line_commit_split,
        desc = 'Open current line commit in split',
      },
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
