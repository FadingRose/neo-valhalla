local blockchain_explorers = require("custom_plugins.blockchain-explorers")

-- (可选) 如果你想自定义浏览器列表，可以在这里配置
-- blockchain_explorers.setup({ ... })

-- 2. 在 blink 的 sources 列表中注册我们的新源
-- require("blink").setup({
--   -- ... 你其他的 blink 配置 ...
--
--   sources = {
--     -- 确保你保留了其他想要的源，例如 lsp, buffer 等
--     { name = "lsp" },
--     { name = "buffer" },
--     { name = "snippets" },
--
--     {
--       name = "Blockchain", -- 给源起一个名字
--       -- `source` 字段是一个函数，blink 会在需要补全时调用它
--       -- 这个函数应该返回补全项列表或 nil
--       source = function()
--         -- 直接调用我们模块里为 blink 准备的函数
--         return blockchain_explorers.get_blink_completions()
--       end,
--     },
--   },
-- })
