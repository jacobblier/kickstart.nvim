-- Custom LSP Configurations
-- These configurations override or supplement the automatic Mason setup

-- TypeScript/JavaScript Language Server (ts_ls)
-- Custom root_dir to work with projects that have package.json in subdirectories
require('lspconfig').ts_ls.setup {
  capabilities = require('blink.cmp').get_lsp_capabilities(),
  root_dir = function(fname)
    local util = require('lspconfig').util
    return util.root_pattern('package.json', 'tsconfig.json', 'jsconfig.json')(fname) or util.root_pattern '.git'(fname) or vim.fs.dirname(fname)
  end,
}
