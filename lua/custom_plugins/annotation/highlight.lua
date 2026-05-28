local M = {}

local tag_config = {
  economic    = { icon = "¥", hl = "AnnotationEconomic",    fallback = "DiagnosticInfo" },
  security    = { icon = "!", hl = "AnnotationSecurity",    fallback = "DiagnosticError" },
  invariant   = { icon = "≠", hl = "AnnotationInvariant",   fallback = "DiagnosticWarn" },
  mechanism   = { icon = "⚙", hl = "AnnotationMechanism",   fallback = "DiagnosticOk" },
  gotcha      = { icon = "⚠", hl = "AnnotationGotcha",      fallback = "DiagnosticWarn" },
  note        = { icon = "•", hl = "AnnotationNote",        fallback = "Comment" },
  observation = { icon = "·", hl = "AnnotationObservation", fallback = "Comment" },
  warning     = { icon = "⚠", hl = "AnnotationWarning",     fallback = "DiagnosticWarn" },
  question    = { icon = "?", hl = "AnnotationQuestion",    fallback = "DiagnosticHint" },
  insight     = { icon = "※", hl = "AnnotationInsight",     fallback = "DiagnosticInfo" },
  step        = { icon = "→", hl = "AnnotationStep",        fallback = "DiagnosticOk" },
  risk        = { icon = "☠", hl = "AnnotationRisk",        fallback = "DiagnosticError" },
  assumption  = { icon = "~", hl = "AnnotationAssumption",  fallback = "DiagnosticHint" },
  finding     = { icon = "★", hl = "AnnotationFinding",     fallback = "DiagnosticError" },
  decision    = { icon = "◆", hl = "AnnotationDecision",    fallback = "DiagnosticInfo" },
}

local function dim_color(source_group, fade)
  local hl = vim.api.nvim_get_hl(0, { name = source_group })
  if not hl or not hl.fg then
    return
  end
  local r = math.floor(hl.fg / 65536)
  local g = math.floor((hl.fg % 65536) / 256)
  local b = hl.fg % 256
  local bg_val = vim.o.background == "dark" and 0 or 255
  local function blend(c)
    return math.floor(c * (1 - fade) + bg_val * fade)
  end
  return (blend(r) * 65536) + (blend(g) * 256) + blend(b)
end

function M.setup()
  local ns = vim.api.nvim_create_namespace("annotation_highlights")

  for tag, cfg in pairs(tag_config) do
    local fg = dim_color(cfg.fallback, 0.3)
    if fg then
      vim.api.nvim_set_hl(0, cfg.hl, { fg = fg })
    else
      vim.api.nvim_set_hl(0, cfg.hl, { link = cfg.fallback, default = true })
    end
  end

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("AnnotationHighlights", { clear = true }),
    callback = function()
      for tag, cfg in pairs(tag_config) do
        local fg = dim_color(cfg.fallback, 0.3)
        if fg then
          vim.api.nvim_set_hl(0, cfg.hl, { fg = fg })
        end
      end
    end,
  })
end

function M.get_config(tag)
  return tag_config[tag] or tag_config.note
end

function M.get_icon(tag)
  local cfg = tag_config[tag]
  return cfg and cfg.icon or tag_config.note.icon
end

function M.get_hl(tag)
  local cfg = tag_config[tag]
  return cfg and cfg.hl or tag_config.note.hl
end

function M.all_tags()
  return tag_config
end

return M
