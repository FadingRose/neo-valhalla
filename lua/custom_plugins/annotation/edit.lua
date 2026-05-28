local store = require("custom_plugins.annotation.store")

local M = {}

function M.open()
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    vim.notify("Annotation Edit: No file open", vim.log.levels.WARN)
    return
  end

  local rel = store.file_rel_path(buf_path)
  local dir = store.annotations_for_file_dir(rel)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    vim.notify("Annotation Edit: No annotations for this file", vim.log.levels.INFO)
    return
  end

  local files = {}
  for _, item in ipairs(vim.fn.readdir(dir)) do
    if item:match("%.md$") then
      table.insert(files, dir .. "/" .. item)
    end
  end

  if #files == 0 then
    vim.notify("Annotation Edit: No annotation files found", vim.log.levels.INFO)
    return
  end

  table.sort(files)

  if #files == 1 then
    vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(files[1]))
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    local name = vim.fn.fnamemodify(f, ":t")
    table.insert(items, name)
  end

  vim.ui.select(items, { prompt = "Edit annotation:" }, function(_, idx)
    if idx and files[idx] then
      vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(files[idx]))
    end
  end)
end

function M.open_all()
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    return
  end

  local rel = store.file_rel_path(buf_path)
  local dir = store.annotations_for_file_dir(rel)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    vim.notify("Annotation Edit: No annotations for this file", vim.log.levels.INFO)
    return
  end

  local files = {}
  for _, item in ipairs(vim.fn.readdir(dir)) do
    if item:match("%.md$") then
      table.insert(files, dir .. "/" .. item)
    end
  end

  if #files == 0 then
    return
  end

  table.sort(files)
  vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(files[1]))
  for i = 2, #files do
    vim.cmd("vsplit " .. vim.fn.fnameescape(files[i]))
  end
end

function M.delete()
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    return
  end

  local rel = store.file_rel_path(buf_path)
  local dir = store.annotations_for_file_dir(rel)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    return
  end

  local files = {}
  for _, item in ipairs(vim.fn.readdir(dir)) do
    if item:match("%.md$") then
      table.insert(files, { path = dir .. "/" .. item, name = item })
    end
  end

  if #files == 0 then
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    table.insert(items, f.name)
  end

  vim.ui.select(items, { prompt = "Delete annotation:" }, function(_, idx)
    if idx and files[idx] then
      local choice = vim.fn.confirm("Delete " .. files[idx].name .. "?", "&Yes\n&No", 2)
      if choice == 1 then
        vim.fn.delete(files[idx].path)
        store.clear_cache()
        local inline = require("custom_plugins.annotation.inline")
        inline.refresh()
        vim.notify("Annotation deleted: " .. files[idx].name, vim.log.levels.INFO)
      end
    end
  end)
end

return M
