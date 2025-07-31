-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- =======================================================================
-- 警告：这是一个非标准的键位绑定，会彻底改变 Vim 的核心导航和编辑模式。
-- 使用 j, k, l, i 模拟方向键, 使用 h 进入插入模式
-- =======================================================================

-- -- 在普通模式和可视模式下, 'i' 键现在的功能是向左移动光标。
-- vim.keymap.set({ "n", "v" }, "i", "<Left>", { noremap = true, desc = "Move Left" })
--
-- -- 在普通模式和可视模式下, 'j' 键的功能是向下移动光标。
-- vim.keymap.set({ "n", "v" }, "j", "<Down>", { noremap = true, desc = "Move Down" })
--
-- -- 在普通模式和可视模式下, 'k' 键的功能是向上移动光标。
-- vim.keymap.set({ "n", "v" }, "k", "<Up>", { noremap = true, desc = "Move Up" })
--
-- -- 在普通模式和可视模式下, 'l' 键的功能是向右移动光标。
-- -- 注意：'l' 在普通模式下已具备此功能，这里为了统一性而显式设置。
-- vim.keymap.set({ "n", "v" }, "l", "<Right>", { noremap = true, desc = "Move Right" })
--
-- -- 'h' 键现在取代了 'i' 的原始功能：进入插入模式。
-- -- 原本的 'h' (向左移动) 的功能已被上面的 'i' 键映射所取代。
-- vim.keymap.set("n", "h", "i", { noremap = true, desc = "Enter Insert Mode" })

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

vim.keymap.set("x", "<leader>wc", 'c\\code{<C-r>"}<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with \\code{}",
})

vim.keymap.set("x", "<leader>wC", 'c\\tcode{<C-r>"}<Esc>', {
  noremap = true,
  silent = true,
  desc = "Wrap selection with \\tcode{}",
})
