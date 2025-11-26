-- ~/.config/nvim/colors/virtual-glare.lua

-- 防止重复加载
if vim.g.colors_name then
  vim.cmd("hi clear")
end

-- 设置颜色方案名称
vim.g.colors_name = "virtual-glare"

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
  -- 基于提供的色卡 (#86A6B1, #4A8DA6, #223748, #7C767A, #CA525A, #DB8169)
  -- 营造出屏幕辉光与深邃代码海洋的氛围。
  local c = {
    -- 基础背景与前景
    bg = "#223748", -- [色卡] 主背景：深蓝灰，如同未开灯的房间里屏幕的辉光
    bg_alt = "#1C2E3D", -- 次背景：比主背景稍暗，用于侧边栏或浮窗
    bg_darkest = "#15222E", -- 最暗背景：用于分割线

    selection = "#3D566B", -- 选区：背景色的提亮版
    cursorline = "#2A3E50", -- 当前行：微妙的深色高亮

    -- 文本层级
    -- 核心逻辑：使用冷色调(蓝色系)作为骨架，暖色调(橙/红)作为数据和逻辑的高亮

    fg = "#DCE8ED", -- 普通文本：基于 #86A6B1 提亮，确保在深色背景下的可读性
    comment = "#7C767A", -- [色卡] 注释：紫灰色，低调且略带忧郁
    line_nr = "#5A7382", -- 行号：介于背景和注释之间
    current_line_nr = "#DB8169", -- 当前行号：使用温暖的橙色，清晰指示位置

    -- ===============================================
    -- 核心语法层级颜色
    -- ===============================================

    -- [1] 变量/标识符 (视觉焦点 - 屏幕的反光)
    fg_brightest = "#FFFFFF", -- 纯白，用于最核心的变量名，模拟强光

    -- [2] 关键字/结构 (冷峻的逻辑)
    keyword_color = "#4A8DA6", -- [色卡] 中蓝色：用于 if, else, function 等逻辑词

    -- [3] 类型/定义 (稳定的结构)
    type_color = "#86A6B1", -- [色卡] 浅钢蓝：用于 Type, int, bool

    -- 其他高亮颜色 (暖色点缀)
    error_red = "#CA525A", -- [色卡] 柔和红：错误、操作符，具有警示感但不刺眼
    number_orange = "#DB8169", -- [色卡] 桃橙色：数字、布尔值，为冷色调带来温度
    string_cyan = "#A3C4D1", -- 字符串：比关键字稍浅的蓝色，保持文本流的连贯性
    special_accent = "#CA525A", -- [色卡] 特殊符号、标题：复用红色

    -- UI 颜色
    ui_border = "#4A8DA6", -- 边框色：与关键字呼应
    grey_light = "#C0C0C0", -- 浅灰
    grey_mid = "#546E7A", -- 中灰
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
  hi("FloatBorder", c.ui_border, c.bg_alt)
  hi("LineNr", c.line_nr, c.bg)
  hi("CursorLineNr", c.current_line_nr, c.cursorline, "bold")
  hi("CursorLine", "NONE", c.cursorline)
  hi("Visual", "NONE", c.selection)
  hi("ColorColumn", "NONE", c.cursorline)
  hi("SignColumn", c.fg, c.bg)
  hi("VertSplit", c.bg_darkest, c.bg_darkest)
  hi("StatusLine", c.bg, c.type_color)
  hi("StatusLineNC", c.comment, c.bg_darkest)
  hi("Pmenu", c.fg, c.bg_alt)
  hi("PmenuSel", c.bg, c.keyword_color) -- 选中项反转颜色
  hi("PmenuThumb", c.fg, c.bg)
  hi("PmenuSbar", c.fg, c.bg_alt)
  hi("TabLine", c.comment, c.bg_alt)
  hi("TabLineFill", c.comment, c.bg_alt)
  hi("TabLineSel", c.bg, c.keyword_color)

  -- ===================================
  -- 基础语法高亮
  -- ===================================
  hi("Comment", c.comment, "NONE", "italic")
  hi("Todo", c.bg, c.number_orange, "bold")
  hi("Error", c.error_red, c.bg_alt, "underline")
  hi("Warning", c.number_orange, "NONE")
  hi("Title", c.special_accent, "NONE", "bold")
  hi("Directory", c.keyword_color, "NONE", "bold")

  -- [1] 变量/函数
  hi("Identifier", c.fg, "NONE") -- 普通变量跟随前景
  hi("Function", c.fg_brightest, "NONE", "bold") -- 函数名高亮

  -- [2] 类型/常量
  hi("Type", c.type_color, "NONE", "italic")
  hi("StorageClass", c.type_color, "NONE")
  hi("Structure", c.type_color, "NONE")
  hi("Typedef", c.type_color, "NONE")
  hi("Constant", c.number_orange, "NONE")
  hi("Boolean", c.number_orange, "NONE", "bold")

  -- [3] 关键字/语句
  hi("Keyword", c.keyword_color, "NONE")
  hi("Statement", c.keyword_color, "NONE", "bold")
  hi("Conditional", c.keyword_color, "NONE", "bold")
  hi("Repeat", c.keyword_color, "NONE", "bold")
  hi("Label", c.keyword_color, "NONE")

  -- 其他
  hi("String", c.string_cyan, "NONE")
  hi("Number", c.number_orange, "NONE")
  hi("Float", c.number_orange, "NONE")
  hi("Operator", c.error_red, "NONE") -- 操作符使用红色点缀

  -- 预处理器
  hi("PreProc", c.special_accent, "NONE")
  hi("Include", c.keyword_color, "NONE")
  hi("Define", c.special_accent, "NONE")
  hi("Macro", c.special_accent, "NONE")

  -- 特殊
  hi("Special", c.number_orange, "NONE")
  hi("SpecialKey", c.grey_mid, "NONE")
  hi("Underlined", c.fg, "NONE", "underline")
  hi("Ignore", c.comment, "NONE")

  -- ===================================
  -- 插件和 LSP 高亮
  -- ===================================
  -- 差异比较
  hi("DiffAdd", c.string_cyan, c.bg_alt)
  hi("DiffDelete", c.error_red, c.bg_alt)
  hi("DiffChange", c.number_orange, c.bg_alt)
  hi("DiffText", c.bg, c.number_orange)

  -- LSP
  hi("LspReferenceText", "NONE", c.selection)
  hi("LspReferenceRead", "NONE", c.selection)
  hi("LspReferenceWrite", "NONE", c.selection)
  hi("LspDiagnosticsDefaultError", c.error_red, "NONE")
  hi("LspDiagnosticsDefaultWarning", c.number_orange, "NONE")
  hi("LspDiagnosticsDefaultInformation", c.type_color, "NONE")
  hi("LspDiagnosticsDefaultHint", c.comment, "NONE")
  hi("LspDiagnosticsUnderlineError", c.error_red, "NONE", "underline")
  hi("LspDiagnosticsUnderlineWarning", c.number_orange, "NONE", "underline")
  hi("LspDiagnosticsUnderlineInformation", c.type_color, "NONE", "underline")
  hi("LspDiagnosticsUnderlineHint", c.comment, "NONE", "underline")

  -- 链接现有高亮组
  hi("NonText", c.bg_alt, "NONE")
  hi("EndOfBuffer", c.bg, "NONE")
  hi("Folded", c.comment, c.bg_alt, "italic")
  hi("Search", c.bg, c.number_orange)
  hi("IncSearch", c.bg, c.special_accent)
  hi("MatchParen", c.bg, c.keyword_color, "bold")
  hi("Cursor", c.bg, c.fg)
  hi("lCursor", c.bg, c.fg)
  hi("TermCursor", "NONE", c.fg, "reverse")
  hi("Whitespace", c.bg_alt, "NONE")

  -- 消息和提示
  hi("ErrorMsg", c.error_red, "NONE", "bold")
  hi("WarningMsg", c.number_orange, "NONE", "bold")
  hi("MoreMsg", c.keyword_color, "NONE")
  hi("Question", c.number_orange, "NONE")
  hi("MsgArea", "NONE", "NONE")
  hi("MsgSeparator", c.bg_alt, "NONE")

  -- Tree-sitter 高亮
  hi("@variable", c.fg, "NONE")
  hi("@variable.builtin", c.special_accent, "NONE")
  hi("@function", c.fg_brightest, "NONE", "bold")
  hi("@function.builtin", c.fg_brightest, "NONE", "bold")
  hi("@parameter", c.type_color, "NONE", "italic")
  hi("@keyword", c.keyword_color, "NONE")
  hi("@string", c.string_cyan, "NONE")
  hi("@number", c.number_orange, "NONE")
  hi("@boolean", c.number_orange, "NONE", "bold")
  hi("@type", c.type_color, "NONE", "italic")
  hi("@constructor", c.fg_brightest, "NONE")
  hi("@operator", c.error_red, "NONE")
  hi("@punctuation.delimiter", c.fg, "NONE")
  hi("@punctuation.bracket", c.fg, "NONE")
  hi("@comment", c.comment, "NONE", "italic")
  hi("@constant", c.number_orange, "NONE")
  hi("@constant.builtin", c.number_orange, "NONE")
  hi("@property", c.fg, "NONE")
  hi("@field", c.fg, "NONE")
  hi("@markup.heading", c.number_orange, "NONE", "bold")
  hi("@markup.link", c.type_color, "NONE", "underline")
  hi("@markup.raw", c.string_cyan, c.bg_alt)

  -- 插件特定高亮
  hi("WhichKeyFloat", c.fg, c.bg_alt)
  hi("WhichKeyBorder", c.ui_border, c.bg_alt)
  hi("WhichKeyGroup", c.keyword_color, "NONE", "bold")
  hi("WhichKeyMatch", c.number_orange, "NONE")
  hi("WhichKeyDesc", c.fg, "NONE")

  hi("TelescopePromptNormal", c.fg, c.bg)
  hi("TelescopePromptBorder", c.keyword_color, c.bg)
  hi("TelescopeResultsNormal", c.fg, c.bg_alt)
  hi("TelescopeResultsBorder", c.comment, c.bg_alt)
  hi("TelescopePreviewNormal", c.fg, c.bg_alt)
  hi("TelescopePreviewBorder", c.comment, c.bg_alt)
  hi("TelescopeMatching", c.number_orange, "NONE", "bold")
  hi("TelescopeSelection", "NONE", c.selection)
  hi("TelescopeTitle", c.bg, c.keyword_color, "bold")

  hi("GitSignsAdd", c.string_cyan, "NONE")
  hi("GitSignsChange", c.number_orange, "NONE")
  hi("GitSignsDelete", c.error_red, "NONE")

  hi("NoiceCmdline", c.fg, c.bg)
  hi("NoiceCmdlinePopup", c.fg, c.bg_alt)
  hi("NoiceCmdlinePopupBorder", c.keyword_color, c.bg_alt)
  hi("NoicePopupmenu", c.fg, c.bg_alt)
  hi("NoicePopupmenuSelected", c.bg, c.keyword_color)
  hi("NoiceConfirm", c.fg, c.bg_alt)
  hi("NoiceConfirmBorder", c.special_accent, c.bg_alt)
  hi("NoiceMini", c.comment, "NONE")

  hi("DapUIFloatNormal", c.fg, c.bg_alt)
  hi("DapUIFloatBorder", c.keyword_color, c.bg_alt)
  hi("DapUIScope", c.keyword_color, "NONE", "bold")
  hi("DapUIValue", c.fg, "NONE")
  hi("DapUIBreakpointsCurrentLine", c.current_line_nr, "NONE", "bold")
  hi("NvimDapVirtualText", c.comment, "NONE")

  hi("BufferLineFill", c.bg_darkest, c.bg_darkest)
  hi("BufferLineBuffer", c.comment, c.bg_alt)
  hi("BufferLineBufferSelected", c.fg, c.bg, "bold")
  hi("BufferLineTabSelected", c.fg, c.bg, "bold")
  hi("BufferLineSeparator", c.bg_darkest, c.bg_darkest)
  hi("BufferLineSeparatorSelected", c.bg, c.bg)
  hi("BufferLineModified", c.number_orange, c.bg_alt)
  hi("BufferLineModifiedSelected", c.number_orange, c.bg)

  -- Hop 插件
  hi("HopNextKey", c.bg, c.number_orange, "bold")
  hi("HopNextKey1", c.bg, c.keyword_color, "bold")
  hi("HopNextKey2", c.bg, c.string_cyan)
  hi("HopUnmatched", c.comment, "NONE")

  -- Lualine 配置主题
  local lualine_theme = {
    normal = {
      a = { fg = c.bg, bg = c.keyword_color, gui = "bold" }, -- 蓝色块
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    insert = {
      a = { fg = c.bg, bg = c.number_orange, gui = "bold" }, -- 橙色块 (活力)
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    visual = {
      a = { fg = c.bg, bg = c.type_color, gui = "bold" }, -- 浅蓝色块
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    replace = {
      a = { fg = c.bg, bg = c.error_red, gui = "bold" }, -- 红色块 (警示)
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    command = {
      a = { fg = c.bg, bg = c.special_accent, gui = "bold" },
      b = { fg = c.fg, bg = c.selection },
      c = { fg = c.fg, bg = c.bg_alt },
    },
    inactive = {
      a = { fg = c.comment, bg = c.bg_alt, gui = "bold" },
      b = { fg = c.comment, bg = c.bg_darkest },
      c = { fg = c.comment, bg = c.bg_darkest },
    },
  }

  local augroup = vim.api.nvim_create_augroup("VirtualGlareColors", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    pattern = "virtual-glare",
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
