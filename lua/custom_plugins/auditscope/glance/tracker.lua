local uv = vim.uv or vim.loop
local store = require("custom_plugins.auditscope.glance.store")

local M = {}

local DEBOUNCE_MS = 300
local FLUSH_INTERVAL_S = 10
local MAX_LINE_SECONDS = 30

local debounce_timer = nil
local flush_timer = nil
local current_file = nil
local current_line = nil
local settled_at = nil
local line_accumulated = 0
local buffer = {}
local enabled = false
local last_pos_key = nil
local paused = false
local dirty = false

local function flush()
  if #buffer == 0 then
    return
  end
  local by_file = {}
  for _, rec in ipairs(buffer) do
    if not by_file[rec.file] then
      by_file[rec.file] = {}
    end
    table.insert(by_file[rec.file], rec)
  end
  buffer = {}
  dirty = false
  for file, records in pairs(by_file) do
    store.append(file, records)
  end
end

local function emit_line()
  if not current_file or not current_line then
    return
  end
  if line_accumulated < 0.05 then
    return
  end

  table.insert(buffer, {
    file = current_file,
    line = current_line,
    seconds = line_accumulated,
    ts = os.time(),
  })
  line_accumulated = 0
  dirty = true
end

local function accumulate_line()
  if not current_file or not current_line or not settled_at or paused then
    return
  end

  local now = uv.hrtime() / 1e9
  local elapsed = now - settled_at

  if elapsed <= 0.05 then
    return
  end

  elapsed = math.min(elapsed, MAX_LINE_SECONDS - line_accumulated)
  if elapsed <= 0 then
    return
  end

  line_accumulated = line_accumulated + elapsed
  settled_at = now

  if line_accumulated >= MAX_LINE_SECONDS then
    emit_line()
  end
end

local function on_cursor_moved()
  if not enabled then
    return
  end

  local file = vim.fn.expand("%:p")
  if file == "" then
    return
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local key = file .. ":" .. tostring(line)

  if key == last_pos_key then
    return
  end

  accumulate_line()
  emit_line()

  current_file = file
  current_line = line
  settled_at = uv.hrtime() / 1e9
  line_accumulated = 0
  last_pos_key = key
  paused = false
end

local function on_buf_leave()
  accumulate_line()
  emit_line()
  current_file = nil
  current_line = nil
  settled_at = nil
  line_accumulated = 0
  last_pos_key = nil
  if dirty then
    flush()
  end
end

local function on_focus_lost()
  if not enabled or paused then
    return
  end
  accumulate_line()
  paused = true
end

local function on_focus_gained()
  if not enabled then
    return
  end
  paused = false
  if current_file and current_line then
    settled_at = uv.hrtime() / 1e9
  end
end

local function stop_debounce()
  if debounce_timer then
    debounce_timer:stop()
    if not debounce_timer:is_closing() then
      debounce_timer:close()
    end
    debounce_timer = nil
  end
end

local function stop_flush()
  if flush_timer then
    flush_timer:stop()
    if not flush_timer:is_closing() then
      flush_timer:close()
    end
    flush_timer = nil
  end
end

local function start_flush_timer()
  stop_flush()
  flush_timer = uv.new_timer()
  flush_timer:start(FLUSH_INTERVAL_S * 1000, FLUSH_INTERVAL_S * 1000, function()
    vim.schedule(function()
      if not paused then
        accumulate_line()
      end
      if dirty then
        flush()
      end
    end)
  end)
end

function M.enable()
  if enabled then
    return
  end
  enabled = true
  paused = false
  dirty = false

  local group = vim.api.nvim_create_augroup("AuditScopeGlance", { clear = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = function()
      stop_debounce()
      debounce_timer = uv.new_timer()
      debounce_timer:start(DEBOUNCE_MS, 0, function()
        stop_debounce()
        vim.schedule(on_cursor_moved)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    callback = on_buf_leave,
  })

  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = on_focus_lost,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = on_focus_gained,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      accumulate_line()
      emit_line()
      flush()
      stop_debounce()
      stop_flush()
    end,
  })

  current_file = vim.fn.expand("%:p")
  if current_file ~= "" then
    current_line = vim.api.nvim_win_get_cursor(0)[1]
    settled_at = uv.hrtime() / 1e9
    last_pos_key = current_file .. ":" .. tostring(current_line)
  end

  start_flush_timer()
end

function M.disable()
  if not enabled then
    return
  end
  enabled = false
  accumulate_line()
  emit_line()
  flush()
  vim.api.nvim_del_augroup_by_name("AuditScopeGlance")
  stop_debounce()
  stop_flush()
  current_file = nil
  current_line = nil
  settled_at = nil
  line_accumulated = 0
  last_pos_key = nil
  paused = false
  dirty = false
end

function M.toggle()
  if enabled then
    M.disable()
    vim.notify("AuditScope Glance: OFF", vim.log.levels.INFO)
  else
    M.enable()
    vim.notify("AuditScope Glance: ON", vim.log.levels.INFO)
  end
end

function M.is_enabled()
  return enabled
end

function M.flush_now()
  if not paused then
    accumulate_line()
  end
  emit_line()
  if settled_at and not paused then
    settled_at = uv.hrtime() / 1e9
  end
  if dirty then
    flush()
  end
end

function M.stats()
  local current_elapsed = 0
  if settled_at and not paused then
    current_elapsed = (uv.hrtime() / 1e9) - settled_at
  end
  return {
    enabled = enabled,
    paused = paused,
    dirty = dirty,
    current_file = current_file,
    current_line = current_line,
    line_accumulated = line_accumulated,
    current_elapsed = current_elapsed,
    buffer_count = #buffer,
    debounce_active = debounce_timer ~= nil,
    flush_active = flush_timer ~= nil,
    last_pos_key = last_pos_key,
  }
end

return M
