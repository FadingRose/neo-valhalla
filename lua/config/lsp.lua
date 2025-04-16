local lspconfig = require("lspconfig")
local configs = require("lspconfig.configs")

-- manully introduce solidity-language-server
-- npm install @nomicfoundation/solidity-language-server -g
configs.solidity = {
  default_config = {
    cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
    filetypes = { "solidity" },
    root_dir = lspconfig.util.find_git_ancestor,
    single_file_support = true,
  },
}

lspconfig.solidity.setup({})
