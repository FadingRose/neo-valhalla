local M = {}

-- Vault directory

M.vault_dir = vim.fn.expand("$HOME") .. "/.vault"

function N.setup(opts)
  -- Load maid-vault plugin
  require("maid-vault").setup({
    vault_dir = M.vault_dir,
    -- Additional configuration options can be added here
  })

  if opts and opts.vault_dir then
    M.vault_dir = opts.vault_dir
  end

  -- Ensure the vault directory exists
  if not vim.loop.fs_stat(M.vault_dir) then
    vim.fn.mkdir(M.vault_dir, "p")
  end
end

function M.find_files() end
