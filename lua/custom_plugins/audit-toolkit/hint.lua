local M = {}

-- Private helper function to find the root and construct the hint path
local function get_hint_file_path()
  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    vim.notify("No open file.", vim.log.levels.WARN)
    return nil
  end

  local git_dir = vim.fn.finddir(".git", ".;")
  if not git_dir or git_dir == "" then
    vim.notify("Not in a git repository.", vim.log.levels.WARN)
    return nil
  end
  local git_root = vim.fn.fnamemodify(git_dir, ":h")

  local file_basename = vim.fn.fnamemodify(current_file, ":t:r")
  local hint_file = git_root .. "/.audit-copilot/" .. file_basename .. ".hint.md"

  if vim.fn.filereadable(hint_file) == 0 then
    local question = "Hint file not found. Create it?\n" .. hint_file
    local choice = vim.fn.confirm(question, "&Yes\n&No", 2)

    if choice == 1 then -- User selected 'Yes'
      -- The 'p' flag creates parent directories as needed.
      vim.fn.mkdir(vim.fn.fnamemodify(hint_file, ":h"), "p")
      -- writefile with an empty list creates an empty file.
      vim.fn.writefile({}, hint_file)
      vim.notify("Hint file created: " .. hint_file, vim.log.levels.INFO)
    else
      vim.notify("Hint file not created.", vim.log.levels.INFO)
      return nil
    end
  end

  return hint_file
end

--- Opens the hint file in a vertical split and shows outline
function M.open_in_split()
  local hint_file = get_hint_file_path()
  if not hint_file then
    return
  end

  vim.cmd("botright vsplit " .. vim.fn.fnameescape(hint_file))
  vim.cmd("Lspsaga outline")
end

--- Opens the hint file in a floating window and shows outline
-- @param position string | nil: 'center', 'top', 'bottom', 'left', 'right', 'top-left', 'top-right', 'bottom-left', 'bottom-right'
function M.open_in_float(position)
  local hint_file = get_hint_file_path()
  if not hint_file then
    return
  end

  local content = vim.fn.readfile(hint_file)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false

  position = position or "center"

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  local width, height, row, col

  if position == "left" then
    width = math.floor(editor_width * 0.4)
    height = editor_height
    row = 0
    col = 0
  elseif position == "right" then
    width = math.floor(editor_width * 0.4)
    height = editor_height
    row = 0
    col = editor_width - width
  elseif position == "top" then
    width = editor_width
    height = math.floor(editor_height * 0.4)
    row = 0
    col = 0
  elseif position == "bottom" then
    width = editor_width
    height = math.floor(editor_height * 0.4)
    row = editor_height - height
    col = 0
  elseif position == "top-left" then
    width = math.floor(editor_width * 0.4)
    height = math.floor(editor_height * 0.5)
    row = 0
    col = 0
  elseif position == "top-right" then
    width = math.floor(editor_width * 0.4)
    height = math.floor(editor_height * 0.5)
    row = 0
    col = editor_width - width
  elseif position == "bottom-left" then
    width = math.floor(editor_width * 0.4)
    height = math.floor(editor_height * 0.5)
    row = editor_height - height
    col = 0
  elseif position == "bottom-right" then
    width = math.floor(editor_width * 0.4)
    height = math.floor(editor_height * 0.5)
    row = editor_height - height
    col = editor_width - width
  else -- "center" or default
    width = math.floor(editor_width * 0.7)
    height = math.floor(editor_height * 0.7)
    row = math.floor((editor_height - height) / 2)
    col = math.floor((editor_width - width) / 2)
  end

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  vim.cmd("Lspsaga outline")
end

--- Performs a live grep across all hint files in the project.
function M.live_grep_hints()
  local ok, telescope_builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("Telescope is not installed.", vim.log.levels.ERROR)
    return
  end

  local git_dir = vim.fn.finddir(".git", ".;")
  if not git_dir or git_dir == "" then
    vim.notify("Not in a git repository.", vim.log.levels.WARN)
    return
  end
  local git_root = vim.fn.fnamemodify(git_dir, ":h")

  local hint_dir = git_root .. "/.audit-copilot"

  if vim.fn.isdirectory(hint_dir) == 0 then
    vim.notify("Hint directory not found: " .. hint_dir, vim.log.levels.INFO)
    return
  end

  telescope_builtin.live_grep({
    prompt_title = "Live Grep All Hint Files",
    search_dirs = { hint_dir },
  })
end

return M
