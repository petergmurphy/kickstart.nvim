package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local symbol_kinds = require 'custom.lsp_symbols'

local function assert_equal(expected, actual, message)
  if expected ~= actual then
    error(('%s: expected %q, got %q'):format(message, expected, actual))
  end
end

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, '/tmp/telescope-symbol-search.ts')
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'export type SearchableAlias = { value: string }',
  'export const SearchableValue = 1',
  'export interface SearchableInterface { value: string }',
})

local function symbol(name, kind, line)
  return {
    name = name,
    kind = kind,
    location = {
      uri = vim.uri_from_bufnr(bufnr),
      range = {
        start = { line = line, character = 0 },
        ['end'] = { line = line, character = 1 },
      },
    },
  }
end

local raw_symbols = {
  symbol('SearchableAlias', vim.lsp.protocol.SymbolKind.Variable, 0),
  symbol('SearchableValue', vim.lsp.protocol.SymbolKind.Constant, 1),
  symbol('SearchableInterface', vim.lsp.protocol.SymbolKind.Interface, 2),
}
local items = {
  { kind = 'Variable', text = '[Variable] SearchableAlias' },
  { kind = 'Constant', text = '[Constant] SearchableValue' },
  { kind = 'Interface', text = '[Interface] SearchableInterface' },
}

symbol_kinds.normalize_typescript_type_aliases(raw_symbols, items)

assert_equal('TypeAlias', items[1].kind, 'TypeScript type alias kind')
assert_equal('[TypeAlias] SearchableAlias', items[1].text, 'TypeScript type alias label')
assert_equal('Constant', items[2].kind, 'ordinary TypeScript value kind')
assert_equal('Interface', items[3].kind, 'TypeScript interface kind')

print 'lsp_symbols_spec: ok'
