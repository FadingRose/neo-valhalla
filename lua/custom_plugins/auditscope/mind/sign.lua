-- lua/custom_plugins/auditscope/mind/signs.lua
local db = require("custom_plugins.auditscope.mind.db")
local M = {}
local NAMESPACE = vim.api.nvim_create_namespace("AuditMindSigns")
local config = {}

local sign_definitions = {
  hypothesis = { group = "AuditHypothesis" },
  insight = { group = "AuditInsight" },
  fact = { group = "AuditFact" },
  question = { group = "AuditQuestion" },
}

-- Helper to dim a highlight group color by blending with background
local function set_dimmed_hl(target_group, source_group, fade_factor)
  local hl = vim.api.nvim_get_hl(0, { name = source_group })
  local fg = hl.fg

  if fg then
    -- Extract RGB
    local r = math.floor(fg / 65536)
    local g = math.floor((fg % 65536) / 256)
    local b = fg % 256

    -- Determine background blending target
    local bg_val = vim.o.background == "dark" and 0 or 255

    -- Blend function
    local function blend(c)
      return math.floor(c * (1 - fade_factor) + bg_val * fade_factor)
    end

    -- Reconstruct Hex
    local new_fg = (blend(r) * 65536) + (blend(g) * 256) + blend(b)

    vim.api.nvim_set_hl(0, target_group, { fg = new_fg })
  else
    -- Fallback: link if source color not found
    vim.api.nvim_set_hl(0, target_group, { link = source_group, default = true })
  end
end

function M.setup(cfg)
  config = cfg

  local function apply_highlights()
    -- Fade factor 0.4 means 40% faded towards background
    set_dimmed_hl("AuditHypothesis", "DiagnosticError", 0.4)
    set_dimmed_hl("AuditInsight", "DiagnosticInfo", 0.4)
    set_dimmed_hl("AuditFact", "DiagnosticOk", 0.4)
    set_dimmed_hl("AuditQuestion", "DiagnosticWarn", 0.4)
  end

  apply_highlights()

  -- Re-calculate when colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("AuditScopeHighlights", { clear = true }),
    callback = apply_highlights,
  })

  for type, def in pairs(sign_definitions) do
    if config.icons[type] then
      vim.fn.sign_define(def.group, { text = config.icons[type], texthl = def.group })
    end
  end
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_file = vim.fn.expand("%:p")
  local nodes = db.get_nodes()

  -- 清除当前 Buffer 的所有 extmarks/signs
  vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)

  -- 简单的 Sign Placement 逻辑 (建议使用 extmarks 因为它随代码移动更稳定)
  for _, node in ipairs(nodes) do
    if node.file == current_file and node.start_line then
      local sign_def = sign_definitions[node.type]
      if sign_def then
        -- Use a single extmark for both the gutter sign and virtual text
        vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, node.start_line - 1, 0, {
          -- sign_text = config.icons[node.type], -- 移除侧边栏符号设置
          -- sign_hl_group = sign_def.group,      -- 移除侧边栏符号高亮设置
          virt_text = { { config.icons[node.type] .. " " .. node.text, sign_def.group } }, -- 将图标作为虚拟文本的一部分
          virt_text_pos = "eol",
        })
      end
    end
  end
end

return M
