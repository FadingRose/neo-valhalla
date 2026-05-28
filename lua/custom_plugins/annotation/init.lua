local M = {}

function M.setup(opts)
  opts = opts or {}

  M.store = require("custom_plugins.annotation.store")
  M.highlight = require("custom_plugins.annotation.highlight")
  M.inline = require("custom_plugins.annotation.inline")
  M.panel = require("custom_plugins.annotation.panel")
  M.generate = require("custom_plugins.annotation.generate")
  M.edit = require("custom_plugins.annotation.edit")
  M.list = require("custom_plugins.annotation.list")
  M.compact = require("custom_plugins.annotation.compact")
  M.session = require("custom_plugins.annotation.session")
  M.keymaps = require("custom_plugins.annotation.keymaps")

  M.highlight.setup()
  M.keymaps.setup(M)

  vim.api.nvim_create_user_command("AnnotationToggle", function()
    M.inline.toggle()
  end, { desc = "Toggle inline annotations" })

  vim.api.nvim_create_user_command("AnnotationMode", function()
    M.inline.cycle_mode()
  end, { desc = "Cycle annotation display mode" })

  vim.api.nvim_create_user_command("AnnotationPanel", function()
    M.panel.toggle()
  end, { desc = "Toggle annotation side panel" })

  vim.api.nvim_create_user_command("AnnotationReload", function()
    M.store.clear_cache()
    M.inline.refresh()
    if M.panel.is_open() then
      M.panel.refresh()
    end
    vim.notify("Annotations reloaded", vim.log.levels.INFO)
  end, { desc = "Reload annotations from disk" })

  vim.api.nvim_create_user_command("AnnotationGenerate", function(args)
    local range = args.range
    if range == 2 then
      M.generate.generate({
        start_line = args.line1,
        end_line = args.line2,
      })
    else
      M.generate.generate()
    end
  end, { desc = "Generate annotations via opencode", range = true })

  vim.api.nvim_create_user_command("AnnotationGeneratePrompt", function(args)
    local range = args.range
    if range == 2 then
      M.generate.generate_with_prompt({
        start_line = args.line1,
        end_line = args.line2,
      })
    else
      M.generate.generate_with_prompt()
    end
  end, { desc = "Generate annotations with custom prompt", range = true })

  vim.api.nvim_create_user_command("AnnotationGenerateLine", function()
    M.generate.generate_at_line()
  end, { desc = "Generate annotation at current line" })

  vim.api.nvim_create_user_command("AnnotationGenerateLinePrompt", function()
    M.generate.generate_at_line_with_prompt()
  end, { desc = "Generate annotation at current line with custom prompt" })

  vim.api.nvim_create_user_command("AnnotationSessionReset", function()
    M.session.reset()
  end, { desc = "Start a fresh Claude session for annotations" })

  vim.api.nvim_create_user_command("AnnotationCompact", function()
    M.compact.compact()
  end, { desc = "Compact similar annotations via Claude" })

  vim.api.nvim_create_user_command("AnnotationList", function()
    M.list.toggle()
  end, { desc = "List all annotations" })

  vim.api.nvim_create_user_command("AnnotationEdit", function()
    M.edit.open()
  end, { desc = "Edit annotation file in split" })

  vim.api.nvim_create_user_command("AnnotationDelete", function()
    M.edit.delete()
  end, { desc = "Delete an annotation" })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("annotation_auto_refresh", { clear = true }),
    callback = function()
      local ft = vim.bo.filetype
      if ft == "solidity" or ft == "rust" or ft == "lua" or ft == "go" then
        M.inline.refresh()
      end
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = vim.api.nvim_create_augroup("annotation_panel_sync", { clear = true }),
    callback = function()
      if M.panel.is_open() then
        local buf = vim.api.nvim_get_current_buf()
        if not vim.b[buf].annotation_panel then
          M.panel.refresh()
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("annotation_md_save", { clear = true }),
    pattern = "*.md",
    callback = function(args)
      local path = args.match or args.file or ""
      if path:find(M.store._dir_name, 1, true) then
        M.store.clear_cache()
        M.inline.refresh()
      end
    end,
  })
end

return M
