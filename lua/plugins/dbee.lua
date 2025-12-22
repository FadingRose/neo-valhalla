return {
  "kndndrj/nvim-dbee",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  build = function()
    require("dbee").install()
  end,
  config = function()
    require("dbee").setup({
      require("dbee.sources").MemorySource:new({
        {
          id = "database",
          name = "database",
          type = "sqlite3",
          url = vim.fn.expand("~/database.db"),
        },
      }),
    })
  end,
}
