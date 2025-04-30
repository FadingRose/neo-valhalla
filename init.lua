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
  vnoremap <silent> w :call CustomW()<CR>
  vnoremap <silent> b :call CustomB()<CR>
]])
