local lspconfig = require("lspconfig")

lspconfig.pylsp.setup({
  filetypes = { "python", "vyper", "vy" }, -- 添加 'vy'
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          maxLineLength = 100,
        },
        yapf = {
          enabled = true,
        },
      },
    },
  },
})
