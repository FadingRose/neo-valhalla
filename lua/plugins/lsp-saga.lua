return {
  "glepnir/lspsaga.nvim",
  config = function()
    require("lspsaga").setup({
      finder = {
        keys = {
          shuttle = "[w", -- shuttle bettween the finder layout window
          toggle_or_open = "<CR>", -- toggle expand or open
          vsplit = "s", -- open in vsplit
          split = "i", -- open in split
          tabe = "t", -- open in tabe
          tabnew = "r", -- open in new tab
          quit = "q", -- quit the finder, only works in layout left window
          close = "<C-c>k", -- close finder
        },
      },
      ui = {
        code_action = "",
      },
    })
  end,
}
