return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    keymap = {
      ["<CR>"] = { "select_and_accept", "fallback" },
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
    },
  },
}
