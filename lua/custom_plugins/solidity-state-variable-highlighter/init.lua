local M = {}

-- Namespace for our custom highlights
local ns_id = vim.api.nvim_create_namespace("solidity_state_vars")

-- The core highlighting function
local function highlight_state_vars(bufnr)
  -- Ensure the buffer is valid and has a 'solidity' parser available
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local parser = vim.treesitter.get_parser(bufnr, "solidity")
  if not parser then
    return
  end

  -- Clear previous highlights from our namespace before applying new ones
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Step 1: Find all state variable identifiers and store their names
  local state_var_names = {}
  local query_state_vars =
    vim.treesitter.query.parse("solidity", "(state_variable_declaration name: (identifier) @name)")

  -- The root of the syntax tree
  local root = parser:parse()[1]:root()

  for _, node in query_state_vars:iter_captures(root, bufnr, 0, -1) do
    local var_name = vim.treesitter.get_node_text(node, bufnr)
    state_var_names[var_name] = true
    local start_row, start_col, end_row, end_col = node:range()
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      hl_group = "@variable.builtin", -- Corresponds to @variable.builtin
    })
  end

  -- Step 2: Find all identifiers and highlight them if they are state variables

  local query_function_modifiers = vim.treesitter.query.parse(
    "solidity",
    [[
     (function_definition
       name: (identifier)
      (_)
      (modifier_invocation
          (identifier) @modifier_name)
      (_)
      )
   ]]
  )

  for _, node, _ in query_function_modifiers:iter_captures(root, bufnr, 0, -1) do
    -- local modifier_name = vim.treesitter.get_node_text(node, bufnr)
    -- vim.notify("Found state_variable in function modifier: " .. modifier_name, vim.log.levels.INFO)
    local start_row, start_col, end_row, end_col = node:range()
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      hl_group = "@variable.parameter", -- Corresponds to @variable.builtin
    })
  end

  local query_function_bodies = vim.treesitter.query.parse(
    "solidity",
    [[
      [
        (function_definition
          body: (function_body) @body)
        (modifier_definition
          body: (function_body) @body)
      ]
   ]]
  )

  local id_query = vim.treesitter.query.parse(
    "solidity",
    [[
       (identifier) @id 
    ]]
  )

  local external_call_query = vim.treesitter.query.parse(
    "solidity",
    [[
      (call_expression
        function: (expression
          (member_expression
            object: (_)
            property: (identifier) @call ))
        (_)
        )
     ]]
  )

  for _, node, _ in query_function_bodies:iter_captures(root, bufnr, 0, -1) do
    -- highlight external calls
    for _, call_node, _ in external_call_query:iter_captures(node, bufnr, 0, -1) do
      local call_text = vim.treesitter.get_node_text(call_node, bufnr)
      -- vim.notify("Found state_variable in external call: " .. call_text, vim.log.levels.INFO)
      local start_row, start_col, end_row, end_col = call_node:range()
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {
        end_row = end_row,
        end_col = end_col,
        hl_group = "@variable.member", -- Corresponds to @variable.builtin
      })
    end

    -- highlight state variables
    for _, id_node, _ in id_query:iter_captures(node, bufnr, 0, -1) do
      local id_text = vim.treesitter.get_node_text(id_node, bufnr)
      if state_var_names[id_text] then
        -- vim.notify("Found state_variable in function body: " .. id_text, vim.log.levels.INFO)
        local start_row, start_col, end_row, end_col = id_node:range()
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = "@variable.builtin", -- Corresponds to @variable.builtin
        })
      end
    end
  end
end

-- Setup function to activate the highlighting via autocommands
function M.setup()
  vim.api.nvim_set_hl(0, "@variable.member.solidity", { link = "@variable" })
  vim.api.nvim_set_hl(0, "@keyword.function.solidity", { link = "@keyword" })
  vim.api.nvim_set_hl(0, "@variable.parameter.solidity", { link = "@variable" })
  vim.api.nvim_set_hl(0, "@function.method.call.solidity", { link = "@variable" })

  local group = vim.api.nvim_create_augroup("SolidityStateVarHighlighter", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = "*.sol",
    callback = function(args)
      -- Use a timer to avoid running on every single keystroke in insert mode
      vim.defer_fn(function()
        highlight_state_vars(args.buf)
      end, 300) -- 300ms delay
    end,
  })
end

return M
