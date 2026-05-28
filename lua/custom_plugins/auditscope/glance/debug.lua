local tracker = require("custom_plugins.auditscope.glance.tracker")

local M = {}

local panel_buf = nil
local panel_win = nil
local refresh_timer = nil
local REFRESH_MS = 500

local function get_status_lines()
  local s = tracker.stats()
  local lines = {
    " AuditScope Glance Debug",
    string.rep("─", 36),
    string.format(" %-16s %s", "Tracking:", s.enabled and "ON" or "OFF"),
    string.format(" %-16s %s", "Paused:", s.paused and "YES" or "NO"),
    string.format(" %-16s %s", "Dirty:", s.dirty and "YES" or "NO"),
    "",
    string.format(" %-16s %s", "File:", s.current_file and vim.fn.fnamemodify(s.current_file, ":t") or "-"),
    string.format(" %-16s %s", "Line:", s.current_line and tostring(s.current_line) or "-"),
    string.format(" %-16s %.2fs", "Accumulated:", s.line_accumulated),
    string.format(" %-16s %.2fs", "Live elapsed:", s.current_elapsed),
    string.format(" %-16s %.2fs", "Line total:", s.line_accumulated + s.current_elapsed),
    "",
    string.format(" %-16s %d", "Buffer:", s.buffer_count),
    string.format(" %-16s %s", "Debounce:", s.debounce_active and "active" or "idle"),
    string.format(" %-16s %s", "Flush timer:", s.flush_active and "running" or "stopped"),
  }
  return lines
end

local function is_valid()
  return panel_buf and vim.api.nvim_buf_is_valid(panel_buf)
    and panel_win and vim.api.nvim_win_is_valid(panel_win)
end

local function refresh()
  if not is_valid() then
    M.close()
    return
  end
  local lines = get_status_lines()
  vim.api.nvim_buf_set_lines(panel_buf, 0, -1, false, lines)
end

local function start_refresh()
  if refresh_timer then
    refresh_timer:stop()
    if not refresh_timer:is_closing() then
      refresh_timer:close()
    end
  end
  refresh_timer = (vim.uv or vim.loop).new_timer()
  refresh_timer:start(REFRESH_MS, REFRESH_MS, function()
    vim.schedule(refresh)
  end)
end

local function stop_refresh()
  if refresh_timer then
    refresh_timer:stop()
    if not refresh_timer:is_closing() then
      refresh_timer:close()
    end
    refresh_timer = nil
  end
end

function M.open()
  if is_valid() then
    vim.api.nvim_set_current_win(panel_win)
    return
  end

  panel_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[panel_buf].buftype = "nofile"
  vim.bo[panel_buf].bufhidden = "wipe"
  vim.bo[panel_buf].filetype = "auditscope_debug"

  vim.cmd("botright 15split")
  panel_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(panel_win, panel_buf)
  vim.wo[panel_win].number = false
  vim.wo[panel_win].relativenumber = false
  vim.wo[panel_win].signcolumn = "no"
  vim.wo[panel_win].cursorline = false
  vim.wo[panel_win].winfixheight = true

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(panel_win),
    once = true,
    callback = function()
      stop_refresh()
      panel_buf = nil
      panel_win = nil
    end,
  })

  refresh()
  start_refresh()
end

function M.close()
  stop_refresh()
  if panel_win and vim.api.nvim_win_is_valid(panel_win) then
    vim.api.nvim_win_close(panel_win, true)
  end
  panel_buf = nil
  panel_win = nil
end

function M.toggle()
  if is_valid() then
    M.close()
  else
    M.open()
  end
end

return M
