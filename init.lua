-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
-- require("dap-go").setup()
vim.opt.signcolumn = "yes"

require("config.lsp")
