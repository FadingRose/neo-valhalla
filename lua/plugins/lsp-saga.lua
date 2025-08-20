return {
  "glepnir/lspsaga.nvim",
  config = function()
    require("lspsaga").setup({
      max_height = 0.6,
      left_width = 0.2,
      right_width = 0.5,
      layout = "float",
      finder = {
        keys = {
          shuttle = "[w", -- shuttle bettween the finder layout window
          toggle_or_open = "i", -- toggle expand or open
          vsplit = "<CR>", -- open in vsplit
          split = "s", -- open in split
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
