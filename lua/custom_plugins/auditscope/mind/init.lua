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
  M.delete_node = function()
    M.ui.delete_node()
    M.sign.refresh()
  end
  M.modify_node = function()
    M.ui.modify_node()
    M.sign.refresh()
  end
  M.set_commit = M.db.set_commit
  M.unlock_commit = M.db.unlock_commit
  M.pin_node = M.ui.pin_node
  M.unpin_node = M.ui.unpin_node
  M.toggle_pin = M.ui.toggle_pin
  M.select_commit = M.db.try_select_mind
  M.increment_glance = M.ui.increment_glance
  M.decrement_glance = M.ui.decrement_glance

  vim.api.nvim_create_user_command("AuditCreateMind", function()
    M.db.CreateMind()
    M.sign.refresh() -- DB 就绪后，尝试刷新当前 Buffer 的标记
  end, { desc = "Initialize AuditMind session for current git commit" })
  vim.api.nvim_create_user_command("AuditLockCommit", function(args)
    local commit = args.args ~= "" and args.args or nil
    M.db.set_commit(commit)
  end, { nargs = "?", desc = "Lock AuditMind to a specific commit" })

  vim.api.nvim_create_user_command("AuditUnlockCommit", function()
    M.db.unlock_commit()
  end, { desc = "Unlock AuditMind commit" })

  vim.api.nvim_create_user_command("AuditPin", function()
    M.ui.pin_node()
  end, { desc = "Pin a question or hypothesis" })

  vim.api.nvim_create_user_command("AuditUnpin", function()
    M.ui.unpin_node()
  end, { desc = "Unpin the current pinned node" })

  vim.api.nvim_create_user_command("AuditToggleTrace", function()
    M.ui.toggle_auto_trace()
  end, { desc = "Toggle auto trace for glance counting" })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    callback = function()
      local filetype = vim.bo.filetype
      if filetype == "solidity" or filetype == "rust" then
        local success = M.db.TryLoadMind()
        if success then
          M.sign.refresh()
          print("[AuditMind] Loaded mind for current file.")
        end
      end
    end,
  })
end

return M
