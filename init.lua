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
  pattern = "*.tx",
  callback = function()
    vim.opt_local.filetype = "tx"
    vim.bo.commentstring = "// %s"
  end,
  desc = "Set filetype for .tx files",
})

vim.diagnostic.config({
  virtual_lines = {
    current_line_only = true,
  },
})
