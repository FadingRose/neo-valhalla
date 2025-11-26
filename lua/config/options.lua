-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      zen = {
        toggles = {
          dim = false,
          git_signs = true,
          mini_diff_signs = true,
          diagnostics = true,
          inlay_hints = true,
        },
        show = { statusline = false, tabline = false },
      },
      styles = {
        zen = {
          backdrop = { transparent = false },
        },
      },
    },
  },
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        manual_mode = false,
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      })
    end,
  },
}
