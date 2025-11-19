-- ~/.config/nvim/colors/aqua-pink.lua

-- 防止重复加载
if vim.g.colors_name then
  vim.cmd("hi clear")
end

-- 设置颜色方案名称
vim.g.colors_name = "aqua-pink"

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
  -- Based on the Aqua Pink palette with a deeper background for higher contrast.
  -- The palette uses a dark grey background with a bright, high-contrast foreground.
  -- Pink is used as the primary accent for important identifiers and UI elements.
  -- Soft blue is used for literals and types.
  -- Muted grey makes keywords and comments recede.
  local c = {
    -- 基础颜色 (背景已加深)
    -- bg = "#2E3033", -- 主背景 (更深的炭灰色)
    -- bg_alt = "#3A3D42", -- 次背景 (比新bg稍亮)
    -- bg_darkest = "#242629", -- 最暗背景 (比新bg稍暗)
    -- selection = "#747C7A", -- 选区颜色 (保持原样，以提供清晰对比)
    -- cursorline = "#3A3D42", -- 当前行背景色 (与bg_alt一致)

    bg = "#222426", -- 主背景 (更深的炭灰色)
    bg_alt = "#2A2C2F", -- 次背景 (比新bg稍亮，差别很小)
    bg_darkest = "#1D1F21", -- 最暗背景 (比新bg稍暗，差别很小)
    selection = "#747C7A", -- 选区颜色 (保持原样，以提供清晰对比)
    cursorline = "#2A2C2F", -- 当前行背景色 (与bg_alt一致，提供非常细微的区分)

    -- 前景与注释 (保持不变)
    fg = "#DDE7EA", -- 普通前景文字 (Very Light Blue/White - for max readability)
    comment = "#A4A49F", -- 注释 (Muted Grey)
    line_nr = "#A4A49F", -- 行号 (Muted Grey)
    current_line_nr = "#DDE7EA", -- 当前行号 (Matches fg)

    -- ===============================================
    -- 核心语法层级颜色 (保持不变)
    -- ===============================================
    -- [1] 变量/函数 (最突出)
    fg_brightest = "#E89CAF", -- 用于变量、函数名。Distinctive pink accent.

    -- [2] 类型/常量 (次突出)
    type_color = "#BBD0D5", -- 用于类型、常量。Soft blue.

    -- [3] 关键字 (最不突出)
    keyword_color = "#A4A49F", -- 用于关键字、语句。Muted grey, visually retreats.

    -- 其他高亮颜色 (保持不变)
    error_red = "#E89CAF", -- Pink is the only warm accent, used for errors.
    string_yellow = "#BBD0D5", -- Soft blue for strings (re-using type_color).
    number_orange = "#BBD0D5", -- Soft blue for numbers (re-using type_color).
    special_magenta = "#E89CAF", -- Pink for special symbols, titles, etc.

    -- UI 颜色 (保持不变)
    ui_purple = "#E89CAF", -- Pink is the main UI accent color.
    grey_light = "#DDE7EA", -- 浅灰色 (For status bar text, etc.)
    grey_mid = "#A4A49F", -- 中灰色 (For special characters)
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
  -- ADDED: WinBar 定义
  hi("WinBar", c.comment, c.bg, "bold")
  hi("WinBarNC", c.comment, c.bg, "bold")
  -- ===================================
  -- 基础语法高亮
  -- ===================================
  hi("Comment", c.comment, "NONE", "italic")
  hi("Todo", c.special_magenta, c.bg_alt, "bold,underline")
  hi("Error", c.error_red, c.bg_alt, "underline")
  hi("Warning", c.string_yellow, "NONE")
  hi("Title", c.special_magenta, "NONE", "bold")
  hi("Directory", c.special_magenta, "NONE", "bold")

  -- [1] 变量/函数 (Pink Accent)
  hi("Identifier", c.fg_brightest, "NONE") -- 变量名
  hi("Function", c.fg_brightest, "NONE", "bold") -- 函数名

  -- [2] 类型/常量 (Soft Blue)
  hi("Type", c.type_color, "NONE", "italic") -- 类型 (int, string, bool)
  hi("StorageClass", c.type_color, "NONE") -- 存储类 (static, extern)
  hi("Structure", c.type_color, "NONE") -- 结构体 (struct, union)
  hi("Typedef", c.type_color, "NONE") -- 类型定义
  hi("Constant", c.type_color, "NONE") -- 常量
  hi("Boolean", c.type_color, "NONE", "bold") -- 布尔值

  -- [3] 关键字/语句 (Muted Grey)
  hi("Keyword", c.keyword_color, "NONE")
  hi("Statement", c.keyword_color, "NONE", "bold")
  hi("Conditional", c.keyword_color, "NONE", "bold")
  hi("Repeat", c.keyword_color, "NONE", "bold")
  hi("Label", c.keyword_color, "NONE")

  -- 其他
  hi("String", c.string_yellow, "NONE")
  hi("Number", c.number_orange, "NONE")
  hi("Float", c.number_orange, "NONE")
  hi("Operator", c.keyword_color, "NONE") -- Operators use the muted grey to recede

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
  hi("DiffChange", c.type_color, c.bg_alt)
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
  hi("@operator", c.keyword_color, "NONE")
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

  -- 其他常见高亮组
  hi("CursorColumn", "NONE", c.cursorline)
  hi("Conceal", c.comment, "NONE")
  hi("FoldColumn", c.comment, c.bg)
  hi("QuickFixLine", c.special_magenta, c.bg_alt, "bold")
  hi("SpellBad", "NONE", "NONE", "undercurl", c.error_red)
  hi("SpellCap", "NONE", "NONE", "undercurl", c.string_yellow)
  hi("SpellRare", "NONE", "NONE", "undercurl", c.special_magenta)
  hi("SpellLocal", "NONE", "NONE", "undercurl", c.type_color)

  hi("IncSearch", "NONE", "NONE", "reverse")

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
      a = { fg = c.bg, bg = c.type_color, gui = "bold" }, -- Using blue for insert mode
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
      a = { fg = c.bg, bg = c.string_yellow, gui = "bold" }, -- Using blue for command mode
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    inactive = {
      a = { fg = c.comment, bg = c.bg, gui = "bold" },
      b = { fg = c.comment, bg = c.bg_darkest },
      c = { fg = c.comment, bg = c.bg_darkest },
    },
  }

  local augroup = vim.api.nvim_create_augroup("AquaPinkLualine", { clear = true })
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
      if ev.new == "aqua-pink" then
        if lualine_config.options.theme ~= lualine_theme then
          lualine_config.options.theme = lualine_theme
          needs_refresh = true
        end
        -- 当从本主题切换走时
      elseif ev.old == "aqua-pink" then
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
