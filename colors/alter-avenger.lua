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
    -- bg_alt = "#211B2B", -- 主背景 (与原版一致)
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

  -- 链接现有高亮组
  hi("NonText", c.comment, "NONE")
  hi("EndOfBuffer", c.comment, "NONE")
  hi("Folded", c.comment, c.bg_alt, "italic")
  hi("Search", c.bg, c.string_yellow)
  hi("IncSearch", c.bg, c.number_orange)
  hi("MatchParen", c.bg_alt, c.selection, "bold")
  hi("Cursor", "NONE", c.fg)
  hi("lCursor", "NONE", c.fg)
  hi("TermCursor", "NONE", c.fg, "reverse")
  hi("CursorIM", "NONE", c.fg)
  hi("Whitespace", c.comment, "NONE")

  -- 消息和提示
  hi("ErrorMsg", c.error_red, "NONE", "bold")
  hi("WarningMsg", c.string_yellow, "NONE", "bold")
  hi("MoreMsg", c.special_magenta, "NONE")
  hi("Question", c.special_magenta, "NONE")
  hi("MsgArea", "NONE", "NONE")
  hi("MsgSeparator", c.comment, "NONE")

  -- Tree-sitter 高亮 (通用映射)
  hi("@variable", c.fg_brightest, "NONE")
  hi("@function", c.fg_brightest, "NONE", "bold")
  hi("@parameter", c.fg_brightest, "NONE", "italic")
  hi("@keyword", c.keyword_color, "NONE")
  hi("@string", c.string_yellow, "NONE")
  hi("@number", c.number_orange, "NONE")
  hi("@boolean", c.type_color, "NONE", "bold")
  hi("@type", c.type_color, "NONE", "italic")
  hi("@operator", c.error_red, "NONE")
  hi("@punctuation.delimiter", c.fg, "NONE")
  hi("@punctuation.bracket", c.fg, "NONE")
  hi("@comment", c.comment, "NONE", "italic")
  hi("@constant", c.type_color, "NONE")
  hi("@property", c.fg_brightest, "NONE")
  hi("@markup.heading", c.special_magenta, "NONE", "bold")
  hi("@markup.link", c.fg, "NONE", "underline")
  hi("@markup.raw", c.string_yellow, c.bg_alt)

  -- 插件特定高亮 (部分示例，根据实际需求添加)
  hi("WhichKeyFloat", c.fg, c.bg_alt)
  hi("WhichKeyBorder", c.ui_purple, c.bg_alt)
  hi("WhichKeyGroup", c.special_magenta, "NONE", "bold")
  hi("WhichKeyMatch", c.string_yellow, "NONE")
  hi("WhichKeyDesc", c.fg, "NONE")

  hi("TelescopePromptNormal", c.fg, c.bg)
  hi("TelescopePromptBorder", c.ui_purple, c.bg)
  hi("TelescopeResultsNormal", c.fg, c.bg_alt)
  hi("TelescopeResultsBorder", c.ui_purple, c.bg_alt)
  hi("TelescopePreviewNormal", c.fg, c.bg_alt)
  hi("TelescopePreviewBorder", c.ui_purple, c.bg_alt)
  hi("TelescopeMatching", c.string_yellow, "NONE", "bold")
  hi("TelescopeSelection", "NONE", c.selection)
  hi("TelescopeTitle", c.special_magenta, c.bg, "bold")

  hi("GitSignsAdd", c.string_yellow, "NONE")
  hi("GitSignsChange", c.number_orange, "NONE")
  hi("GitSignsDelete", c.error_red, "NONE")

  hi("NoiceCmdline", c.fg, c.bg)
  hi("NoiceCmdlinePopup", c.fg, c.bg_alt)
  hi("NoiceCmdlinePopupBorder", c.ui_purple, c.bg_alt)
  hi("NoicePopupmenu", c.fg, c.bg_alt)
  hi("NoicePopupmenuSelected", c.grey_light, c.selection)
  hi("NoiceConfirm", c.fg, c.bg_alt)
  hi("NoiceConfirmBorder", c.ui_purple, c.bg_alt)
  hi("NoiceMini", c.comment, "NONE")
  hi("NoiceFormatProgressDone", c.fg, c.number_orange)
  hi("NoiceFormatProgressTodo", c.comment, c.bg_darkest)

  hi("DapUIFloatNormal", c.fg, c.bg_alt)
  hi("DapUIFloatBorder", c.ui_purple, c.bg_alt)
  hi("DapUIScope", c.keyword_color, "NONE", "bold")
  hi("DapUIValue", c.fg, "NONE")
  hi("DapUIBreakpointsCurrentLine", c.current_line_nr, "NONE", "bold")
  hi("NvimDapVirtualText", c.comment, "NONE")

  hi("BufferLineFill", c.bg_darkest, c.bg_darkest)
  hi("BufferLineBuffer", c.comment, c.bg_alt)
  hi("BufferLineBufferSelected", c.grey_light, c.selection, "bold")
  hi("BufferLineTabSelected", c.grey_light, c.selection, "bold")
  hi("BufferLineSeparator", c.bg_darkest, c.bg_darkest)
  hi("BufferLineSeparatorSelected", c.ui_purple, c.selection)
  hi("BufferLineCloseButton", c.comment, c.bg_alt)
  hi("BufferLineCloseButtonSelected", c.grey_light, c.selection)
  hi("BufferLineModified", c.string_yellow, c.bg_alt)
  hi("BufferLineModifiedSelected", c.string_yellow, c.selection)
  hi("BufferLineErrorDiagnostic", c.error_red, c.bg_alt)
  hi("BufferLineWarningDiagnostic", c.string_yellow, c.bg_alt)
  hi("BufferLineInfoDiagnostic", c.type_color, c.bg_alt)
  hi("BufferLineHintDiagnostic", c.grey_mid, c.bg_alt)

  -- 其他常见高亮组
  hi("CursorColumn", "NONE", c.cursorline)
  hi("Conceal", c.comment, "NONE")
  hi("FoldColumn", c.comment, c.bg)
  hi("QuickFixLine", c.special_magenta, c.bg_alt, "bold")
  hi("SpellBad", "NONE", "NONE", "undercurl", c.error_red)
  hi("SpellCap", "NONE", "NONE", "undercurl", c.string_yellow)
  hi("SpellRare", "NONE", "NONE", "undercurl", c.special_magenta)
  hi("SpellLocal", "NONE", "NONE", "undercurl", c.type_color)
  hi("IncSearch", "NONE", "NONE", "reverse") -- 注意这里可以根据喜好调整为链接到 Search

  hi("HopNextKey", c.bg, c.string_yellow, "bold") -- 单字符提示，背景黄色，前景背景色
  hi("HopNextKey1", c.bg, c.number_orange, "bold") -- 多字符提示的第一个字符，背景橙色
  hi("HopNextKey2", c.bg, c.type_color) -- 多字符提示的后续字符，背景类型色，稍微柔和
  hi("HopUnmatched", c.comment, "NONE") -- 不匹配的部分，使用注释颜色，低调
  hi("HopCursor", "NONE", c.selection, "reverse") -- 伪光标，反转选区颜色，突出显示
  hi("HopPreview", c.bg, c.special_magenta) -- 预览提示，背景洋红，前景背景色

  local lualine_theme = {
    normal = {
      a = { fg = c.bg, bg = c.ui_purple, gui = "bold" },
      b = { fg = c.grey_light, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    insert = {
      a = { fg = c.bg, bg = c.string_yellow, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    visual = {
      a = { fg = c.bg, bg = c.special_magenta, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    replace = {
      a = { fg = c.bg, bg = c.error_red, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    command = {
      a = { fg = c.bg, bg = c.number_orange, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    inactive = {
      a = { fg = c.comment, bg = c.bg, gui = "bold" },
      b = { fg = c.comment, bg = c.bg_darkest },
      c = { fg = c.comment, bg = c.bg_darkest },
    },
  }

  local augroup = vim.api.nvim_create_augroup("AlterAvengerColors", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    pattern = "alter-avenger-muted",
    callback = function()
      if not package.loaded.lualine then
        return
      end

      local lualine_config = require("lualine").get_config()
      lualine_config.options.theme = lualine_theme

      require("lualine").setup(lualine_config)
    end,
  })
end

M.setup()

return M
