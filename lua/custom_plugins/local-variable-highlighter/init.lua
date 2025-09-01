local M = {}

-- 存储高亮状态
local state = {
  -- { word = { match_id = 123, hl_group = "CursorWordHighlight1" } }
  highlighted_words = {},
  -- 可用的高亮组列表
  hl_groups = {},
  -- 下一个可用高亮组的索引
  next_hl_group_idx = 1,
}

-- 预定义的高亮颜色 (背景色)
local colors = {
  { bg = "#5f8787", fg = "#ffffff" },
  { bg = "#875f87", fg = "#ffffff" },
  { bg = "#87875f", fg = "#ffffff" },
  { bg = "#5f5f87", fg = "#ffffff" },
  { bg = "#5f875f", fg = "#ffffff" },
  { bg = "#875f5f", fg = "#ffffff" },
}

-- 定义高亮组
local function define_hl_groups()
  for i, color in ipairs(colors) do
    local group_name = "CursorWordHighlight" .. i
    vim.api.nvim_set_hl(0, group_name, { bg = color.bg, fg = color.fg, bold = true })
    table.insert(state.hl_groups, group_name)
  end
end

-- 高亮光标下的单词
function M.highlight_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word == "" or state.highlighted_words[word] then
    return
  end

  local hl_group = state.hl_groups[state.next_hl_group_idx]
  -- 使用 '\\V' 来确保单词按字面意思匹配，并用 \<\> 来匹配整个单词
  local pattern = table.concat({ [[\V\<]], word, [[\>]] })
  vim.cmd("echo 'Highlighting word: " .. word .. " with group: " .. hl_group .. "'")
  local match_id = vim.fn.matchadd(hl_group, pattern, 100)

  state.highlighted_words[word] = { match_id = match_id, hl_group = hl_group }

  -- 循环使用高亮组
  state.next_hl_group_idx = state.next_hl_group_idx % #state.hl_groups + 1
end

-- 清除光标下单词的高亮
function M.clear_highlight_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word == "" or not state.highlighted_words[word] then
    return
  end

  local highlight_info = state.highlighted_words[word]
  vim.fn.matchdelete(highlight_info.match_id)
  state.highlighted_words[word] = nil
end

-- 清除所有高亮
function M.clear_all_highlights()
  for word, highlight_info in pairs(state.highlighted_words) do
    vim.fn.matchdelete(highlight_info.match_id)
  end
  state.highlighted_words = {}
  state.next_hl_group_idx = 1
end

-- 设置函数，用于创建快捷键
function M.setup()
  define_hl_groups()

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
