local M = {}

function M.setup(plugin)
  local opts = { noremap = true, silent = true }

  vim.keymap.set("n", "<leader>at", function()
    plugin.inline.toggle()
  end, vim.tbl_extend("force", opts, { desc = "Toggle annotations" }))

  vim.keymap.set("n", "<leader>am", function()
    plugin.inline.cycle_mode()
  end, vim.tbl_extend("force", opts, { desc = "Cycle annotation display mode" }))

  vim.keymap.set("n", "<leader>as", function()
    plugin.panel.toggle()
  end, vim.tbl_extend("force", opts, { desc = "Toggle annotation side panel" }))

  vim.keymap.set("n", "<leader>ar", function()
    plugin.store.clear_cache()
    plugin.inline.refresh()
    if plugin.panel.is_open() then
      plugin.panel.refresh()
    end
    vim.notify("Annotations reloaded", vim.log.levels.INFO)
  end, vim.tbl_extend("force", opts, { desc = "Reload annotations from disk" }))

  vim.keymap.set("n", "<leader>ai", function()
    local buf_path = vim.api.nvim_buf_get_name(0)
    local annotations = plugin.store.get_cached(buf_path)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local found = {}
    for _, ann in ipairs(annotations) do
      if ann.line_start and line >= ann.line_start and (not ann.line_end or line <= ann.line_end) then
        table.insert(found, ann)
      end
    end
    if #found == 0 then
      vim.notify("No annotation at current line", vim.log.levels.INFO)
      return
    end
    local lines = {}
    for i, ann in ipairs(found) do
      if i > 1 then
        table.insert(lines, "")
        table.insert(lines, string.rep("─", 40))
        table.insert(lines, "")
      end
      table.insert(lines, string.format("%s %s  [%s]", plugin.highlight.get_icon(ann.tag), ann.tag:upper(), ann.id or "?"))
      table.insert(lines, "")
      if ann.body then
        for _, l in ipairs(vim.split(ann.body, "\n", { plain = true })) do
          table.insert(lines, l)
        end
      end
    end
    local title = #found == 1
      and string.format("%s %s", plugin.highlight.get_icon(found[1].tag), found[1].id or "Annotation")
      or string.format("Annotations at L%d (%d)", line, #found)
    vim.lsp.util.open_floating_preview(lines, "markdown", {
      title = title,
      border = "rounded",
    })
  end, vim.tbl_extend("force", opts, { desc = "Show annotations at current line" }))

  vim.keymap.set("n", "<leader>an", function()
    local buf_path = vim.api.nvim_buf_get_name(0)
    local annotations = plugin.store.get_cached(buf_path)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local next_ann = nil
    for _, ann in ipairs(annotations) do
      if ann.line_start and ann.line_start > line then
        if not next_ann or ann.line_start < next_ann.line_start then
          next_ann = ann
        end
      end
    end
    if next_ann then
      vim.api.nvim_win_set_cursor(0, { next_ann.line_start, 0 })
    else
      vim.notify("No more annotations below", vim.log.levels.INFO)
    end
  end, vim.tbl_extend("force", opts, { desc = "Next annotation" }))

  vim.keymap.set("n", "<leader>aN", function()
    local buf_path = vim.api.nvim_buf_get_name(0)
    local annotations = plugin.store.get_cached(buf_path)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local prev_ann = nil
    for _, ann in ipairs(annotations) do
      if ann.line_end and ann.line_end < line then
        if not prev_ann or ann.line_end > prev_ann.line_end then
          prev_ann = ann
        end
      end
    end
    if prev_ann then
      vim.api.nvim_win_set_cursor(0, { prev_ann.line_start, 0 })
    else
      vim.notify("No more annotations above", vim.log.levels.INFO)
    end
  end, vim.tbl_extend("force", opts, { desc = "Previous annotation" }))

  vim.keymap.set("n", "<leader>ag", function()
    plugin.generate.generate()
  end, vim.tbl_extend("force", opts, { desc = "Generate annotations" }))

  vim.keymap.set("v", "<leader>ag", function()
    local s = vim.api.nvim_buf_get_mark(0, "<")
    local e = vim.api.nvim_buf_get_mark(0, ">")
    plugin.generate.generate({
      start_line = math.min(s[1], e[1]),
      end_line = math.max(s[1], e[1]),
    })
  end, vim.tbl_extend("force", opts, { desc = "Generate annotations for selection" }))

  vim.keymap.set("n", "<leader>aP", function()
    plugin.generate.generate_with_prompt()
  end, vim.tbl_extend("force", opts, { desc = "Generate annotations with prompt" }))

  vim.keymap.set("v", "<leader>aP", function()
    local s = vim.api.nvim_buf_get_mark(0, "<")
    local e = vim.api.nvim_buf_get_mark(0, ">")
    plugin.generate.generate_with_prompt({
      start_line = math.min(s[1], e[1]),
      end_line = math.max(s[1], e[1]),
    })
  end, vim.tbl_extend("force", opts, { desc = "Generate annotations for selection with prompt" }))

  vim.keymap.set("n", "<leader>al", function()
    plugin.generate.generate_at_line()
  end, vim.tbl_extend("force", opts, { desc = "Generate annotation at current line" }))

  vim.keymap.set("n", "<leader>ap", function()
    plugin.generate.generate_at_line_with_prompt()
  end, vim.tbl_extend("force", opts, { desc = "Generate annotation at current line with prompt" }))

  vim.keymap.set("n", "<leader>aS", function()
    plugin.session.reset()
  end, vim.tbl_extend("force", opts, { desc = "Reset annotation Claude session" }))

  vim.keymap.set("n", "<leader>aG", function()
    local backends = { "opencode", "claude" }
    local current = plugin.generate.backend
    vim.ui.select(backends, {
      prompt = "Annotation backend (current: " .. current .. "):",
    }, function(choice)
      if choice then
        plugin.generate.set_backend(choice)
      end
    end)
  end, vim.tbl_extend("force", opts, { desc = "Select annotation backend" }))

  vim.keymap.set("n", "<leader>aL", function()
    plugin.list.toggle()
  end, vim.tbl_extend("force", opts, { desc = "List all annotations" }))

  vim.keymap.set("n", "<leader>ac", function()
    plugin.compact.compact()
  end, vim.tbl_extend("force", opts, { desc = "Compact similar annotations" }))

  vim.keymap.set("n", "<leader>ae", function()
    plugin.edit.open()
  end, vim.tbl_extend("force", opts, { desc = "Edit annotation file" }))

  vim.keymap.set("n", "<leader>ad", function()
    plugin.edit.delete()
  end, vim.tbl_extend("force", opts, { desc = "Delete annotation" }))
end

return M
