local M = {}

-- Store the configured todo directory
M.tododir = vim.fn.expand("~/todo") -- Default value

--- Sets up the todo plugin with user options.
--- @param opts table
---   opts.tododir string? The directory to store todo files. Defaults to '~/todo'.
function M.setup(opts)
  opts = opts or {}
  if opts.tododir then
    M.tododir = vim.fn.expand(opts.tododir)
  end
end

--- Opens today's todo file in a floating window.
function M.open_today_todo_popup()
  local date_str = os.date("%m-%d-%Y")
  local todo_filename = date_str .. ".todo.md"
  local todo_filepath = M.tododir .. "/" .. todo_filename

  -- Ensure the directory exists
  vim.fn.system({ "mkdir", "-p", M.tododir })

  local file_content = {}
  local default_header = "# " .. date_str .. " Daily Todos\n\n- [ ] "

  -- Read file content or create default
  local file = io.open(todo_filepath, "r")
  if file then
    for line in file:lines() do
      table.insert(file_content, line)
    end
    io.close(file)
  else
    table.insert(file_content, default_header)
  end

  local buf = vim.api.nvim_create_buf(false, true) -- autocmd_buf (temporary), no_undo
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_content)

  vim.api.nvim_buf_set_var(buf, "todo_filepath", todo_filepath)

  -- Calculate reasonable size for the popup
  local width = math.min(vim.o.columns * 0.8, 80)
  local height = math.min(vim.o.lines * 0.8, 30)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_id = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "single",
    focusable = true,
    style = "minimal",
    title = "Today's Todos",
    title_pos = "center",
  })

  -- Autocommand to save buffer on WinLeave and BufDelete
  vim.api.nvim_create_autocmd({ "BufLeave", "BufDelete" }, {
    buffer = buf,
    callback = function()
      local current_filepath = vim.api.nvim_buf_get_var(buf, "todo_filepath")
      if current_filepath then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local out_file = io.open(current_filepath, "w")
        if out_file then
          out_file:write(table.concat(lines, "\n"))
          io.close(out_file)
          vim.notify("Todo file saved: " .. current_filepath, vim.log.levels.INFO, { title = "Todo Plugin" })
        else
          vim.notify("Failed to save todo file: " .. current_filepath, vim.log.levels.ERROR, { title = "Todo Plugin" })
        end
      end
    end,
    once = true, -- Ensure it runs only once per buffer close event
  })

  vim.api.nvim_set_current_win(win_id)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("G", true, false, true), "n", false) -- Go to end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", false) -- Enter insert mode at end
end

return M
