local M = {}

function M.setup(plugin)
  vim.keymap.set("n", "<D-a>l", function()
    local scope = plugin.get_scope()
    if not scope or #scope == 0 then
      print("No 'include' paths found in scope.")
      return
    end

    print("Audit Scope 'include' Paths:")
    for _, path in ipairs(scope) do
      print("- " .. path)
    end
  end, { desc = "List Audit Scope" })

  vim.keymap.set("n", "<D-a>s", plugin.hint.live_grep_hints, { desc = "Grep in Hint files" })

  vim.keymap.set("n", "<leader>ch", plugin.hint.open_in_split, { desc = "打开 Hint 文件和 Lspsaga outline" })

  vim.keymap.set("n", "<leader>cHu", function()
    plugin.hint.open_in_float("top-left")
  end, { desc = "top-left Open hint file (read only) and Lspsaga outline" })
  vim.keymap.set("n", "<leader>cHo", function()
    plugin.hint.open_in_float("top-right")
  end, { desc = "top-right Open hint file (read only) and Lspsaga outline" })
  vim.keymap.set("n", "<leader>cHj", function()
    plugin.hint.open_in_float("bottom-left")
  end, { desc = "bottom-left Open hint file (read only) and Lspsaga outline" })
  vim.keymap.set("n", "<leader>cHl", function()
    plugin.hint.open_in_float("bottom-right")
  end, { desc = "bottom-right Open hint file (read only) and Lspsaga outline" })
end

return M
