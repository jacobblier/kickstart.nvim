-- Custom LSP Configurations
-- These configurations override or supplement the automatic Mason setup

-- TypeScript/JavaScript Language Server (ts_ls)
-- Custom LSP Configurations
vim.lsp.config('ts_ls', {
  capabilities = require('blink.cmp').get_lsp_capabilities(),
  root_dir = function(fname)
    return vim.fs.root(fname, { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' }) or vim.fs.dirname(fname)
  end,
})

vim.lsp.enable 'ts_ls'
