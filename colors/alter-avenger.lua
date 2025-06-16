-- ~/.config/nvim/colors/alteravenger.lua

local M = {}

M.setup = function()
  -- Reset highlights to default to ensure a clean slate
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.termguicolors = true -- Essential for true color support

  local c = {
    -- Base Colors (same as before)
    bg = "#1A0A2E",
    bg_alt = "#281040",
    fg = "#E0CEF0",
    comment = "#8A7B9B",
    selection = "#4F1F6F",
    cursorline = "#321550",
    line_nr = "#6A4F8B",
    current_line_nr = "#E0CEF0",

    -- Accent Colors (same as before)
    magenta = "#FF00FF",
    red = "#FF3366",
    purple_light = "#C080FF",
    white_ish = "#F0F0F0",
    grey_metallic = "#A0A0B0",
    purple_dark = "#6A2F9B",
  }

  -- Helper function to set highlight groups
  local function hi(group, fg, bg, style)
    -- Build the command string carefully
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

    -- ONLY add gui= if style is provided and not an empty string
    if style and style ~= "" then
      cmd = cmd .. " gui=" .. style
    end

    vim.cmd(cmd)
  end

  -- ... (rest of your highlight calls, no changes needed here if you used "NONE" or valid styles) ...

  -- Examples of calls you have:
  hi("Normal", c.fg, c.bg) -- style is nil, gui= should not be added
  hi("CursorLineNr", c.current_line_nr, c.cursorline, "bold") -- style is "bold", gui=bold will be added
  hi("Visual", "NONE", c.selection) -- style is nil, gui= should not be added (you passed "NONE" for fg, which is fine, but for style it's nil)
  hi("Error", c.red, "NONE", "underline") -- style is "underline", gui=underline will be added
  hi("Todo", c.magenta, c.bg_alt, "bold,underline") -- style is "bold,underline", gui=bold,underline will be added

  -- ... (rest of your colorscheme) ...
end

return M
