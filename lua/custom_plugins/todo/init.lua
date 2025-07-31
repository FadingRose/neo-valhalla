local M = {}

-- Store the configured todo directory
M.tododir = vim.fn.expand("~/.config/todo") -- Default value

-- Function to find the correct insertion index for a new todo item
local function find_insertion_index(buf, win_id)
  local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
  local current_line_num = cursor_pos[1] -- 1-based
  local total_lines = vim.api.nvim_buf_line_count(buf)

  local insert_before_line = -1 -- Sentinel: -1 means append to end

  -- Search for the next topic from the current line onwards
  if current_line_num <= total_lines then
    local lines_to_search = vim.api.nvim_buf_get_lines(buf, current_line_num - 1, total_lines, false)
    for i, line in ipairs(lines_to_search) do
      if line:match("^%s*%+") then
        -- Found a topic header. Its line number is current_line_num + i - 1
        insert_before_line = current_line_num + i - 1
        break
      end
    end
  end

  local insert_idx
  if insert_before_line ~= -1 then
    insert_idx = insert_before_line - 1 -- API is 0-based
  else
    insert_idx = total_lines -- Append to the end
  end

  -- Adjust insertion point up if the preceding line is empty
  while insert_idx > 0 do
    local prev_line = vim.api.nvim_buf_get_lines(buf, insert_idx - 1, insert_idx, false)[1]
    if prev_line and prev_line:match("^%s*$") then
      insert_idx = insert_idx - 1
    else
      break
    end
  end

  return insert_idx
end

--- Sets up the todo plugin with user options.
--- @param opts table
---   opts.tododir string? The directory to store todo files. Defaults to '~/.config/todo'.
function M.setup(opts)
  opts = opts or {}
  if opts.tododir then
    M.tododir = vim.fn.expand(opts.tododir)
  end

  --   if not git_timer then
  --     git_timer = vim.uv.new_timer()
  --     local timer_callback = vim.schedule_wrap(function()
  --       vim.notify("Git Sync: Starting pull and push...", vim.log.levels.INFO, { title = "Todo Plugin" })
  --       vim.fn.system({ "git", "-C", M.tododir, "pull", "--rebase" })
  --       vim.fn.system({ "git", "-C", M.tododir, "push" })
  --       vim.notify("Git Sync: Finished.", vim.log.levels.INFO, { title = "Todo Plugin" })
  --     end)
  --     git_timer:start(0, 6000000, timer_callback) -- Every hour
  --   end
end

--- Synchronizes the todo directory with the remote git repository.
function M.sync(on_complete)
  local notify = function(msg, level)
    -- 使用 vim.schedule 確保在主線程中安全地發送通知
    vim.schedule(function()
      require("noice").notify(msg, level or "info")
    end)
  end

  vim.fn.jobstart({ "git", "-C", M.tododir, "pull", "--rebase" }, {
    on_exit = function(_, pull_code)
      if pull_code ~= 0 then
        notify("Todo Git Sync: Pull failed.", "error")
        if on_complete then
          on_complete(pull_code)
        end
        return
      end

      -- notify("Git Sync: Pull finished.")
      -- notify("Git Sync: Starting push...")

      vim.fn.jobstart({ "git", "-C", M.tododir, "push" }, {
        on_exit = function(_, push_code)
          if push_code ~= 0 then
            notify("Git Sync: Push failed.", "error")
          end
          if on_complete then
            on_complete(push_code)
          end
        end,
      })
    end,
  })
end

--- Opens today's todo file in a floating window.
function M.open_today_todo_popup()
  local date_str = os.date("%m-%d-%Y")
  local todo_filename = date_str .. ".todo"
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
    file:close()
  else
    -- Create the file since it doesn't exist
    local new_file = io.open(todo_filepath, "w")
    if new_file then
      new_file:write(default_header)
      new_file:close()
    end
    -- Split the header string into a table of lines for the buffer
    file_content = vim.split(default_header, "\n")
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
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    focusable = true,
    style = "minimal",
    title = "Today's Todos",
    title_pos = "center",
  })

  -- Enable line wrapping for the popup window
  vim.api.nvim_set_option_value("wrap", true, { win = win_id })

  -- Autocommand to save buffer and commit changes on WinLeave and BufDelete
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
          -- vim.notify("Todo file saved: " .. current_filepath, vim.log.levels.INFO, { title = "Todo Plugin" })

          -- Git operations after saving the file
          -- 1. Add the file to the staging area
          vim.fn.system({ "git", "-C", M.tododir, "add", current_filepath })

          -- 2. Check if there are changes to commit for this file
          local git_status = vim.fn.system({ "git", "-C", M.tododir, "status", "--porcelain", "--", current_filepath })
          if git_status and git_status ~= "" then
            -- 3. Commit the changes with an automatic message
            local commit_message = "Auto-commit: update for " .. date_str
            vim.fn.system({ "git", "-C", M.tododir, "commit", "-m", commit_message })
            -- vim.notify("Changes committed for " .. todo_filename, vim.log.levels.INFO, { title = "Todo Plugin" })
          end
        else
          vim.notify("Failed to save todo file: " .. current_filepath, vim.log.levels.ERROR, { title = "Todo Plugin" })
        end
      end
    end,
    once = true, -- Ensure it runs only once per buffer close event
  })

  -- Set buffer-local keymaps
  -- 't' for append new [t]odo item
  vim.api.nvim_buf_set_keymap(buf, "n", "t", "", {
    noremap = true,
    silent = true,
    desc = "Append new todo item",
    callback = function()
      local insert_idx = find_insertion_index(buf, win_id)
      local new_line_content = { "- [ ] " }

      -- Insert the new line at the determined position
      vim.api.nvim_buf_set_lines(buf, insert_idx, insert_idx, false, new_line_content)
      local cursor_target_line = insert_idx + 1

      -- Move cursor to new line and enter insert mode at the end of it
      vim.api.nvim_win_set_cursor(win_id, { cursor_target_line, 0 })
      vim.cmd("startinsert!")
    end,
  })

  -- 's' for append new [s]ub-todo item
  vim.api.nvim_buf_set_keymap(buf, "n", "s", "", {
    noremap = true,
    silent = true,
    desc = "Append new todo item",
    callback = function()
      local insert_idx = find_insertion_index(buf, win_id)
      local new_line_content = { "  |- [ ] " }

      -- Insert the new line at the determined position
      vim.api.nvim_buf_set_lines(buf, insert_idx, insert_idx, false, new_line_content)
      local cursor_target_line = insert_idx + 1

      -- Move cursor to new line and enter insert mode at the end of it
      vim.api.nvim_win_set_cursor(win_id, { cursor_target_line, 0 })
      vim.cmd("startinsert!")
    end,
  })

  -- 'c' for [c]heck/uncheck todo item
  vim.api.nvim_buf_set_keymap(buf, "n", "c", "", {
    noremap = true,
    silent = true,
    desc = "Toggle todo item checkbox",
    callback = function()
      local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
      local line_num = cursor_pos[1]
      local line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]

      if line then
        local new_line
        if line:match("^%s*|?%-%s*%[ %] ") then
          new_line = line:gsub("%[ %]", "[x]", 1)
        elseif line:match("^%s*|?%-%s*%[x%] ") then
          new_line = line:gsub("%[x%]", "[ ]", 1)
        end

        if new_line then
          vim.api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
        end
      end
    end,
  })

  -- 'T' for a new [t]opic header
  vim.api.nvim_buf_set_keymap(buf, "n", "T", "", {
    noremap = true,
    silent = true,
    desc = "Append a new topic header",
    callback = function()
      vim.ui.input({ prompt = "Topic: " }, function(topic)
        -- Ensure the user entered something and didn't cancel
        if topic and topic:gsub("%s*", "") ~= "" then
          local formatted_topic = "+----- " .. topic .. " -----+"
          local line_count = vim.api.nvim_buf_line_count(buf)
          -- Append an empty line for spacing, then the topic
          vim.api.nvim_buf_set_lines(buf, line_count, -1, false, { "", formatted_topic })
          -- Optional: move cursor below the new topic and enter insert mode
          vim.api.nvim_buf_set_lines(buf, line_count + 2, -1, false, { "- [ ] " })
          vim.api.nvim_win_set_cursor(win_id, { line_count + 3, 7 })
          vim.cmd("startinsert")
        end
      end)
    end,
  })

  vim.keymap.set("n", "q", ":close<CR>", { buffer = true, silent = true })

  vim.api.nvim_set_current_win(win_id)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("G", true, false, true), "n", false) -- Go to end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", false) -- Enter insert mode at end
end

return M
