-- lua/custom_plugins/auditscope/mind/init.lua
local M = {}

M.config = {
  file_path = ".audit_mind.json", -- 数据存储在项目根目录
  icons = {
    hypothesis = "❓",
    insight = "💡",
    fact = "📌",
    question = "🧐",
    supports = "✅",
    refutes = "❌",
    relates = "🔗",
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.db = require("custom_plugins.auditscope.mind.db")
  M.ui = require("custom_plugins.auditscope.mind.ui")
  M.sign = require("custom_plugins.auditscope.mind.sign")
  -- M.db.setup(M.config.file_path)
  M.sign.setup(M.config)
  M.ui.setup(M.config)

  -- 自动加载当前文件的 signs
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    callback = function()
      M.sign.refresh()
    end,
  })

  M.create_mind = M.db.CreateMind
  M.new_node = M.ui.create_node
  M.open_dashboard = M.ui.toggle_dashboard
  M.add_link = M.ui.link_node

  vim.api.nvim_create_user_command("AuditCreateMind", function()
    M.db.CreateMind()
    M.sign.refresh() -- DB 就绪后，尝试刷新当前 Buffer 的标记
  end, { desc = "Initialize AuditMind session for current git commit" })
end

return M
