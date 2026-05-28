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
    "ankushbhagats/pastel.nvim",
    lazy = false, -- disable lazy loading
    priority = 1000, -- load immediately at startup
    opts = {}, -- your configuration comes here
    config = true, -- call setup function with provided opts
  },
  { "savq/melange-nvim" },
}
