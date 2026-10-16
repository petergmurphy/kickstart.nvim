local M = {}

local function declaration_text(symbol)
  local location = symbol.location
  local range = location and location.range
  local uri = location and location.uri
  if not (range and uri) then
    return nil
  end

  local filename = vim.uri_to_fname(uri)
  if not filename:match '%.([cm]?tsx?)$' then
    return nil
  end

  local start_line = range.start.line
  local end_line = range['end'].line
  local bufnr = vim.fn.bufnr(filename)
  local lines

  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  else
    local ok, file_lines = pcall(vim.fn.readfile, filename, '', end_line + 1)
    if not ok then
      return nil
    end

    lines = {}
    for line_number = start_line + 1, end_line + 1 do
      lines[#lines + 1] = file_lines[line_number]
    end
  end

  return table.concat(lines, ' ')
end

-- typescript-language-server reports type aliases as LSP Variables. Relabel
-- only declarations whose source range actually starts with `type Name`, so
-- ordinary variables do not leak into Telescope's class/type picker.
function M.normalize_typescript_type_aliases(symbols, items)
  for index, symbol in ipairs(symbols) do
    if symbol.kind == vim.lsp.protocol.SymbolKind.Variable then
      local declaration = declaration_text(symbol)
      local type_alias_pattern = '%f[%a]type%s+' .. vim.pesc(symbol.name) .. '%f[^%w_$]'

      local item = items[index]
      if item and declaration and declaration:match(type_alias_pattern) then
        item.kind = 'TypeAlias'
        item.text = item.text:gsub('^%[[^]]+%]', '[TypeAlias]', 1)
      end
    end
  end

  return items
end

return M
