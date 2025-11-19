-- ~/.config/nvim/colors/homeland-security.lua
-- Version 2: Deep Dark variant

-- 防止重复加载
if vim.g.colors_name then
  vim.cmd("hi clear")
end

-- 设置颜色方案名称
vim.g.colors_name = "homeland-security"

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
  -- Based on the "Homeland Security" palette, Deep Dark variant.
  -- This version uses a near-black background for a more immersive experience.
  -- Text highlighting is restricted to shades of navy blue and white for a subtle, monochromatic feel.
  -- Vibrant orange is used sparingly for numbers and key UI elements only.
  local c = {
    -- 基础颜色 (使用更深的背景)
    bg = "#05090D", -- 主背景 (近乎纯黑)
    bg_alt = "#081826", -- 次背景 (深海军蓝)
    bg_darkest = "#05090D", -- 最暗背景 (同主背景)
    selection = "#102940", -- 选区颜色 (使用最亮的海军蓝)
    cursorline = "#081826", -- 当前行背景色 (与bg_alt一致)

    -- 前景与注释
    fg = "#F2F2F2", -- 普通前景文字 (灰白)
    fg_dim = "#7392B7", -- 暗淡前景 (用于注释、行号等，提供中等对比度)
    fg_dim_alt = "#9BBCDC", -- 次暗淡前景 (用于字符串、操作符等，比fg_dim亮一些)
    comment = "#7392B7", -- 注释 (使用fg_dim)
    line_nr = "#7392B7", -- 行号 (使用fg_dim)
    current_line_nr = "#F2F2F2", -- 当前行号 (同前景)

    -- ===============================================
    -- 核心语法层级颜色 (海军蓝/白色方案)
    -- ===============================================
    -- [1] 变量/函数 (最突出)
    fg_brightest = "#F2F2F2", -- 使用白色，通过粗体强调

    -- [2] 类型/常量 (次突出)
    type_color = "#F2F2F2", -- 使用白色，通过斜体区分

    -- [3] 关键字 (最不突出)
    keyword_color = "#9BBCDC", -- 使用fg_dim_alt，视觉上后退但仍可见

    -- 其他高亮颜色
    error_red = "#F26430", -- 橙色作为UI/错误色保留
    string_yellow = "#9BBCDC", -- 字符串使用fg_dim_alt
    number_orange = "#F26430", -- 数字是少数保留橙色的语法元素
    special_magenta = "#F26430", -- 特殊符号、标题等UI元素使用橙色

    -- UI 颜色
    ui_purple = "#F26430", -- 橙色是主要的UI强调色
    grey_light = "#F2F2F2", -- 浅灰色 (用于状态栏文本等)
    grey_mid = "#102940", -- 中灰色 (海军蓝)
  }

  -- 设置高亮组的辅助函数
  local function hi(group, fg, bg, style, sp)
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
    if sp then
      cmd = cmd .. " guisp=" .. sp
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
  hi("VertSplit", c.bg_alt, c.bg_alt) -- Use bg_alt to make splits visible
  hi("StatusLine", c.fg, c.bg_alt)
  hi("StatusLineNC", c.fg_dim, c.bg)
  hi("Pmenu", c.fg, c.bg_alt)
  hi("PmenuSel", c.bg, c.ui_purple)
  hi("PmenuThumb", c.fg, c.bg)
  hi("PmenuSbar", c.fg, c.bg_alt)
  hi("TabLine", c.comment, c.bg_alt)
  hi("TabLineFill", c.comment, c.bg_alt)
  hi("TabLineSel", c.fg, c.ui_purple)
  hi("WinBar", c.comment, c.bg, "bold")
  hi("WinBarNC", c.comment, c.bg, "bold")

  -- ===================================
  -- 基础语法高亮
  -- ===================================
  hi("Comment", c.comment, "NONE", "italic")
  hi("Todo", c.special_magenta, c.bg_alt, "bold,underline")
  hi("Error", c.error_red, c.bg_alt, "underline")
  hi("Warning", c.special_magenta, "NONE")
  hi("Title", c.special_magenta, "NONE", "bold")
  hi("Directory", c.special_magenta, "NONE", "bold")

  -- [1] 变量/函数 (White, Bold)
  hi("Identifier", c.fg_brightest, "NONE", "bold")
  hi("Function", c.fg_brightest, "NONE", "bold")

  -- [2] 类型/常量 (White, Italic)
  hi("Type", c.type_color, "NONE", "italic")
  hi("StorageClass", c.type_color, "NONE")
  hi("Structure", c.type_color, "NONE")
  hi("Typedef", c.type_color, "NONE")
  hi("Constant", c.type_color, "NONE")
  hi("Boolean", c.type_color, "NONE", "bold")

  -- [3] 关键字/语句 (Navy Blue)
  hi("Keyword", c.keyword_color, "NONE")
  hi("Statement", c.keyword_color, "NONE", "bold")
  hi("Conditional", c.keyword_color, "NONE", "bold")
  hi("Repeat", c.keyword_color, "NONE", "bold")
  hi("Label", c.keyword_color, "NONE")

  -- 其他
  hi("String", c.string_yellow, "NONE") -- Navy Blue
  hi("Number", c.number_orange, "NONE") -- Orange
  hi("Float", c.number_orange, "NONE") -- Orange
  hi("Operator", c.keyword_color, "NONE")

  -- 预处理器
  hi("PreProc", c.keyword_color, "NONE")
  hi("Include", c.keyword_color, "NONE")
  hi("Define", c.keyword_color, "NONE")
  hi("Macro", c.keyword_color, "NONE")

  -- 特殊
  hi("Special", c.special_magenta, "NONE")
  hi("SpecialKey", c.grey_mid, "NONE")
  hi("Underlined", c.fg, "NONE", "underline")
  hi("Ignore", c.comment, "NONE")

  -- ===================================
  -- 插件和 LSP 高亮
  -- ===================================
  -- 差异比较
  hi("DiffAdd", c.type_color, c.bg_alt)
  hi("DiffDelete", c.error_red, c.bg_alt)
  hi("DiffChange", c.grey_mid, c.bg_alt)
  hi("DiffText", c.special_magenta, c.bg_alt)

  -- LSP
  hi("LspReferenceText", "NONE", c.selection)
  hi("LspReferenceRead", "NONE", c.selection)
  hi("LspReferenceWrite", "NONE", c.selection)
  hi("LspDiagnosticsDefaultError", c.error_red, "NONE")
  hi("LspDiagnosticsDefaultWarning", c.special_magenta, "NONE")
  hi("LspDiagnosticsDefaultInformation", c.type_color, "NONE")
  hi("LspDiagnosticsDefaultHint", c.grey_mid, "NONE")
  hi("LspDiagnosticsUnderlineError", c.error_red, "NONE", "underline")
  hi("LspDiagnosticsUnderlineWarning", c.special_magenta, "NONE", "underline")
  hi("LspDiagnosticsUnderlineInformation", c.type_color, "NONE", "underline")
  hi("LspDiagnosticsUnderlineHint", c.grey_mid, "NONE", "underline")

  -- 链接现有高亮组
  hi("NonText", c.comment, "NONE")
  hi("EndOfBuffer", c.comment, "NONE")
  hi("Folded", c.comment, c.bg_alt, "italic")
  hi("Search", c.bg, c.special_magenta)
  hi("IncSearch", c.bg, c.special_magenta)
  hi("MatchParen", c.bg_alt, c.selection, "bold")
  hi("Cursor", "NONE", c.fg)
  hi("lCursor", "NONE", c.fg)
  hi("TermCursor", "NONE", c.fg, "reverse")
  hi("CursorIM", "NONE", c.fg)
  hi("Whitespace", c.comment, "NONE")

  -- 消息和提示
  hi("ErrorMsg", c.error_red, "NONE", "bold")
  hi("WarningMsg", c.special_magenta, "NONE", "bold")
  hi("MoreMsg", c.special_magenta, "NONE")
  hi("Question", c.special_magenta, "NONE")
  hi("MsgArea", "NONE", "NONE")
  hi("MsgSeparator", c.comment, "NONE")

  -- Tree-sitter 高亮 (通用映射)
  hi("@variable", c.fg_brightest, "NONE", "bold")
  hi("@function", c.fg_brightest, "NONE", "bold")
  hi("@parameter", c.fg_brightest, "NONE", "italic,bold")
  hi("@keyword", c.keyword_color, "NONE")
  hi("@string", c.string_yellow, "NONE")
  hi("@number", c.number_orange, "NONE")
  hi("@boolean", c.type_color, "NONE", "bold")
  hi("@type", c.type_color, "NONE", "italic")
  hi("@operator", c.keyword_color, "NONE")
  hi("@punctuation.delimiter", c.fg, "NONE")
  hi("@punctuation.bracket", c.fg, "NONE")
  hi("@comment", c.comment, "NONE", "italic")
  hi("@constant", c.type_color, "NONE")
  hi("@property", c.fg_brightest, "NONE", "bold")
  hi("@markup.heading", c.special_magenta, "NONE", "bold")
  hi("@markup.link", c.fg, "NONE", "underline")
  hi("@markup.raw", c.string_yellow, c.bg_alt)

  -- 插件特定高亮
  hi("WhichKeyFloat", c.fg, c.bg_alt)
  hi("WhichKeyBorder", c.ui_purple, c.bg_alt)
  hi("WhichKeyGroup", c.special_magenta, "NONE", "bold")
  hi("WhichKeyMatch", c.number_orange, "NONE") -- Match with orange
  hi("WhichKeyDesc", c.fg, "NONE")

  hi("TelescopePromptNormal", c.fg, c.bg_alt)
  hi("TelescopePromptBorder", c.ui_purple, c.bg_alt)
  hi("TelescopeResultsNormal", c.fg, c.bg)
  hi("TelescopeResultsBorder", c.ui_purple, c.bg)
  hi("TelescopePreviewNormal", c.fg, c.bg_alt)
  hi("TelescopePreviewBorder", c.ui_purple, c.bg_alt)
  hi("TelescopeMatching", c.number_orange, "NONE", "bold")
  hi("TelescopeSelection", c.fg, c.selection, "bold")
  hi("TelescopeTitle", c.ui_purple, c.bg, "bold")

  hi("GitSignsAdd", c.type_color, "NONE")
  hi("GitSignsChange", c.type_color, "NONE") -- Changed from orange to white
  hi("GitSignsDelete", c.error_red, "NONE")

  -- 其他常见高亮组
  hi("CursorColumn", "NONE", c.cursorline)
  hi("Conceal", c.comment, "NONE")
  hi("FoldColumn", c.comment, c.bg)
  hi("QuickFixLine", c.special_magenta, c.bg_alt, "bold")
  hi("SpellBad", "NONE", "NONE", "undercurl", c.error_red)
  hi("SpellCap", "NONE", "NONE", "undercurl", c.special_magenta)
  hi("SpellRare", "NONE", "NONE", "undercurl", c.special_magenta)
  hi("SpellLocal", "NONE", "NONE", "undercurl", c.type_color)

  local lualine_theme = {
    normal = {
      a = { fg = c.bg, bg = c.ui_purple, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    insert = {
      a = { fg = c.bg, bg = c.type_color, gui = "bold" },
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
      a = { fg = c.bg, bg = c.fg, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    inactive = {
      a = { fg = c.comment, bg = c.bg, gui = "bold" },
      b = { fg = c.comment, bg = c.bg_darkest },
      c = { fg = c.comment, bg = c.bg_darkest },
    },
  }

  local augroup = vim.api.nvim_create_augroup("HomelandSecurityLualine", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    pattern = "*", -- 监听所有配色方案的变化
    callback = function(ev)
      -- 安全地与 lualine 交互
      local success, lualine = pcall(require, "lualine")
      if not success then
        return
      end

      local lualine_config = lualine.get_config()
      local needs_refresh = false

      -- 当切换到本主题时
      if ev.new == "homeland-security" then
        if lualine_config.options.theme ~= lualine_theme then
          lualine_config.options.theme = lualine_theme
          needs_refresh = true
        end
        -- 当从本主题切换走时
      elseif ev.old == "homeland-security" then
        -- 重置为 'auto'，让 lualine 为新主题自动处理
        lualine_config.options.theme = "auto"
        needs_refresh = true
      end

      if needs_refresh then
        lualine.setup(lualine_config)
      end
    end,
  })
end

M.setup()

return M
