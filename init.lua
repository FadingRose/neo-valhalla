-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
-- require("dap-go").setup()
vim.opt.signcolumn = "yes"

require("config.lsp")

-- now the w and b only move cursor at the same line
vim.cmd([[
  function! CustomW()
    let start_line = line('.')
    normal! w
    if line('.') != start_line
      execute start_line . 'normal! $'
    endif
  endfunction

  function! CustomB()
    let start_line = line('.')
    normal! b
    if line('.') != start_line
      execute start_line . 'normal! ^'
    endif
  endfunction

  nnoremap <silent> w :call CustomW()<CR>
  nnoremap <silent> b :call CustomB()<CR>
]])

--- set filetype for .tx files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.trace", "*.txlog", "*.tx" }, -- 你希望关联的文件后缀名
  callback = function()
    vim.bo.filetype = "tx"
    vim.bo.commentstring = "# %s"
  end,
  desc = "Set filetype to tx for transaction trace logs",
})

--- set up tree-sitter for .tx files
local parsers_config = require("nvim-treesitter.parsers").get_parser_configs()
parsers_config.tx = {
  install_info = {
    url = "~/tree-sitter-tx-trace",
    files = { "src/parser.c" },
    generate_requires_npm = false,
    requires_generate_from_grammar = false,
  },
  filetype = "tx",
}

require("nvim-treesitter.configs").setup({
  ensure_installed = { "tx" },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
