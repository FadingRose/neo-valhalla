return {
  "lervag/vimtex",
  lazy = false, -- we don't want to lazy load VimTeX
  -- tag = "v2.15", -- uncomment to pin to a specific release
  init = function()
    -- VimTeX configuration goes here, e.g.

    vim.g.tex_flavor = "latex" -- Default tex file format
    vim.g.vimtex_view_method = "skim"
    -- allows forward search after every successful compilation
    vim.g.vimtex_view_skim_sync = 1
    -- allows change focus to skim after command `:VimtexView` is given
    vim.g.vimtex_view_skim_activate = 1

    vim.g.vimtex_indent_bib_enabled = 0
    vim.g.vimtex_indent_enabled = 0

    vim.g.vimtex_complete_enabled = 0
    -- Disable imaps (using Ultisnips)
    vim.g.vimtex_imaps_enabled = 0
    -- Do not open pdfviwer on compile
    vim.g.vimtex_view_automatic = 0
    -- Disable conceal
    vim.g.vimtex_syntax_conceal = {
      accents = 0,
      cites = 0,
      fancy = 0,
      greek = 0,
      math_bounds = 0,
      math_delimiters = 0,
      math_fracs = 0,
      math_super_sub = 0,
      math_symbols = 0,
      sections = 0,
      styles = 0,
    }
    -- Enable quickfix auto open
    -- vim.g.vimtex_quickfix_ignore_mode = 1
    vim.g.vimtex_compiler_progname = "nvr"
    -- PDF viewer settings
    -- vim.g.vimtex_view_general_viewer = "skim"
    -- auto open quickfix on compile erros
    vim.g.vimtex_quickfix_mode = 1
    -- Latex warnings to ignore
    vim.g.vimtex_quickfix_ignore_filters = {
      "Command terminated with space",
      "LaTeX Font Warning: Font shape",
      "Package caption Warning: The option",
      [[Underfull \\hbox (badness [0-9]*) in]],
      "Package enumitem Warning: Negative labelwidth",
      [[Overfull \\hbox ([0-9]*.[0-9]*pt too wide) in]],
      [[Package caption Warning: Unused \\captionsetup]],
      "Package typearea Warning: Bad type area settings!",
      [[Package fancyhdr Warning: \\headheight is too small]],
      [[Underfull \\hbox (badness [0-9]*) in paragraph at lines]],
      "Package hyperref Warning: Token not allowed in a PDF string",
      [[Overfull \\hbox ([0-9]*.[0-9]*pt too wide) in paragraph at lines]],
    }
    vim.g.vimtex_fold_enabled = 0
    vim.g.vimtex_fold_manual = 0
    vim.g.vimtex_fold_types = {
      cmd_addplot = {
        cmds = { "addplot[+3]?" },
      },
      cmd_multi = {
        cmds = {
          "%(re)?new%(command|environment)",
          "providecommand",
          "presetkeys",
          "Declare%(Multi|Auto)?CiteCommand",
          "Declare%(Index)?%(Field|List|Name)%(Format|Alias)",
        },
      },
      cmd_single = {
        cmds = { "hypersetup", "tikzset", "pgfplotstableread", "lstset" },
      },
      cmd_single_opt = {
        cmds = { "usepackage", "includepdf" },
      },
      comments = {
        enabled = 0,
      },
      env_options = vim.empty_dict(),
      envs = {
        blacklist = {},
        whitelist = { "figure", "frame", "table", "example", "answer" },
      },
      items = {
        enabled = 0,
      },
      markers = vim.empty_dict(),
      preamble = {
        enabled = 0,
      },
      sections = {
        parse_levels = 0,
        parts = { "appendix", "frontmatter", "mainmatter", "backmatter" },
        sections = {
          "%(add)?part",
          "%(chapter|addchap)",
          "%(section|section\\*)",
          "%(subsection|subsection\\*)",
          "%(subsubsection|subsubsection\\*)",
          "paragraph",
        },
      },
    }
  end,
}
