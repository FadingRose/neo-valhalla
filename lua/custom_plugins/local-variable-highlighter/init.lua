local M = {}

local MAX_COLORS = 48
local HUE_STEP = 137.5
local MIX_STRENGTH = 0.30
local ADAPT_GROUPS = { "Normal", "Identifier", "Function" }

-- 存储高亮状态
local state = {
  -- 使用 [bufnr] 结构共享同一 Buffer 的高亮状态
  -- 结构: { [bufnr] = { highlighted_words = {}, available_hl_groups = {} } }
  contexts = {},
  -- 所有已定义的高亮组 (全局共享)
  all_hl_groups = {},
}

local function clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end

local function hsl_to_rgb(h, s, l)
  local c = (1 - math.abs(2 * l - 1)) * s
  local h_prime = (h % 360) / 60
  local x = c * (1 - math.abs((h_prime % 2) - 1))
  local r1, g1, b1 = 0, 0, 0

  if h_prime < 1 then
    r1, g1, b1 = c, x, 0
  elseif h_prime < 2 then
    r1, g1, b1 = x, c, 0
  elseif h_prime < 3 then
    r1, g1, b1 = 0, c, x
  elseif h_prime < 4 then
    r1, g1, b1 = 0, x, c
  elseif h_prime < 5 then
    r1, g1, b1 = x, 0, c
  else
    r1, g1, b1 = c, 0, x
  end

  local m = l - c / 2
  local r = math.floor((r1 + m) * 255 + 0.5)
  local g = math.floor((g1 + m) * 255 + 0.5)
  local b = math.floor((b1 + m) * 255 + 0.5)

  return r, g, b
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

local function hl_to_rgb(value)
  if not value then
    return nil
  end
  local r = math.floor(value / 65536) % 256
  local g = math.floor(value / 256) % 256
  local b = value % 256
  return r, g, b
end

local function collect_scheme_targets(groups)
  local targets = {}
  for _, group in ipairs(groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
    if ok and hl then
      if hl.fg then
        local r, g, b = hl_to_rgb(hl.fg)
        table.insert(targets, { r = r, g = g, b = b })
      end
      if hl.bg then
        local r, g, b = hl_to_rgb(hl.bg)
        table.insert(targets, { r = r, g = g, b = b })
      end
    end
  end

  return targets
end

local function blend_channel(a, b, amount)
  return math.floor(a + (b - a) * amount + 0.5)
end

local function blend_rgb(r, g, b, target, amount)
  if not target or amount <= 0 then
    return r, g, b
  end

  return blend_channel(r, target.r, amount),
    blend_channel(g, target.g, amount),
    blend_channel(b, target.b, amount)
end

local function relative_luminance(r, g, b)
  local function channel(value)
    local v = value / 255
    if v <= 0.03928 then
      return v / 12.92
    end
    return ((v + 0.055) / 1.055) ^ 2.4
  end

  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

local function pick_foreground(r, g, b)
  local luminance = relative_luminance(r, g, b)
  if luminance > 0.5 then
    return "#000000"
  end
  return "#ffffff"
end

local function generate_palette(count, background, hue_step, scheme_targets, mix_strength)
  local colors = {}
  local is_dark = background == "dark"
  local base_l = is_dark and 0.35 or 0.78
  local base_s = is_dark and 0.55 or 0.45
  local l_offsets = is_dark and { 0.00, 0.08, -0.08 } or { 0.00, 0.06, -0.06 }
  local s_offsets = is_dark and { 0.00, -0.08, 0.08 } or { 0.00, -0.05, 0.05 }
  local step = hue_step or HUE_STEP
  local mix = clamp(mix_strength or 0, 0, 1)
  local targets = scheme_targets or {}

  for i = 1, count do
    local hue = ((i - 1) * step) % 360
    local offset_index = ((i - 1) % #l_offsets) + 1
    local l = clamp(base_l + l_offsets[offset_index], 0.18, 0.85)
    local s = clamp(base_s + s_offsets[offset_index], 0.25, 0.85)
    local r, g, b = hsl_to_rgb(hue, s, l)
    if #targets > 0 and mix > 0 then
      local target = targets[((i - 1) % #targets) + 1]
      r, g, b = blend_rgb(r, g, b, target, mix)
    end
    local bg = rgb_to_hex(r, g, b)
    local fg = pick_foreground(r, g, b)
    table.insert(colors, { bg = bg, fg = fg })
  end

  return colors
end

-- 定义高亮组
local function define_hl_groups()
  local scheme_targets = collect_scheme_targets(ADAPT_GROUPS)
  local colors = generate_palette(MAX_COLORS, vim.o.background, HUE_STEP, scheme_targets, MIX_STRENGTH)
  state.all_hl_groups = {}
  for i, color in ipairs(colors) do
    local group_name = "CursorWordHighlight" .. i
    vim.api.nvim_set_hl(0, group_name, { bg = color.bg, fg = color.fg, bold = true })
    table.insert(state.all_hl_groups, group_name)
  end
end

-- 获取或初始化当前 Buffer 的高亮上下文
local function get_buffer_context(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not state.contexts[bufnr] then
    state.contexts[bufnr] = {
      highlighted_words = {},
      highlight_order = {},
      -- 同一 Buffer 共享可用高亮组队列
      available_hl_groups = vim.deepcopy(state.all_hl_groups),
    }
  end

  return state.contexts[bufnr], bufnr
end

local function remove_from_order(ctx, word)
  for i, value in ipairs(ctx.highlight_order) do
    if value == word then
      table.remove(ctx.highlight_order, i)
      return
    end
  end
end

local function remove_word(ctx, word, opts)
  if not word then
    return nil
  end

  local highlight_info = ctx.highlighted_words[word]
  if not highlight_info then
    return nil
  end

  for winid, match_id in pairs(highlight_info.match_ids or {}) do
    if vim.api.nvim_win_is_valid(winid) then
      pcall(vim.fn.matchdelete, match_id, winid)
    end
  end

  ctx.highlighted_words[word] = nil
  remove_from_order(ctx, word)

  if opts and opts.recycle then
    table.insert(ctx.available_hl_groups, highlight_info.hl_group)
  end

  return highlight_info.hl_group
end

local function allocate_hl_group(ctx)
  local hl_group = table.remove(ctx.available_hl_groups, 1)
  if hl_group then
    return hl_group
  end

  local oldest_word = ctx.highlight_order[1]
  if not oldest_word then
    return nil
  end

  return remove_word(ctx, oldest_word)
end

local function list_buffer_windows(bufnr)
  local ok, wins = pcall(vim.fn.win_findbuf, bufnr)
  if not ok or not wins then
    return {}
  end
  return wins
end

local function add_match_to_window(winid, hl_group, pattern)
  if not vim.api.nvim_win_is_valid(winid) then
    return nil
  end

  local ok, match_id = pcall(vim.api.nvim_win_call, winid, function()
    return vim.fn.matchadd(hl_group, pattern, 100)
  end)

  if not ok then
    return nil
  end

  return match_id
end

local function sync_window_highlights(ctx, winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end

  for _, highlight_info in pairs(ctx.highlighted_words) do
    highlight_info.match_ids = highlight_info.match_ids or {}
    if not highlight_info.match_ids[winid] then
      local match_id = add_match_to_window(winid, highlight_info.hl_group, highlight_info.pattern)
      if match_id then
        highlight_info.match_ids[winid] = match_id
      end
    end
  end
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

  local ctx, bufnr = get_buffer_context()

  if selection == "" or ctx.highlighted_words[selection] then
    return
  end

  local hl_group = allocate_hl_group(ctx)
  if not hl_group then
    vim.notify("No more highlight groups available.", vim.log.levels.WARN)
    return
  end

  -- 使用 '\\V' 来确保按字面意思匹配, 并转义特殊字符
  local pattern = [[\V]] .. vim.fn.escape(selection, [[\ ]])
  local match_ids = {}
  for _, winid in ipairs(list_buffer_windows(bufnr)) do
    local match_id = add_match_to_window(winid, hl_group, pattern)
    if match_id then
      match_ids[winid] = match_id
    end
  end

  ctx.highlighted_words[selection] = {
    match_ids = match_ids,
    hl_group = hl_group,
    pattern = pattern,
  }
  table.insert(ctx.highlight_order, selection)
end

-- 高亮光标下的单词
function M.highlight_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  local ctx, bufnr = get_buffer_context()

  if word == "" or ctx.highlighted_words[word] then
    return
  end

  -- 从当前上下文的池中获取一个可用的高亮组
  local hl_group = allocate_hl_group(ctx)
  if not hl_group then
    vim.notify("No more highlight groups available.", vim.log.levels.WARN)
    return
  end

  -- 使用 '\\V' 来确保单词按字面意思匹配，并用 \<\> 来匹配整个单词
  local pattern = table.concat({ [[\V\<]], word, [[\>]] })
  local match_ids = {}
  for _, winid in ipairs(list_buffer_windows(bufnr)) do
    local match_id = add_match_to_window(winid, hl_group, pattern)
    if match_id then
      match_ids[winid] = match_id
    end
  end

  ctx.highlighted_words[word] = {
    match_ids = match_ids,
    hl_group = hl_group,
    pattern = pattern,
  }
  table.insert(ctx.highlight_order, word)
end

-- 清除光标下单词的高亮
function M.clear_highlight_under_cursor()
  local word = vim.fn.expand("<cword>")
  local ctx = get_buffer_context()

  if word == "" or not ctx.highlighted_words[word] then
    return
  end

  remove_word(ctx, word, { recycle = true })
end

-- 清除当前 Buffer 的所有高亮
function M.clear_current_window_highlights()
  local ctx = get_buffer_context()

  local words = {}
  for word in pairs(ctx.highlighted_words) do
    table.insert(words, word)
  end
  for _, word in ipairs(words) do
    remove_word(ctx, word)
  end

  ctx.highlighted_words = {}
  -- 重置当前窗口的可用高亮组
  ctx.available_hl_groups = vim.deepcopy(state.all_hl_groups)
  ctx.highlight_order = {}
end

-- 重置所有上下文（用于 ColorScheme 变更）
function M.reset_all_contexts()
  for _, ctx in pairs(state.contexts) do
    for _, highlight_info in pairs(ctx.highlighted_words) do
      for winid, match_id in pairs(highlight_info.match_ids or {}) do
        if vim.api.nvim_win_is_valid(winid) then
          pcall(vim.fn.matchdelete, match_id, winid)
        end
      end
    end
  end
  state.contexts = {}
end

function M.show_status()
  local ctx = get_buffer_context()
  local used_count = 0
  for _ in pairs(ctx.highlighted_words) do
    used_count = used_count + 1
  end
  local total_count = #state.all_hl_groups
  local available_count = #ctx.available_hl_groups

  vim.notify(
    string.format(
      "Highlight Status (Current Buffer): Used %d / Available %d (Total %d)",
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

  -- 当同一 Buffer 在新窗口中出现时，同步已有高亮
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "WinEnter" }, {
    pattern = "*",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local winid = vim.api.nvim_get_current_win()
      local ctx = state.contexts[bufnr]
      if not ctx then
        return
      end
      sync_window_highlights(ctx, winid)
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
  -- 更改快捷键行为：清除当前 Buffer 的高亮
  vim.keymap.set(
    "n",
    "<leader>hC",
    M.clear_current_window_highlights,
    { silent = true, desc = "清除当前 Buffer 高亮" }
  )
  vim.keymap.set("n", "<leader>hs", M.show_status, { silent = true, desc = "显示高亮状态" })
end

return M
