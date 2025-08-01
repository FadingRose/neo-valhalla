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
      if line:match("^##%s*%+") then
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

--- Sets up buffer-local keymaps for the todo popup.
-- @param buf integer: The buffer handle.
-- @param win_id integer: The window handle.
local function setup_keymaps(buf, win_id)
  -- 't' for append new [t]odo item
  vim.api.nvim_buf_set_keymap(buf, "n", "t", "", {
    noremap = true,
    silent = true,
    desc = "Append new todo item",
    callback = function()
      -- Assuming find_insertion_index is defined elsewhere
      local insert_idx = find_insertion_index(buf, win_id)
      local new_line_content = { "- [ ] " }
      vim.api.nvim_buf_set_lines(buf, insert_idx, insert_idx, false, new_line_content)
      vim.api.nvim_win_set_cursor(win_id, { insert_idx + 1, 0 })
      vim.cmd("startinsert!")
    end,
  })

  -- 's' for append new [s]ub-todo item
  vim.api.nvim_buf_set_keymap(buf, "n", "S", "", {
    noremap = true,
    silent = true,
    desc = "Append new sub-todo item",
    callback = function()
      -- Assuming find_insertion_index is defined elsewhere
      local insert_idx = find_insertion_index(buf, win_id)
      local new_line_content = { "  |- [ ] " }
      vim.api.nvim_buf_set_lines(buf, insert_idx, insert_idx, false, new_line_content)
      vim.api.nvim_win_set_cursor(win_id, { insert_idx + 1, 0 })
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
        if topic and topic:gsub("%s*", "") ~= "" then
          local formatted_topic = "## +----- " .. topic .. " -----+"
          local line_count = vim.api.nvim_buf_line_count(buf)
          vim.api.nvim_buf_set_lines(buf, line_count, -1, false, { "", formatted_topic })
          vim.api.nvim_buf_set_lines(buf, line_count + 2, -1, false, { "- [ ] " })
          vim.api.nvim_win_set_cursor(win_id, { line_count + 3, 7 })
          vim.cmd("startinsert")
        end
      end)
    end,
  })

  -- '[' and ']' for previous/next day
  vim.api.nvim_buf_set_keymap(buf, "n", "<leader>]", "", {
    noremap = true,
    silent = true,
    desc = "Next day's todo",
    callback = function()
      M.switch_day(buf, win_id, 1)
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<leader>[", "", {
    noremap = true,
    silent = true,
    desc = "Previous day's todo",
    callback = function()
      M.switch_day(buf, win_id, -1)
    end,
  })

  vim.keymap.set("n", "q", ":close<CR>", { buffer = buf, silent = true })
end

--- Loads or creates todo content for a given date.
---@param date_str string The date in "mm-dd-YYYY" format.
---@return table, string The file content as a table of lines, and the full filepath.
local function load_todo_content(date_str)
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
  return file_content, todo_filepath
end

function M.switch_day(buf, win_id, direction)
  local current_filepath = vim.api.nvim_buf_get_var(buf, "todo_filepath")
  if not current_filepath then
    return
  end

  local filename = vim.fn.fnamemodify(current_filepath, ":t")
  local date_str = filename:match("^(%d%d-%d%d-%d%d%d%d)%.todo$")
  if not date_str then
    vim.notify("Failed to parse date from filename: " .. filename, vim.log.levels.ERROR, { title = "Todo Plugin" })
    return
  end

  local month, day, year = date_str:match("^(%d%d)-(%d%d)-(%d%d%d%d)$")
  if not (month and day and year) then
    vim.notify("Invalid date format in filename: " .. filename, vim.log.levels.ERROR, { title = "Todo Plugin" })
    return
  end
  -- month, day, year = tonumber(month), tonumber(day), tonumber(year)

  local current_time = os.time({ year = year, month = month, day = day, hour = 12 })
  local new_time = current_time + (direction * 24 * 60 * 60)
  local new_date_str = tostring(os.date("%m-%d-%Y", new_time))

  local file_content, todo_filepath = load_todo_content(new_date_str)

  vim.api.nvim_buf_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_content)
  vim.api.nvim_buf_set_option_value("modifiable", false, { buf = buf })

  vim.api.nvim_buf_set_var(buf, "todo_filepath", todo_filepath)

  local new_title
  if new_date_str == os.date("%m-%d-%Y") then
    new_title = "Today's Todos"
  else
    new_title = new_date_str .. " Todos"
  end

  vim.api.nvim_win_set_config(win_id, { title = new_title })
  vim.api.nvim_win_set_cursor(win_id, { 1, 0 })
end

--- Opens today's todo file in a floating window.
function M.open_today_todo_popup()
  local date_str = tostring(os.date("%m-%d-%Y"))
  local file_content, todo_filepath = load_todo_content(date_str)

  local buf = vim.api.nvim_create_buf(false, true) -- autocmd_buf (temporary), no_undo

  -- Calculate reasonable size for the popup
  local width = math.min(vim.o.columns * 0.8, 100)
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

  -- Defer buffer population and setup to avoid race conditions with other plugins.
  vim.schedule(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_content)

    vim.api.nvim_buf_set_var(buf, "todo_filepath", todo_filepath)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

    -- Enable line wrapping for the popup window
    vim.api.nvim_set_option_value("wrap", true, { win = win_id })
    vim.api.nvim_set_option_value("linebreak", true, { win = win_id })

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
            local git_status =
              vim.fn.system({ "git", "-C", M.tododir, "status", "--porcelain", "--", current_filepath })
            if git_status and git_status ~= "" then
              -- 3. Commit the changes with an automatic message
              local filename = vim.fn.fnamemodify(current_filepath, ":t")
              local date_from_filename = filename:match("^(%d%d-%d%d-%d%d%d%d)%.todo$")
              local commit_message = "Auto-commit: update for " .. (date_from_filename or "todo")
              vim.fn.system({ "git", "-C", M.tododir, "commit", "-m", commit_message })
              -- vim.notify("Changes committed for " .. todo_filename, vim.log.levels.INFO, { title = "Todo Plugin" })
            end
          else
            vim.notify(
              "Failed to save todo file: " .. current_filepath,
              vim.log.levels.ERROR,
              { title = "Todo Plugin" }
            )
          end
        end
      end,
      once = true, -- Ensure it runs only once per buffer close event
    })

    -- Set buffer-local keymaps
    setup_keymaps(buf, win_id)
  end)
end

return M
