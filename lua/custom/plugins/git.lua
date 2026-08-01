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

local function open_commit_history(line_range)
  local file = vim.api.nvim_buf_get_name(0)

  if file == '' then
    vim.notify('No file for current buffer', vim.log.levels.WARN)
    return
  end

  local root_lines, root_error = system_lines { 'git', '-C', vim.fs.dirname(file), 'rev-parse', '--show-toplevel' }

  if not root_lines then
    vim.notify('Could not find repository for current file: ' .. root_error, vim.log.levels.ERROR)
    return
  end

  local root = root_lines[1]
  local relative_file = vim.fs.relpath(root, file)
  local log_cmd = {
    'git',
    '-C',
    root,
    'log',
    '--no-patch',
    '--date=short',
    '--format=%H%x1f%h%x1f%ad%x1f%an%x1f%s',
  }

  if line_range then
    vim.list_extend(log_cmd, {
      '-L',
      string.format('%d,%d:%s', line_range.first, line_range.last, relative_file),
    })
  else
    vim.list_extend(log_cmd, { '--follow', '--', relative_file })
  end

  local lines, git_error = system_lines(log_cmd)

  if not lines then
    vim.notify('Could not read commit history: ' .. git_error, vim.log.levels.ERROR)
    return
  end

  local commits = vim
    .iter(lines)
    :map(function(line)
      local fields = vim.split(line, '\31', { plain = true })

      return {
        hash = fields[1],
        label = string.format('%s  %s  %s  %s', fields[2], fields[3], fields[4], fields[5]),
      }
    end)
    :totable()

  if vim.tbl_isempty(commits) then
    vim.notify('No commits found', vim.log.levels.INFO)
    return
  end

  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values
  local finders = require 'telescope.finders'
  local pickers = require 'telescope.pickers'
  local previewers = require 'telescope.previewers'
  local prompt_title = line_range
      and string.format('History for %s lines %d-%d', relative_file, line_range.first, line_range.last)
    or 'History for ' .. relative_file

  pickers
    .new({ cwd = root }, {
      prompt_title = prompt_title,
      finder = finders.new_table {
        results = commits,
        entry_maker = function(commit)
          return {
            value = commit.hash,
            display = commit.label,
            ordinal = commit.hash .. ' ' .. commit.label,
          }
        end,
      },
      previewer = previewers.git_commit_diff_to_parent.new {
        cwd = root,
        current_file = relative_file,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if not selection then
            return
          end

          require('neogit.lib.git.repository').instance(root)
          require('neogit.buffers.commit_view').new(selection.value):open 'vsplit'
        end)

        return true
      end,
    })
    :find()
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
      {
        '<leader>gh',
        open_commit_history,
        desc = 'Select from current file history',
      },
      {
        '<leader>gh',
        function()
          local first = vim.fn.line 'v'
          local last = vim.fn.line '.'

          open_commit_history {
            first = math.min(first, last),
            last = math.max(first, last),
          }
        end,
        mode = 'x',
        desc = 'Select from selected lines history',
      },
    },
  },
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    event = 'BufReadPost',
    opts = {
      default_mappings = false,
      disable_diagnostics = true,
    },
    keys = {
      { '<leader>gco', '<cmd>GitConflictChooseOurs<cr>', desc = 'Choose our conflict changes' },
      { '<leader>gct', '<cmd>GitConflictChooseTheirs<cr>', desc = 'Choose their conflict changes' },
      { '<leader>gcb', '<cmd>GitConflictChooseBoth<cr>', desc = 'Choose both conflict changes' },
      { '<leader>gc0', '<cmd>GitConflictChooseNone<cr>', desc = 'Choose neither conflict changes' },
      { '<leader>gcl', '<cmd>GitConflictListQf<cr>', desc = 'List Git conflicts' },
      { '[x', '<cmd>GitConflictPrevConflict<cr>', desc = 'Previous Git conflict' },
      { ']x', '<cmd>GitConflictNextConflict<cr>', desc = 'Next Git conflict' },
    },
  },
}
