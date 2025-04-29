return {
  "mistricky/codesnap.nvim",
  build = "make",
  keys = {
    {
      "<leader>cx",
      "<cmd>CodeSnap<cr>",
      mode = { "n", "v" },
      desc = "Screenshot",
    },
    {
      "<leader>cX",
      "<cmd>CodeSnapHighlight<cr>",
      mode = { "n", "v" },
      desc = "Screenshot with Highlight",
    },
  },
  opts = {
    bg_padding = 0,
    has_line_number = true,
    mac_window_bar = false,
    code_font_family = "Maple Mono NF CN",
  },
}
