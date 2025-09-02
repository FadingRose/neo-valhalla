local M = {}

-- 存储高亮状态
local state = {
  -- { word = { match_id = 123, hl_group = "CursorWordHighlight1" } }
  highlighted_words = {},
  -- 可用的高亮组列表 (作为队列使用)
  available_hl_groups = {},
  -- 所有已定义的高亮组
  all_hl_groups = {},
}

-- 为暗色背景预定义的高亮颜色
local dark_colors = {
  { bg = "#5f8787", fg = "#ffffff" },
  { bg = "#875f87", fg = "#ffffff" },
  { bg = "#87875f", fg = "#ffffff" },
  { bg = "#5f5f87", fg = "#ffffff" },
  { bg = "#5f875f", fg = "#ffffff" },
  { bg = "#875f5f", fg = "#ffffff" },
}

-- 为亮色背景预定义的高亮颜色
local light_colors = {
  { bg = "#a0d1d1", fg = "#000000" },
  { bg = "#d1a0d1", fg = "#000000" },
  { bg = "#d1d1a0", fg = "#000000" },
  { bg = "#a0a0d1", fg = "#000000" },
  { bg = "#a0d1a0", fg = "#000000" },
  { bg = "#d1a0a0", fg = "#000000" },
}

-- 定义高亮组并初始化状态
local function define_hl_groups()
  local colors = vim.o.background == "dark" and dark_colors or light_colors
  state.all_hl_groups = {}
  for i, color in ipairs(colors) do
    local group_name = "CursorWordHighlight" .. i
    vim.api.nvim_set_hl(0, group_name, { bg = color.bg, fg = color.fg, bold = true })
    table.insert(state.all_hl_groups, group_name)
  end
  -- 重置可用高亮组
  state.available_hl_groups = vim.deepcopy(state.all_hl_groups)
end

-- 高亮光标下的单词
function M.highlight_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word == "" or state.highlighted_words[word] then
    return
  end

  -- 从池中获取一个可用的高亮组
  local hl_group = table.remove(state.available_hl_groups, 1)
  if not hl_group then
    vim.notify("No more highlight groups available.", vim.log.levels.WARN)
    return
  end

  -- 使用 '\\V' 来确保单词按字面意思匹配，并用 \<\> 来匹配整个单词
  local pattern = table.concat({ [[\V\<]], word, [[\>]] })
  local match_id = vim.fn.matchadd(hl_group, pattern, 100)

  state.highlighted_words[word] = { match_id = match_id, hl_group = hl_group }
end

-- 清除光标下单词的高亮
function M.clear_highlight_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word == "" or not state.highlighted_words[word] then
    return
  end

  local highlight_info = state.highlighted_words[word]
  vim.fn.matchdelete(highlight_info.match_id)

  -- 将高亮组归还到可用池中
  table.insert(state.available_hl_groups, highlight_info.hl_group)

  state.highlighted_words[word] = nil
end

-- 清除所有高亮
function M.clear_all_highlights()
  for _, highlight_info in pairs(state.highlighted_words) do
    vim.fn.matchdelete(highlight_info.match_id)
  end
  state.highlighted_words = {}
  -- 将所有高亮组重置为可用
  state.available_hl_groups = vim.deepcopy(state.all_hl_groups)
end

-- 设置函数，用于创建快捷键
function M.setup()
  define_hl_groups()

  -- 当配色方案改变时，重新定义高亮组并清除现有高亮
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      define_hl_groups()
      M.clear_all_highlights()
    end,
  })

  vim.keymap.set("n", "<leader>hh", M.highlight_word_under_cursor, { silent = true, desc = "高亮光标下的单词" })
  vim.keymap.set(
    "n",
    "<leader>hc",
    M.clear_highlight_under_cursor,
    { silent = true, desc = "清除光标下单词的高亮" }
  )
  vim.keymap.set("n", "<leader>hC", M.clear_all_highlights, { silent = true, desc = "清除所有高亮" })
end

return M
