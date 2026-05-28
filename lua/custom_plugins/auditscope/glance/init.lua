local tracker = require("custom_plugins.auditscope.glance.tracker")
local render = require("custom_plugins.auditscope.glance.render")
local debug_panel = require("custom_plugins.auditscope.glance.debug")

local M = {}

M.config = {
  auto_track = true,
  show_glance = false,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.auto_track then
    tracker.enable()
  end

  if M.config.show_glance then
    render.show()
  end

  local group = vim.api.nvim_create_augroup("AuditScopeGlanceUI", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    callback = function()
      if render.is_visible() then
        render.refresh_cache()
        render.render_current()
      end
    end,
  })

  vim.api.nvim_create_user_command("AuditGlanceToggle", function()
    tracker.toggle()
  end, { desc = "Toggle glance tracking on/off" })

  vim.api.nvim_create_user_command("AuditGlanceShow", function()
    render.show()
  end, { desc = "Show glance heatmap bars" })

  vim.api.nvim_create_user_command("AuditGlanceHide", function()
    render.hide()
  end, { desc = "Hide glance heatmap bars" })

  vim.api.nvim_create_user_command("AuditGlanceToggleBars", function()
    render.toggle()
  end, { desc = "Toggle glance heatmap bars visibility" })

  vim.api.nvim_create_user_command("AuditGlanceFlush", function()
    tracker.flush_now()
    render.refresh_cache()
    render.render_current()
  end, { desc = "Flush glance buffer and refresh display" })

  vim.api.nvim_create_user_command("AuditGlanceSummary", function()
    tracker.flush_now()
    render.show_repo_summary()
  end, { desc = "Show glance summary for current repo" })

  vim.api.nvim_create_user_command("AuditGlanceClear", function()
    local store = require("custom_plugins.auditscope.glance.store")
    local file = vim.fn.expand("%:p")
    if file ~= "" then
      store.clear(file)
      render.refresh_cache(file)
      render.render_current()
      vim.notify("AuditScope: glance data cleared for current file", vim.log.levels.INFO)
    end
  end, { desc = "Clear glance data for current file" })

  vim.api.nvim_create_user_command("AuditGlanceDebug", function()
    debug_panel.toggle()
  end, { desc = "Toggle glance debug panel" })
end

M.toggle_tracking = tracker.toggle
M.toggle_bars = render.toggle
M.show_bars = render.show
M.hide_bars = render.hide
M.flush = tracker.flush_now
M.summary = render.show_repo_summary
M.debug = debug_panel.toggle

return M
