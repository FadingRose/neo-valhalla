return {
  "nyoom-engineering/oxocarbon.nvim",
  -- Add in any other configuration;
  --   event = foo,
  --   config = bar
  "EdenEast/nightfox.nvim",
  "olivercederborg/poimandres.nvim",
  "kdheepak/monochrome.nvim",
  "Yazeed1s/oh-lucy.nvim",
  { "ellisonleao/gruvbox.nvim", priority = 1000, config = true, opts = ... },
  { "rose-pine/neovim", name = "rose-pine" },
  { "Mofiqul/vscode.nvim" },
  { "projekt0n/github-nvim-theme", name = "github-theme" },
  {
    "embark-theme/vim",
    lazy = false,
    priority = 1000,
    name = "embark",
    config = function()
      vim.cmd.colorscheme("embark")
    end,
  },
}
