local M = {}

-- 存储高亮状态
local state = {
  -- 使用 [bufnr][winid] 结构隔离状态
  -- 结构: { [bufnr] = { [winid] = { highlighted_words = {}, available_hl_groups = {} } } }
  contexts = {},
  -- 所有已定义的高亮组 (全局共享)
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

-- 定义高亮组
local function define_hl_groups()
  local colors = vim.o.background == "dark" and dark_colors or light_colors
  state.all_hl_groups = {}
  for i, color in ipairs(colors) do
    local group_name = "CursorWordHighlight" .. i
    vim.api.nvim_set_hl(0, group_name, { bg = color.bg, fg = color.fg, bold = true })
    table.insert(state.all_hl_groups, group_name)
  end
end

-- 获取或初始化当前 Buffer 和 Window 的高亮上下文
local function get_context(bufnr, winid)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winid = winid or vim.api.nvim_get_current_win()

  if not state.contexts[bufnr] then
    state.contexts[bufnr] = {}
  end

  if not state.contexts[bufnr][winid] then
    state.contexts[bufnr][winid] = {
      highlighted_words = {},
      -- 每个窗口上下文拥有独立的可用高亮组队列
      available_hl_groups = vim.deepcopy(state.all_hl_groups),
    }
  end

  return state.contexts[bufnr][winid], bufnr, winid
end

-- 高亮视觉模式下选择的文本
function M.highlight_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line_num, start_col = start_pos[2], start_pos[3]
  local end_line_num, end_col = end_pos[2], end_pos[3]

  if start_line_num ~= end_line_num then
    vim.notify("不支持多行高亮。", vim.log.levels.WARN)
    return
  end

  local line = vim.api.nvim_buf_get_lines(0, start_line_num - 1, start_line_num, false)[1]
  if not line then
    return
  end
  local selection = string.sub(line, start_col, end_col)

  local ctx = get_context()

  if selection == "" or ctx.highlighted_words[selection] then
    return
  end

  local hl_group = table.remove(ctx.available_hl_groups, 1)
  if not hl_group then
    vim.notify("No more highlight groups available.", vim.log.levels.WARN)
    return
  end

  -- 使用 '\\V' 来确保按字面意思匹配, 并转义特殊字符
  local pattern = [[\V]] .. vim.fn.escape(selection, [[\ ]])
  local match_id = vim.fn.matchadd(hl_group, pattern, 100)

  ctx.highlighted_words[selection] = { match_id = match_id, hl_group = hl_group }
end

-- 高亮光标下的单词
function M.highlight_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  local ctx = get_context()

  if word == "" or ctx.highlighted_words[word] then
    return
  end

  -- 从当前上下文的池中获取一个可用的高亮组
  local hl_group = table.remove(ctx.available_hl_groups, 1)
  if not hl_group then
    vim.notify("No more highlight groups available.", vim.log.levels.WARN)
    return
  end

  -- 使用 '\\V' 来确保单词按字面意思匹配，并用 \<\> 来匹配整个单词
  local pattern = table.concat({ [[\V\<]], word, [[\>]] })
  local match_id = vim.fn.matchadd(hl_group, pattern, 100)

  ctx.highlighted_words[word] = {
    match_id = match_id,
    hl_group = hl_group,
  }
end

-- 清除光标下单词的高亮
function M.clear_highlight_under_cursor()
  local word = vim.fn.expand("<cword>")
  local ctx, _, winid = get_context()

  if word == "" or not ctx.highlighted_words[word] then
    return
  end

  local highlight_info = ctx.highlighted_words[word]

  -- 尝试删除匹配项
  pcall(vim.fn.matchdelete, highlight_info.match_id, winid)

  -- 将高亮组归还到当前上下文的可用池中
  table.insert(ctx.available_hl_groups, highlight_info.hl_group)

  ctx.highlighted_words[word] = nil
end

-- 清除当前窗口的所有高亮
function M.clear_current_window_highlights()
  local ctx, _, winid = get_context()

  for _, highlight_info in pairs(ctx.highlighted_words) do
    pcall(vim.fn.matchdelete, highlight_info.match_id, winid)
  end

  ctx.highlighted_words = {}
  -- 重置当前窗口的可用高亮组
  ctx.available_hl_groups = vim.deepcopy(state.all_hl_groups)
end

-- 重置所有上下文（用于 ColorScheme 变更）
function M.reset_all_contexts()
  for bufnr, win_list in pairs(state.contexts) do
    for winid, ctx in pairs(win_list) do
      if vim.api.nvim_win_is_valid(winid) then
        for _, highlight_info in pairs(ctx.highlighted_words) do
          pcall(vim.fn.matchdelete, highlight_info.match_id, winid)
        end
      end
    end
  end
  state.contexts = {}
end

function M.show_status()
  local ctx = get_context()
  local used_count = 0
  for _ in pairs(ctx.highlighted_words) do
    used_count = used_count + 1
  end
  local total_count = #state.all_hl_groups
  local available_count = #ctx.available_hl_groups

  vim.notify(
    string.format(
      "Highlight Status (Current Window): Used %d / Available %d (Total %d)",
      used_count,
      available_count,
      total_count
    ),
    vim.log.levels.INFO
  )
end

-- 设置函数，用于创建快捷键
function M.setup()
  define_hl_groups()

  -- 当配色方案改变时，重新定义高亮组并清除所有上下文高亮
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      define_hl_groups()
      M.reset_all_contexts()
    end,
  })

  vim.keymap.set("n", "<leader>hh", M.highlight_word_under_cursor, { silent = true, desc = "高亮光标下的单词" })
  vim.keymap.set("v", "<leader>hh", M.highlight_visual_selection, { silent = true, desc = "高亮选中的文本" })
  vim.keymap.set(
    "n",
    "<leader>hc",
    M.clear_highlight_under_cursor,
    { silent = true, desc = "清除光标下单词的高亮" }
  )
  -- 更改快捷键行为：仅清除当前窗口/Buffer的高亮
  vim.keymap.set(
    "n",
    "<leader>hC",
    M.clear_current_window_highlights,
    { silent = true, desc = "清除当前窗口高亮" }
  )
  vim.keymap.set("n", "<leader>hs", M.show_status, { silent = true, desc = "显示高亮状态" })
end

return M
