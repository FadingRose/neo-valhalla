return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_config = {
            horizontal = { preview_width = 0.7 },
            vertical = { preview_height = 0.7 },
          },
        },
      })
    end,
  },
}
