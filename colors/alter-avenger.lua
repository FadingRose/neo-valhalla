-- ~/.config/nvim/colors/alter-avenger.lua

-- 防止重复加载
if vim.g.colors_name then
  vim.cmd("hi clear")
end

-- 设置颜色方案名称
vim.g.colors_name = "alter-avenger-muted"

local M = {}

M.setup = function()
  -- 重置高亮，确保一个干净的初始状态
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.termguicolors = true -- 对真彩色支持至关重要

  --- 调色板
  -- @description
  -- 经过精心调整，以实现低饱和度和通过明度区分的视觉层级。
  -- 明度层级: 变量 > 类型 > 普通文本 > 关键字 > 注释
  local c = {
    -- 基础颜色
    bg = "#211B2B", -- 主背景 (与原版一致)
    bg_alt = "#2C243B", -- 次背景 (与原版一致)
    bg_darkest = "#1A1423", -- 最暗背景 (与原版一致)
    selection = "#483D59", -- 选区颜色 (与原版一致)
    cursorline = "#2A2235", -- 当前行背景色 (与原版一致)

    -- 前景与注释 (调整明度和对比度)
    fg = "#C5BACC", -- 普通前景文字，比原版稍亮一些作为基准
    comment = "#6E6281", -- 注释，更暗更融入背景
    line_nr = "#7A6F8A", -- 行号，比注释稍亮
    current_line_nr = "#C5BACC", -- 当前行号，与前景一致

    -- ===============================================
    -- 核心语法层级颜色 (变量 > 类型 > 关键字)
    -- ===============================================
    -- [1] 变量 (最高明度)
    fg_brightest = "#DDD6E9", -- 用于变量、函数名。非常亮，低饱和度，最突出

    -- [2] 类型 (中等明度)
    type_color = "#C8A9D9", -- 用于类型、常量。比普通文本亮，有轻微的色彩倾向

    -- [3] 关键字 (最低明度)
    keyword_color = "#988CAF", -- 用于关键字、语句。比普通文本暗，视觉上后退

    -- 其他高亮颜色 (全面降低饱和度)
    error_red = "#D98C8C", -- 柔和的、不刺眼的红色，用于错误和操作符
    string_yellow = "#E6DBA5", -- 柔和的、苍白的黄色，用于字符串
    number_orange = "#E8C4A9", -- 柔和的、像桃子一样的橙色，用于数字
    special_magenta = "#D1A7D6", -- 柔和的洋红，用于特殊符号、标题等

    -- UI 颜色
    ui_purple = "#9F83C4", -- 用于状态栏等UI元素的柔和紫色
    grey_light = "#CCCCCC", -- 浅灰色 (用于状态栏文字)
    grey_mid = "#9E9E9E", -- 中灰色 (用于特殊字符)
  }

  -- 设置高亮组的辅助函数
  local function hi(group, fg, bg, style)
    local cmd = "hi " .. group
    if fg then
      cmd = cmd .. " guifg=" .. fg
    else
      cmd = cmd .. " guifg=NONE"
    end
    if bg then
      cmd = cmd .. " guibg=" .. bg
    else
      cmd = cmd .. " guibg=NONE"
    end
    if style and style ~= "" then
      cmd = cmd .. " gui=" .. style
    end
    vim.cmd(cmd)
  end

  -- ===================================
  -- 编辑器 UI 高亮
  -- ===================================
  hi("Normal", c.fg, c.bg)
  hi("NormalNC", c.fg, c.bg_alt)
  hi("NormalFloat", c.fg, c.bg_alt)
  hi("FloatBorder", c.ui_purple, c.bg_alt)
  hi("LineNr", c.line_nr, c.bg)
  hi("CursorLineNr", c.current_line_nr, c.cursorline, "bold")
  hi("CursorLine", "NONE", c.cursorline)
  hi("Visual", "NONE", c.selection)
  hi("ColorColumn", "NONE", c.cursorline)
  hi("SignColumn", c.fg, c.bg)
  hi("VertSplit", c.bg_darkest, c.bg_darkest)
  hi("StatusLine", c.grey_light, c.ui_purple)
  hi("StatusLineNC", c.comment, c.bg_darkest)
  hi("Pmenu", c.fg, c.bg_alt)
  hi("PmenuSel", c.grey_light, c.selection)
  hi("PmenuThumb", c.fg, c.bg)
  hi("PmenuSbar", c.fg, c.bg_alt)
  hi("TabLine", c.comment, c.bg_alt)
  hi("TabLineFill", c.comment, c.bg_alt)
  hi("TabLineSel", c.grey_light, c.selection)

  -- ===================================
  -- 基础语法高亮 (层级: 变量 > 类型 > 关键字)
  -- ===================================
  hi("Comment", c.comment, "NONE", "italic")
  hi("Todo", c.special_magenta, c.bg_alt, "bold,underline")
  hi("Error", c.error_red, c.bg_alt, "underline")
  hi("Warning", c.string_yellow, "NONE")
  hi("Title", c.special_magenta, "NONE", "bold")
  hi("Directory", c.special_magenta, "NONE", "bold")

  -- [1] 变量/函数 (最突出)
  hi("Identifier", c.fg_brightest, "NONE") -- 变量名
  hi("Function", c.fg_brightest, "NONE", "bold") -- 函数名

  -- [2] 类型/常量 (次突出)
  hi("Type", c.type_color, "NONE", "italic") -- 类型 (int, string, bool)
  hi("StorageClass", c.type_color, "NONE") -- 存储类 (static, extern)
  hi("Structure", c.type_color, "NONE") -- 结构体 (struct, union)
  hi("Typedef", c.type_color, "NONE") -- 类型定义
  hi("Constant", c.type_color, "NONE") -- 常量
  hi("Boolean", c.type_color, "NONE", "bold") -- 布尔值

  -- [3] 关键字/语句 (最不突出)
  hi("Keyword", c.keyword_color, "NONE")
  hi("Statement", c.keyword_color, "NONE", "bold")
  hi("Conditional", c.keyword_color, "NONE", "bold")
  hi("Repeat", c.keyword_color, "NONE", "bold")
  hi("Label", c.keyword_color, "NONE")

  -- 其他
  hi("String", c.string_yellow, "NONE")
  hi("Number", c.number_orange, "NONE")
  hi("Float", c.number_orange, "NONE")
  hi("Operator", c.error_red, "NONE") -- 操作符使用柔和的红色

  -- 预处理器
  hi("PreProc", c.keyword_color, "NONE")
  hi("Include", c.keyword_color, "NONE")
  hi("Define", c.keyword_color, "NONE")
  hi("Macro", c.keyword_color, "NONE")

  -- 特殊
  hi("Special", c.special_magenta, "NONE") -- 特殊符号
  hi("SpecialKey", c.grey_mid, "NONE")
  hi("Underlined", c.fg, "NONE", "underline")
  hi("Ignore", c.comment, "NONE")

  -- ===================================
  -- 插件和 LSP 高亮
  -- ===================================
  -- 差异比较
  hi("DiffAdd", c.string_yellow, c.bg_alt)
  hi("DiffDelete", c.error_red, c.bg_alt)
  hi("DiffChange", c.number_orange, c.bg_alt)
  hi("DiffText", c.special_magenta, c.bg_alt)

  -- LSP
  hi("LspReferenceText", "NONE", c.selection)
  hi("LspReferenceRead", "NONE", c.selection)
  hi("LspReferenceWrite", "NONE", c.selection)
  hi("LspDiagnosticsDefaultError", c.error_red, "NONE")
  hi("LspDiagnosticsDefaultWarning", c.string_yellow, "NONE")
  hi("LspDiagnosticsDefaultInformation", c.type_color, "NONE")
  hi("LspDiagnosticsDefaultHint", c.grey_mid, "NONE")
  hi("LspDiagnosticsUnderlineError", c.error_red, "NONE", "underline")
  hi("LspDiagnosticsUnderlineWarning", c.string_yellow, "NONE", "underline")
  hi("LspDiagnosticsUnderlineInformation", c.type_color, "NONE", "underline")
  hi("LspDiagnosticsUnderlineHint", c.grey_mid, "NONE", "underline")
end

M.setup()

return M
