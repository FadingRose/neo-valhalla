local store = require("custom_plugins.annotation.store")
local hl = require("custom_plugins.annotation.highlight")

local M = {}

local panel_buf = nil
local panel_win = nil
local panel_source_buf = nil
local panel_annotations = {}
local sync_autocmd = nil

local function format_annotation(ann, width)
  local lines = {}
  local icon = hl.get_icon(ann.tag)
  local tag_hl_name = ann.tag or "note"

  table.insert(lines, string.format("━━ %s %s [%s] ━━", icon, tag_hl_name:upper(), ann.id or "?"))
  table.insert(lines, "")

  if ann.author then
    table.insert(lines, string.format("Author: %s", ann.author))
  end
  if ann.line_start then
    local range = ann.line_end and ann.line_start ~= ann.line_end
        and string.format("L%d-%d", ann.line_start, ann.line_end)
        or string.format("L%d", ann.line_start)
    table.insert(lines, string.format("Lines: %s", range))
  end
  if ann.status then
    table.insert(lines, string.format("Status: %s", ann.status))
  end
  table.insert(lines, "")

  if ann.body and ann.body ~= "" then
    for _, line in ipairs(vim.split(ann.body, "\n", { plain = true })) do
      if width and #line > width - 2 then
        local wrapped = {}
        local pos = 1
        while pos <= #line do
          table.insert(wrapped, line:sub(pos, pos + width - 3))
          pos = pos + width - 2
        end
        for _, w in ipairs(wrapped) do
          table.insert(lines, w)
        end
      else
        table.insert(lines, line)
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "")
  return lines
end

local function build_content(annotations, width)
  local all_lines = {}
  all_lines.separators = {}
  all_lines.jump_map = {}

  for idx, ann in ipairs(annotations) do
    local start_line = #all_lines + 1
    local ann_lines = format_annotation(ann, width)
    for _, l in ipairs(ann_lines) do
      table.insert(all_lines, l)
    end
    all_lines.jump_map[start_line] = ann

    for i = start_line, #all_lines do
      all_lines.jump_map[i] = ann
    end
  end

  return all_lines
end

local function jump_to_source(ann)
  if not ann or not ann.file_path then
    return
  end
  local git_root = store.git_root()
  if not git_root then
    return
  end

  local target = git_root .. "/" .. ann.file_path
  if vim.fn.filereadable(target) == 0 then
    target = git_root .. "/readonly/" .. ann.file_path
  end
  if vim.fn.filereadable(target) == 0 then
    vim.notify("Annotation file not found: " .. ann.file_path, vim.log.levels.WARN)
    return
  end

  if panel_win and vim.api.nvim_win_is_valid(panel_win) then
    vim.api.nvim_set_current_win(panel_win - 1 > 0 and panel_win - 1 or vim.fn.winnr("#") > 0 and vim.fn.win_getid(vim.fn.winnr("#")) or panel_win)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(target))
  if ann.line_start then
    vim.api.nvim_win_set_cursor(0, { ann.line_start, 0 })
  end
end

function M.open()
  local source_buf = vim.api.nvim_get_current_buf()
  local source_path = vim.api.nvim_buf_get_name(source_buf)
  if source_path == "" then
    vim.notify("No file open", vim.log.levels.WARN)
    return
  end

  local annotations = store.get_cached(source_path)
  if not annotations or #annotations == 0 then
    vim.notify("No annotations for this file", vim.log.levels.INFO)
    return
  end

  if panel_win and vim.api.nvim_win_is_valid(panel_win) then
    vim.api.nvim_win_close(panel_win, true)
  end

  panel_source_buf = source_buf
  panel_annotations = annotations

  panel_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[panel_buf].buftype = "nofile"
  vim.bo[panel_buf].bufhidden = "wipe"
  vim.bo[panel_buf].swapfile = false
  vim.bo[panel_buf].filetype = "annotation-panel"
  vim.b[panel_buf].annotation_panel = true

  vim.cmd("rightbelow vsplit")
  panel_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(panel_win, panel_buf)
  vim.wo[panel_win].wrap = true
  vim.wo[panel_win].number = false
  vim.wo[panel_win].relativenumber = false
  vim.wo[panel_win].signcolumn = "no"
  vim.wo[panel_win].winfixwidth = true
  vim.api.nvim_win_set_width(panel_win, 50)

  local content = build_content(annotations, 48)
  local lines = {}
  for _, l in ipairs(content) do
    if type(l) == "string" then
      table.insert(lines, l)
    end
  end
  vim.api.nvim_buf_set_lines(panel_buf, 0, -1, false, lines)
  vim.bo[panel_buf].modifiable = false

  local ns = vim.api.nvim_create_namespace("annotation_panel_hl")
  for i = 1, #lines do
    if lines[i]:match("^━━") then
      vim.api.nvim_buf_add_highlight(panel_buf, ns, "Title", i - 1, 0, -1)
    end
  end

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = panel_buf, nowait = true })

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(panel_win)
    local ann = content.jump_map[cursor[1]]
    if ann then
      jump_to_source(ann)
    end
  end, { buffer = panel_buf, nowait = true })

  vim.keymap.set("n", "<C-r>", function()
    M.refresh()
  end, { buffer = panel_buf, nowait = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(panel_win),
    once = true,
    callback = function()
      panel_buf = nil
      panel_win = nil
      panel_source_buf = nil
      panel_annotations = {}
    end,
  })
end

function M.close()
  if panel_win and vim.api.nvim_win_is_valid(panel_win) then
    vim.api.nvim_win_close(panel_win, true)
  end
  panel_buf = nil
  panel_win = nil
  panel_source_buf = nil
  panel_annotations = {}
end

function M.toggle()
  if panel_win and vim.api.nvim_win_is_valid(panel_win) then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  if not panel_win or not vim.api.nvim_win_is_valid(panel_win) then
    return
  end
  local source_path = vim.api.nvim_buf_get_name(panel_source_buf or 0)
  if source_path == "" then
    return
  end

  local annotations = store.get_cached(source_path)
  if not annotations then
    return
  end

  panel_annotations = annotations
  local width = vim.api.nvim_win_get_width(panel_win)
  local content = build_content(annotations, width - 2)
  local lines = {}
  for _, l in ipairs(content) do
    if type(l) == "string" then
      table.insert(lines, l)
    end
  end

  vim.bo[panel_buf].modifiable = true
  vim.api.nvim_buf_set_lines(panel_buf, 0, -1, false, lines)
  vim.bo[panel_buf].modifiable = false
end

function M.is_open()
  return panel_win ~= nil and vim.api.nvim_win_is_valid(panel_win)
end

return M
