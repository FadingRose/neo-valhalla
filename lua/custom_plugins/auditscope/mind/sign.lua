-- lua/custom_plugins/auditscope/mind/signs.lua
local db = require("custom_plugins.auditscope.mind.db")
local M = {}
local NAMESPACE = vim.api.nvim_create_namespace("AuditMindSigns")
local config = {}

function M.setup(cfg)
  config = cfg
  -- 定义 Sign Highlights
  vim.cmd([[highlight AuditHypothesis guifg=#E06C75 guibg=NONE]])
  vim.cmd([[highlight AuditFact guifg=#98C379 guibg=NONE]])

  -- 定义 Signs
  vim.fn.sign_define("AuditHypothesis", { text = config.icons.hypothesis, texthl = "AuditHypothesis" })
  vim.fn.sign_define("AuditFact", { text = config.icons.fact, texthl = "AuditFact" })
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_file = vim.fn.expand("%:p")
  local nodes = db.get_nodes()

  -- 清除当前 Buffer 的所有 extmarks/signs
  vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)

  -- 简单的 Sign Placement 逻辑 (建议使用 extmarks 因为它随代码移动更稳定)
  for _, node in ipairs(nodes) do
    if node.file == current_file then
      -- Virtual Text
      vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, node.line - 1, 0, {
        virt_text = { { string.format(" %s %s", config.icons[node.type], node.text), "Comment" } },
        virt_text_pos = "eol",
      })

      -- Gutter Sign (可选，如果不想太杂乱)
      -- local sign_name = node.type == "hypothesis" and "AuditHypothesis" or "AuditFact"
      -- vim.fn.sign_place(0, "AuditMindGroup", sign_name, bufnr, { lnum = node.line, priority = 10 })
    end
  end
end

return M
