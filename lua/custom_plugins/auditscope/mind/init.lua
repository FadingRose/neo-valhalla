-- lua/custom_plugins/auditscope/mind/init.lua
local M = {}

M.config = {
  icons = {
    hypothesis = "❓",
    insight = "💡",
    fact = "📌",
    question = "🧐",
    finding = "🧭",
    decision = "🧷",
    evidence = "🔍",
    risk = "⚠️",
    note = "🗒️",
    assumption = "🧩",
    invariant = "🧱",
    supports = "✅",
    refutes = "❌",
    relates = "🔗",
  },
  llm = {
    provider = "openrouter",
    model = "google/gemini-3-flash-preview",
    max_candidates = 40,
    max_links = 3,
    min_confidence = 0.35,
    timeout_ms = 30000,
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.db = require("custom_plugins.auditscope.mind.db")
  M.ui = require("custom_plugins.auditscope.mind.ui")
  M.sign = require("custom_plugins.auditscope.mind.sign")
  M.report = require("custom_plugins.auditscope.mind.report")
  M.auto_link = require("custom_plugins.auditscope.mind.auto_link")
  M.subject_picker = require("custom_plugins.auditscope.mind.subject_picker")
  M.db.init()
  M.db.TryLoadMind()
  M.auto_link.setup(M.config)
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
  M.select_subject = M.db.select_subject
  M.select_commit = M.db.try_select_mind
  M.increment_glance = M.ui.increment_glance
  M.decrement_glance = M.ui.decrement_glance

  vim.api.nvim_create_user_command("AuditCreateMind", function()
    M.db.CreateMind()
    M.sign.refresh() -- DB 就绪后，尝试刷新当前 Buffer 的标记
  end, { desc = "Create a new audit subject (compat)" })

  vim.api.nvim_create_user_command("AuditSubjectNew", function(args)
    local title = args.args ~= "" and args.args or nil
    M.db.CreateMind({ title = title })
    M.sign.refresh()
  end, { nargs = "?", desc = "Create a new audit subject" })

  vim.api.nvim_create_user_command("AuditSubjectSelect", function()
    M.subject_picker.select_subject()
  end, { desc = "Select active audit subject" })

  vim.api.nvim_create_user_command("AuditSubjectDelete", function(args)
    local subject_id = args.args ~= "" and args.args or nil
    if subject_id then
      M.db.delete_subject(subject_id)
    else
      M.subject_picker.delete_subject()
    end
  end, { nargs = "?", desc = "Delete an audit subject" })

  vim.api.nvim_create_user_command("AuditGenerateReport", function()
    M.report.generate({ open = true })
  end, { desc = "Generate and open executive report for active subject" })

  vim.api.nvim_create_user_command("AuditSummary", function()
    local subject = M.db.get_subject()
    if not subject then
      vim.notify("AuditScope: No active subject. Use :AuditSubjectNew or :AuditSubjectSelect.", vim.log.levels.ERROR)
      return
    end

    vim.ui.input({
      prompt = "Executive summary:",
      default = subject.summary or "",
    }, function(value)
      if value == nil then
        return
      end
      M.db.set_summary(value)
      vim.notify("AuditScope: Summary updated.", vim.log.levels.INFO)
    end)
  end, { desc = "Set executive summary for active subject" })

  vim.api.nvim_create_user_command("AuditSummaryClear", function()
    local subject = M.db.get_subject()
    if not subject then
      vim.notify("AuditScope: No active subject. Use :AuditSubjectNew or :AuditSubjectSelect.", vim.log.levels.ERROR)
      return
    end

    vim.ui.input({
      prompt = "Type CLEAR to remove executive summary: ",
    }, function(confirm)
      if confirm ~= "CLEAR" then
        return
      end
      M.db.set_summary("")
      vim.notify("AuditScope: Summary cleared.", vim.log.levels.INFO)
    end)
  end, { desc = "Clear executive summary for active subject" })

  vim.api.nvim_create_user_command("AuditAutoLink", function(args)
    local source_id = args.args ~= "" and args.args or nil
    M.auto_link.auto_link({ source_id = source_id })
  end, { nargs = "?", desc = "Auto-link a node using OpenRouter" })

  vim.api.nvim_create_user_command("AuditNote", function(args)
    local note_type = args.args ~= "" and args.args or nil
    local low_level = { "note", "evidence", "insight", "assumption", "invariant", "question", "hypothesis", "fact" }
    local high_level = { "finding", "decision", "risk" }

    if note_type then
      if note_type == "low" then
        vim.ui.select(low_level, { prompt = "Low-level note type:" }, function(choice)
          if choice then
            M.ui.create_node(choice, { input = "split" })
          end
        end)
        return
      end
      if note_type == "high" then
        vim.ui.select(high_level, { prompt = "High-level note type:" }, function(choice)
          if choice then
            M.ui.create_node(choice, { input = "split" })
          end
        end)
        return
      end

      M.ui.create_node(note_type, { input = "split" })
      return
    end

    vim.ui.select(low_level, { prompt = "Note type:" }, function(choice)
      if choice then
        M.ui.create_node(choice, { input = "split" })
      end
    end)
  end, { nargs = "?", desc = "Create a note for the active subject" })
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

  M.clean_glance = M.ui.clean_glance
  vim.api.nvim_create_user_command("AuditCleanGlance", function()
    M.ui.clean_glance()
  end, { desc = "Reset glance counts for all nodes" })

  M.toggle_show_glance = M.ui.toggle_show_glance
  vim.api.nvim_create_user_command("AuditToggleShowGlance", function()
    M.ui.toggle_show_glance()
  end, { desc = "Toggle display of glance traces" })

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
