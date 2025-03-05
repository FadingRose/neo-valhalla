-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

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
