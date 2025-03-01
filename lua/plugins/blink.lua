return {
  "saghen/blink.cmp",
  -- add fittencode.nvim to dependencies
  dependencies = {
    { "luozhiya/fittencode.nvim" },
  },
  opts = {
    -- add fittencode to sources
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "fittencode" },
      --   enabled_providers = { "lsp", "path", "snippets", "buffer", "fittencode" },
      -- },

      -- set custom providers with fittencode
      providers = {
        fittencode = {
          name = "fittencode",
          module = "fittencode.sources.blink",
        },
      },
    },
  },
}
