local store = require("custom_plugins.annotation.store")
local hl = require("custom_plugins.annotation.highlight")

local M = {}

local list_buf = nil
local list_win = nil

local function format_time(mtime)
  if not mtime or mtime <= 0 then return "unknown         " end
  return os.date("%Y-%m-%d %H:%M", mtime)
end

local function group_by_file(annotations)
  local groups = {}
  local order = {}
  for _, ann in ipairs(annotations) do
    local fp = ann.file_path or "unknown"
    if not groups[fp] then
      groups[fp] = {}
      table.insert(order, fp)
    end
    table.insert(groups[fp], ann)
  end
  return groups, order
end

local function build_list(annotations)
  local lines = {}
  local jump_map = {}

  table.insert(lines, string.format(" Annotations  %d total", #annotations))
  table.insert(lines, string.rep("─", 90))
  table.insert(lines, string.format("  %-6s  %-12s  %-12s  %-12s  %-16s  %s",
    "ID", "TAG", "LINES", "AUTHOR", "TIME", "PREVIEW"))
  table.insert(lines, string.rep("─", 90))

  local groups, order = group_by_file(annotations)

  for _, fp in ipairs(order) do
    local anns = groups[fp]
    table.insert(lines, "")
    table.insert(lines, "  " .. fp)
    for _, ann in ipairs(anns) do
      local range = ann.line_end and ann.line_start ~= ann.line_end
          and string.format("L%d-%d", ann.line_start, ann.line_end)
          or string.format("L%d", ann.line_start or 0)
      local author = ann.author or "unknown"
      local time_str = format_time(ann.mtime)
      local preview = (ann.body or ""):match("([^\n]+)") or ""
      if #preview > 45 then preview = preview:sub(1, 42) .. "..." end
      local row = string.format("    %-6s  %-12s  %-12s  %-12s  %-16s  %s",
        ann.id or "?", ann.tag or "note", range, author, time_str, preview)
      local line_num = #lines + 1
      table.insert(lines, row)
      jump_map[line_num] = ann
    end
  end

  table.insert(lines, "")
  table.insert(lines, string.rep("─", 90))
  table.insert(lines, "  <CR> jump to annotation   q close   <C-r> refresh")

  return lines, jump_map
end

local function jump_to_annotation(ann)
  if not ann or not ann.file_path then return end
  local git_root = store.git_root()
  if not git_root then return end

  local target = git_root .. "/" .. ann.file_path
  if vim.fn.filereadable(target) == 0 then
    target = git_root .. "/readonly/" .. ann.file_path
  end
  if vim.fn.filereadable(target) == 0 then
    vim.notify("File not found: " .. ann.file_path, vim.log.levels.WARN)
    return
  end

  M.close()
  vim.cmd("edit " .. vim.fn.fnameescape(target))
  if ann.line_start then
    vim.api.nvim_win_set_cursor(0, { ann.line_start, 0 })
  end
end

function M.open()
  if list_win and vim.api.nvim_win_is_valid(list_win) then
    vim.api.nvim_set_current_win(list_win)
    return
  end

  local annotations = store.get_all_annotations()
  if #annotations == 0 then
    vim.notify("No annotations found", vim.log.levels.INFO)
    return
  end

  table.sort(annotations, function(a, b)
    if (a.file_path or "") ~= (b.file_path or "") then
      return (a.file_path or "") < (b.file_path or "")
    end
    return (a.line_start or 0) < (b.line_start or 0)
  end)

  local lines, jump_map = build_list(annotations)

  list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[list_buf].buftype = "nofile"
  vim.bo[list_buf].bufhidden = "wipe"
  vim.bo[list_buf].swapfile = false
  vim.bo[list_buf].filetype = "annotation-list"
  vim.b[list_buf].annotation_panel = true

  vim.cmd("vsplit")
  list_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(list_win, list_buf)
  vim.wo[list_win].wrap = false
  vim.wo[list_win].number = false
  vim.wo[list_win].relativenumber = false
  vim.wo[list_win].signcolumn = "no"
  vim.api.nvim_win_set_width(list_win, 96)

  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
  vim.bo[list_buf].modifiable = false

  local ns = vim.api.nvim_create_namespace("annotation_list_hl")
  for i, line in ipairs(lines) do
    if i == 1 then
      vim.api.nvim_buf_add_highlight(list_buf, ns, "Title", i - 1, 0, -1)
    elseif i == 3 then
      vim.api.nvim_buf_add_highlight(list_buf, ns, "Comment", i - 1, 0, -1)
    elseif line:match("^  %S") and not line:match("^    ") then
      vim.api.nvim_buf_add_highlight(list_buf, ns, "Directory", i - 1, 0, -1)
    end
  end

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = list_buf, nowait = true })

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(list_win)
    local ann = jump_map[cursor[1]]
    if ann then
      jump_to_annotation(ann)
    end
  end, { buffer = list_buf, nowait = true })

  vim.keymap.set("n", "<C-r>", function()
    M.close()
    M.open()
  end, { buffer = list_buf, nowait = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(list_win),
    once = true,
    callback = function()
      list_buf = nil
      list_win = nil
    end,
  })
end

function M.close()
  if list_win and vim.api.nvim_win_is_valid(list_win) then
    vim.api.nvim_win_close(list_win, true)
  end
  list_buf = nil
  list_win = nil
end

function M.toggle()
  if list_win and vim.api.nvim_win_is_valid(list_win) then
    M.close()
  else
    M.open()
  end
end

return M
