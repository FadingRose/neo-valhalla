local store = require("custom_plugins.auditscope.glance.store")

local M = {}

local GLANCE_NS = vim.api.nvim_create_namespace("auditscope_glance")
local PARTIAL_BLOCKS = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" }
local BAR_WIDTH = 20

local visible = false
local file_cache = {}

local function get_file_max(file_data)
  local max_val = 5
  for _, seconds in pairs(file_data) do
    if seconds > max_val then
      max_val = seconds
    end
  end
  return max_val
end

local function format_bar(seconds, max_seconds)
  if seconds <= 0 then
    return nil
  end

  local ratio = math.min(seconds / max_seconds, 1.0)
  local total_ticks = math.floor(ratio * BAR_WIDTH * 8)
  local full_blocks = math.floor(total_ticks / 8)
  local remainder = total_ticks % 8

  local bar = string.rep("█", full_blocks)
  if remainder > 0 then
    bar = bar .. PARTIAL_BLOCKS[remainder]
  end

  local current_len = full_blocks + (remainder > 0 and 1 or 0)
  local empty = string.rep(" ", math.max(0, BAR_WIDTH - current_len))

  local h_group = "String"
  if ratio > 0.8 then
    h_group = "Error"
  elseif ratio > 0.4 then
    h_group = "WarningMsg"
  end

  return {
    { " ▕", "Comment" },
    { bar, h_group },
    { empty, "Comment" },
    { string.format("▏%4.1fs", seconds), "Comment" },
  }
end

function M.render_buffer(bufnr, file)
  if not visible then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, GLANCE_NS, 0, -1)

  local data = file_cache[file]
  if not data or not next(data) then
    data = store.load(file)
    if not next(data) then
      return
    end
    file_cache[file] = data
  end

  local max_seconds = get_file_max(data)

  for line_str, seconds in pairs(data) do
    local line = tonumber(line_str)
    if line and line > 0 and seconds > 0.1 then
      local virt_text = format_bar(seconds, max_seconds)
      if virt_text then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, GLANCE_NS, line - 1, 0, {
          virt_text = virt_text,
          virt_text_pos = "eol_right_align",
          hl_mode = "blend",
        })
      end
    end
  end
end

function M.render_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.fn.expand("%:p")
  if file == "" then
    return
  end
  M.render_buffer(bufnr, file)
end

function M.show()
  visible = true
  file_cache = {}
  M.render_current()
end

function M.hide()
  visible = false
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, GLANCE_NS, 0, -1)
end

function M.toggle()
  if visible then
    M.hide()
    vim.notify("AuditScope Glance: bars hidden", vim.log.levels.INFO)
  else
    M.show()
    vim.notify("AuditScope Glance: bars shown", vim.log.levels.INFO)
  end
end

function M.is_visible()
  return visible
end

function M.refresh_cache(file)
  if file then
    file_cache[file] = store.load(file)
  else
    file_cache = {}
  end
end

function M.invalidate_line(file, line)
  if file_cache[file] then
    file_cache[file][tostring(line)] = nil
  end
end

function M.show_repo_summary()
  local git_root = vim.fs.root(0, ".git")
  if not git_root then
    vim.notify("AuditScope: not in a git repo", vim.log.levels.WARN)
    return
  end

  local all_data = store.load_all_under_git(git_root)
  if not next(all_data) then
    vim.notify("AuditScope: no glance data for this repo", vim.log.levels.INFO)
    return
  end

  local file_totals = {}
  for file, data in pairs(all_data) do
    local total = 0
    local lines = 0
    for _, seconds in pairs(data) do
      total = total + seconds
      lines = lines + 1
    end
    local rel = vim.fs.normalize(file):sub(#vim.fs.normalize(git_root) + 2)
    table.insert(file_totals, {
      file = rel or file,
      total = total,
      lines = lines,
    })
  end

  table.sort(file_totals, function(a, b)
    return a.total > b.total
  end)

  local lines_out = {
    "# Glance Summary: " .. vim.fn.fnamemodify(git_root, ":t"),
    "",
    string.format("%-50s %8s %8s", "File", "Lines", "Seconds"),
    string.rep("─", 70),
  }

  for _, item in ipairs(file_totals) do
    table.insert(lines_out, string.format("%-50s %8d %8.1f", item.file, item.lines, item.total))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_out)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "auditscope_summary"
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

return M
