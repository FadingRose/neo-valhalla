-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>td", function()
  require("custom_plugins.todo").open_today_todo_popup()
end, { desc = "Open Today's Todos" })

vim.keymap.set("n", "<leader>tl", function()
  require("telescope.builtin").find_files({
    prompt_title = "Todo Files",
    cwd = require("custom_plugins.todo").tododir,
    hidden = true, -- Show hidden files
    find_command = { "rg", "--files", "--hidden", "--glob", "!*.git" }, -- Exclude .git directory
  })
end, { desc = "Open Todo Files" })

vim.keymap.del("n", "<leader>.")

vim.keymap.set("n", "<leader>sA", function() end)

-- 在可视模式下使用 J 和 K 上下移动选中的代码块
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected block down", silent = true })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected block up", silent = true })

-- Resize window using <Alt+Arrow> keys
vim.keymap.set("n", "<M-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
vim.keymap.set("n", "<M-Down>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
vim.keymap.set("n", "<M-Up>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
vim.keymap.set("n", "<M-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Move to window using <ctrl> arrow keys
vim.keymap.set("n", "<C-Up>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
vim.keymap.set("n", "<C-Down>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
vim.keymap.set("n", "<C-Left>", "<C-w>h", { desc = "Go to Left Window", remap = true })
vim.keymap.set("n", "<C-Right>", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- hop
vim.keymap.del("n", "<leader>wd") -- Remove the default <Space>wq mapping
vim.keymap.del("n", "<leader>wm") -- Remove the default <Space>wm mapping
vim.keymap.set("n", "<leader>w", "<cmd>HopWord<CR>", { desc = "Hop to a word" })
vim.keymap.set("n", "<leader>l", "<cmd>HopLine<CR>", { desc = "Hop to a line" })
-- vim.keymap.set("n", "<leader>f", "<cmd>HopChar1<CR>", { desc = "Hop to a character" })

-- Expand references preview with lspsaga
vim.keymap.set("n", "gh", "<cmd>Lspsaga finder ref<CR>", { desc = "Expand References Preview" })

-- Expand definition preview with lspsaga
vim.keymap.set("n", "gy", "<cmd>Lspsaga finder tyd<CR>", { desc = "Expand Definition Preview" })

vim.keymap.set("n", "gm", "<cmd>Lspsaga finder imp<CR>", { desc = "Expand Implementation Preview" })

-- Split window horizontally and open terminal
vim.keymap.set("n", "<C-w>t", "<cmd>vsplit | terminal<cr>", { desc = "Split window horizontally and open terminal" })

vim.keymap.set({ "n", "v" }, "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<Leader>a", "<cmd>CodeCompanionChat Toggle<cr>", { noremap = true, silent = true })
vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

vim.keymap.set("v", "<leader>cx", function()
  vim.cmd("'<,'>yank +")
  vim.fn.system("codesnap --from-clipboard -o clipboard")
end, { desc = "Yank and codesnap" })

-- Mapping '<Leader>cc' to toggle BaleiaColorize
vim.keymap.set("n", "<Leader>cc", "<cmd>BaleiaColorize<CR>", { desc = "Toggle BaleiaColorize" })

-- Expand 'cc' into 'CodeCompanion' in the command line
vim.cmd([[cab cc CodeCompanion]])

-- Mapping Tab to jump to the matching bracket
vim.api.nvim_set_keymap("n", "<Tab>", "%", { noremap = true, silent = true })

-- Increase font size
vim.keymap.set("n", "<C-=>", function()
  local size = vim.o.guifont:match("%d+")
  vim.o.guifont = vim.o.guifont:gsub("%d+", size + 1)
end, { desc = "Increase font size" })

-- Decrease font size
vim.keymap.set("n", "<C-->", function()
  local size = vim.o.guifont:match("%d+")
  vim.o.guifont = vim.o.guifont:gsub("%d+", size - 1)
end, { desc = "Decrease font size" })

vim.keymap.set("x", "<leader>cwo", 'c`<C-r>"`<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with ``",
})

vim.keymap.set("x", "<leader>cwc", 'c\\code{<C-r>"}<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with \\code{}",
})

vim.keymap.set("x", "<leader>cwC", 'c\\tcode{<C-r>"}<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with \\tcode{}",
})

-- Lspsaga outline
vim.keymap.set("n", "<leader>co", "<cmd>Lspsaga outline<CR>", { desc = "Open Lspsaga Outline" })

-- Hint file
vim.keymap.set("n", "<leader>ch", function()
  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    vim.notify("没有打开的文件。", vim.log.levels.WARN)
    return
  end

  local git_dir = vim.fn.finddir(".git", ".;")
  if not git_dir or git_dir == "" then
    vim.notify("不在 git 仓库中。", vim.log.levels.WARN)
    return
  end
  local git_root = vim.fn.fnamemodify(git_dir, ":h")

  local file_basename = vim.fn.fnamemodify(current_file, ":t:r")
  local hint_file = git_root .. "/.audit-copilot/" .. file_basename .. ".hint.md"

  if vim.fn.filereadable(hint_file) == 0 then
    vim.notify("Hint 文件未找到: " .. hint_file, vim.log.levels.INFO)
    return
  end

  -- Save the current window ID to return focus later
  -- vim.api.nvim_get_current_win()

  -- Open the hint file in a new vertical split. `botright` opens it on the far right.
  vim.cmd("botright vsplit " .. vim.fn.fnameescape(hint_file))

  -- Return focus to the original window
  -- vim.api.nvim_set_current_win(original_win_id)

  -- Execute Lspsaga outline from the original buffer's context
  vim.cmd("Lspsaga outline")
end, { desc = "打开 Hint 文件和 Lspsaga outline" })

vim.keymap.set("n", "<leader>cH", function()
  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    vim.notify("没有打开的文件。", vim.log.levels.WARN)
    return
  end

  local git_dir = vim.fn.finddir(".git", ".;")
  if not git_dir or git_dir == "" then
    vim.notify("不在 git 仓库中。", vim.log.levels.WARN)
    return
  end
  local git_root = vim.fn.fnamemodify(git_dir, ":h")

  local file_basename = vim.fn.fnamemodify(current_file, ":t:r")
  local hint_file = git_root .. "/.audit-copilot/" .. file_basename .. ".hint.md"

  if vim.fn.filereadable(hint_file) == 0 then
    vim.notify("Hint 文件未找到: " .. hint_file, vim.log.levels.INFO)
    return
  end

  local content = vim.fn.readfile(hint_file)

  -- Create a scratch buffer to display the hint content
  local buf = vim.api.nvim_create_buf(false, true)
  -- vim.api.(buf, "filetype", "markdown")
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false -- Make the buffer read-only

  -- Configure the floating window
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.7)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

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
end, { desc = "Open hint file (read only) and Lspsaga outline" })

-- Code yank
vim.keymap.set("x", "<leader>cy", function()
  -- Get the line numbers for the start and end of the last visual selection.
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  -- Re-select the last visual area and yank it.
  vim.cmd("normal! gvy")
  local selection = vim.fn.getreg('"')

  -- Get buffer metadata.
  local filename = vim.fn.expand("%:t")
  local lang = vim.bo.filetype

  if filename == "" then
    filename = "untitled"
  end
  if lang == "" then
    lang = "text"
  end

  -- Format the line-range string.
  local line_range
  if start_line == end_line then
    line_range = start_line
  else
    line_range = string.format("%d-%d", start_line, end_line)
  end

  -- Prepend line numbers to the selection.
  local lines = vim.fn.split(selection, "\n")
  local numbered_lines = {}
  local max_line_width = #tostring(end_line)
  for i, line in ipairs(lines) do
    local line_num = start_line + i - 1
    local formatted_line = string.format("%" .. max_line_width .. "d|  %s", line_num, line)
    table.insert(numbered_lines, formatted_line)
  end
  local numbered_selection = table.concat(numbered_lines, "\n")

  -- Construct the content with the new header including line numbers.
  local header = string.format("/// %s:%s", filename, line_range)
  local content = string.format("```%s\n %s\n%s\n```", lang, header, numbered_selection)

  -- Set the system clipboard and show a notification.
  vim.fn.setreg("+", content)
  vim.fn.setreg("*", content) -- For Linux systems using the primary selection
  vim.fn.setreg("", content) -- Also set the default register
  vim.notify("Copied to clipboard with context", vim.log.levels.INFO, { title = "Code Yank" })
end, { desc = "Yank code with file, language, and line number context" })

-- Code Mark
-- vim.keymap.set("x", "<leader>cm", function()
--   -- Get the start and end line numbers of the visual selection (1-based).
--   local start_line, end_line = vim.fn.line("'<"), vim.fn.line("'>")
--
--   -- Read the selected lines from the current buffer.
--   -- API functions use 0-based line numbers, so we subtract 1.
--   local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
--
--   local new_lines = {}
--   for _, line in ipairs(lines) do
--     -- For each line, replace a pattern like "95|" with "95|>".
--     -- The pattern description:
--     -- ^        - Anchor to the start of the line.
--     -- (%s*%d+) - Capture group 1: zero or more whitespace chars followed by one or more digits.
--     -- |        - A literal pipe character.
--     -- The replacement string "%1|>" uses the captured number.
--     table.insert(new_lines, (string.gsub(line, "^(%s*%d+)| ", "%1|>")))
--   end
--
--   -- Write the modified lines back to the buffer in a single operation.
--   vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
-- end, { desc = "Mark code with '>'" })

-- Code ignore comment
vim.keymap.set("x", "<leader>cd", "di //...<Esc>", { desc = "Comment selection with //" })
