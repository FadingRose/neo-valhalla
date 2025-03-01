-- ~/.config/nvim/lua/plugins/hop.lua
return {
  "phaazon/hop.nvim",
  branch = "v2", -- Use the v2 branch for the latest version
  config = function()
    require("hop").setup({
      keys = "qwertasdfgzxcvb",
      quit_key = "<Esc>",
    }) -- Initialize Hop with default settings
  end,
}
