-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- vim.keymap.set("n", "<leader>td", function()
--   require("custom_plugins.todo").open_today_todo_popup()
-- end, { desc = "Open Today's Todos" })

-- vim.keymap.set("n", "<leader>tl", function()
--   require("telescope.builtin").find_files({
--     prompt_title = "Todo Files",
--     cwd = require("custom_plugins.todo").tododir,
--     hidden = true, -- Show hidden files
--     find_command = { "rg", "--files", "--hidden", "--glob", "!*.git" }, -- Exclude .git directory
--   })
-- end, { desc = "Open Todo Files" })

vim.keymap.del("n", "<leader>.")
-- vim.keymap.del("n", "<leader>,")
-- vim.keymap.del("n", "<leader>`")

-- { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
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

vim.keymap.set("x", "<leader>cwb", 'c\\textbf{<C-r>"}<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with \\textbf{}",
})

vim.keymap.set("x", "<leader>cwt", 'c\\texttt{<C-r>"}<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with \\texttt{}",
})
-- Lspsaga outline
vim.keymap.set("n", "<leader>co", "<cmd>Lspsaga outline<CR>", { desc = "Open Lspsaga Outline" })

local function yank_with_context()
  -- 2. 从寄存器中提取 yank 的内容
  local selection = vim.fn.getreg('"')

  -- 从 '< 和 '> 标记中获取行号，这些标记是由 yank 操作设置的
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  -- 3. 处理 content
  -- 获取缓冲区元数据
  local filename = vim.fn.expand("%:t")
  if filename == "" then
    filename = "untitled"
  end

  local lang = vim.bo.filetype
  if lang == "" then
    lang = "text"
  end

  -- 格式化行号范围字符串
  local line_range
  if start_line == end_line then
    line_range = tostring(start_line)
  else
    line_range = string.format("%d-%d", start_line, end_line)
  end

  -- 为选中区域的每一行添加行号
  local lines = vim.fn.split(selection, "\n")

  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  local numbered_lines = {}
  local max_line_width = #tostring(end_line)
  for i, line in ipairs(lines) do
    local line_num = start_line + i - 1
    local formatted_line = string.format("%" .. max_line_width .. "d|  %s", line_num, line)
    table.insert(numbered_lines, formatted_line)
  end
  local numbered_selection = table.concat(numbered_lines, "\n")

  -- 构建包含上下文的最终内容
  local header = string.format("/// %s:%s", filename, line_range)
  local content = string.format("```%s\n %s\n%s\n```", lang, header, numbered_selection)

  -- 4. 写回寄存器
  vim.fn.setreg("+", content)
  vim.fn.setreg("*", content)
  vim.fn.setreg('"', content)
  vim.notify("Copied to clipboard with context", vim.log.levels.INFO, { title = "Code Yank" })
end

_G.yank_with_context_for_mapping = yank_with_context

vim.keymap.set("x", "<leader>cy", "y<Cmd>lua _G.yank_with_context_for_mapping()<CR>", {
  noremap = true,
  silent = true,
  desc = "Yank code with file, language, and line number context",
})

-- Code ignore comment
vim.keymap.set("x", "<leader>cd", "di //...<Esc>", { desc = "Comment selection with //" })

-- Copy current file path to clipboard
vim.api.nvim_set_keymap(
  "n",
  "<leader>bc",
  ':let @+=expand("%:p")<CR>',
  { noremap = true, silent = true, desc = "Copy current file path to clipboard" }
)

local function clear_markdown_formatting()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local start_col = vim.fn.col("'<")
  local end_col = vim.fn.col("'>")

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local new_lines = {}
  for i, line in ipairs(lines) do
    local modified_line = line:gsub("`", ""):gsub("%*", "")
    table.insert(new_lines, modified_line)
  end

  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)

  -- Re-select the changed text to keep visual mode active
  vim.cmd("normal! gv")
end

vim.keymap.set("x", "<leader>cr", clear_markdown_formatting, {
  noremap = true,
  silent = true,
  desc = "Clear Markdown inline code and bold formatting",
})

local audit_mind = require("custom_plugins.auditscope.mind")
vim.keymap.set({ "n", "v" }, "<leader>3h", function()
  audit_mind.new_node("hypothesis")
end, { desc = "Audit: New Hypothesis" })

vim.keymap.set({ "n", "v" }, "<leader>3f", function()
  audit_mind.new_node("fact")
end, { desc = "Audit: New Fact" })

vim.keymap.set({ "n", "v" }, "<leader>3i", function()
  audit_mind.new_node("insight")
end, { desc = "Audit: New Insight" })

vim.keymap.set({ "n", "v" }, "<leader>3q", function()
  audit_mind.new_node("question")
end, { desc = "Audit: New Question" })

vim.keymap.set("n", "<leader>3M", function()
  audit_mind.open_dashboard()
end, { desc = "Audit: Mind Map" })

vim.keymap.set("n", "<leader>3m", function()
  audit_mind.modify_node()
end, { desc = "Audit: Modify Node" })

vim.keymap.set("n", "<leader>3d", function()
  audit_mind.delete_node()
end, { desc = "Audit: Delete Node" })
