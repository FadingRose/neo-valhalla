return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    keymap = {
      ["<CR>"] = { "select_and_accept", "fallback" },
      ["<S-w>"] = { "select_next", "fallback" },
      ["<S-q>"] = { "select_prev", "fallback" },
    },
  },
}
