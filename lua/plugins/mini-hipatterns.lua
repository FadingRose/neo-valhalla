return {
  "echasnovski/mini.hipatterns",
  event = "BufReadPre",
  config = function()
    -- `highlighters` 是一个表，其中键是模式（正则表达式），
    -- 值是高亮组的名称（例如 'Search'）。
    -- 我们将动态地填充这个表。
    local hipatterns = require("mini.hipatterns")
    hipatterns.setup({
      highlighters = {}, -- 初始为空
    })

    -- 高亮光标下的单词
    -- 多次调用会使用不同的颜色高亮不同的单词
    vim.keymap.set("n", "<leader>h", function()
      local word = vim.fn.expand("<cword>")
      hipatterns.add(word)
    end, { desc = "Highlight word under cursor" })

    -- 移除光标下单词的高亮
    vim.keymap.set("n", "<leader>hc", function()
      local word = vim.fn.expand("<cword>")
      hipatterns.remove(word)
    end, { desc = "Remove highlight for word under cursor" })

    -- 清除所有由 mini.hipatterns 添加的高亮
    vim.keymap.set("n", "<leader>H", function()
      hipatterns.clear()
    end, { desc = "Clear all highlights" })
  end,
}
