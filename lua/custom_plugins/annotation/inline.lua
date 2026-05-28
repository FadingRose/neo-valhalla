local store = require("custom_plugins.annotation.store")
local hl = require("custom_plugins.annotation.highlight")

local M = {}

local NAMESPACE = vim.api.nvim_create_namespace("annotation_inline")
local enabled = true
local mode = "truncated"

local function truncate_text(text, max_len)
  if not text then
    return ""
  end
  local first_line = text:match("([^\n]+)") or ""
  if #first_line > max_len then
    return first_line:sub(1, max_len - 1) .. "…"
  end
  return first_line
end

local function render_truncated(bufnr, annotations)
  for _, ann in ipairs(annotations) do
    if ann.line_start and ann.body then
      local icon = hl.get_icon(ann.tag)
      local tag_hl = hl.get_hl(ann.tag)
      local text = truncate_text(ann.body, 80)
      local line = math.max(0, ann.line_start - 1)
      local label = string.format(" %s %s", icon, text)

      vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, line, 0, {
        virt_text = {
          { label, tag_hl },
        },
        virt_text_pos = "eol",
        hl_mode = "blend",
      })
    end
  end
end

local function render_full(bufnr, annotations)
  for _, ann in ipairs(annotations) do
    if ann.line_start and ann.body then
      local icon = hl.get_icon(ann.tag)
      local tag_hl = hl.get_hl(ann.tag)
      local lines = vim.split(ann.body, "\n", { plain = true })
      local virt_lines = {}
      for _, l in ipairs(lines) do
        table.insert(virt_lines, { { "   " .. l, tag_hl } })
      end
      local line = math.max(0, ann.line_start - 1)
      vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, line, 0, {
        virt_text = {
          { string.format(" %s [%s]", icon, ann.id or "?"), tag_hl },
        },
        virt_text_pos = "eol",
        virt_lines = virt_lines,
        hl_mode = "blend",
      })
    end
  end
end

local function render_icon_only(bufnr, annotations)
  for _, ann in ipairs(annotations) do
    if ann.line_start then
      local icon = hl.get_icon(ann.tag)
      local tag_hl = hl.get_hl(ann.tag)
      local line = math.max(0, ann.line_start - 1)
      vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, line, 0, {
        virt_text = {
          { " " .. icon, tag_hl },
        },
        virt_text_pos = "eol",
        hl_mode = "blend",
      })
    end
  end
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)

  if not enabled then
    return
  end

  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  if buf_path == "" then
    return
  end

  local annotations = store.get_cached(buf_path)
  if not annotations or #annotations == 0 then
    return
  end

  if mode == "full" then
    render_full(bufnr, annotations)
  elseif mode == "icon" then
    render_icon_only(bufnr, annotations)
  else
    render_truncated(bufnr, annotations)
  end
end

function M.toggle()
  enabled = not enabled
  M.refresh()
  vim.notify("Annotations " .. (enabled and "shown" or "hidden"), vim.log.levels.INFO)
end

function M.cycle_mode()
  local modes = { "truncated", "full", "icon" }
  for i, m in ipairs(modes) do
    if m == mode then
      mode = modes[(i % #modes) + 1]
      break
    end
  end
  M.refresh()
  vim.notify("Annotation mode: " .. mode, vim.log.levels.INFO)
end

function M.set_mode(m)
  mode = m
  M.refresh()
end

function M.is_enabled()
  return enabled
end

return M
