local M = {}

-- Namespace for our custom highlights
local ns_id = vim.api.nvim_create_namespace("solidity_state_vars")

local builtin_identifiers = {
  msg = true,
  tx = true,
  block = true,
  abi = true,
  this = true,
  super = true,
}

local definition_node_types = {
  contract_definition = true,
  interface_definition = true,
  library_definition = true,
  struct_definition = true,
  enum_definition = true,
  event_definition = true,
  error_definition = true,
  user_defined_value_type_definition = true,
}

local local_decl_node_types = {
  variable_declaration = true,
  parameter = true,
}

local function add_names_from_field(node, bufnr, set)
  local name_nodes = node:field("name")
  for _, name_node in ipairs(name_nodes) do
    if name_node:type() == "identifier" then
      set[vim.treesitter.get_node_text(name_node, bufnr)] = true
    end
  end
end

local function collect_definition_names(root, bufnr)
  local names = {}
  local function walk(node)
    if definition_node_types[node:type()] then
      add_names_from_field(node, bufnr, names)
    end
    for child in node:iter_children() do
      walk(child)
    end
  end
  walk(root)
  return names
end

local function find_enclosing_definition(node)
  local current = node
  while current do
    local node_type = current:type()
    if
      node_type == "function_definition"
      or node_type == "modifier_definition"
      or node_type == "constructor_definition"
      or node_type == "fallback_definition"
      or node_type == "receive_definition"
    then
      return current
    end
    current = current:parent()
  end
  return nil
end

local function collect_local_names(body_node, bufnr)
  local names = {}

  local fn_node = find_enclosing_definition(body_node)
  if fn_node then
    local function walk_params(node)
      if node:type() == "function_body" then
        return
      end
      if node:type():find("parameter") and node:type() ~= "parameter_list" then
        add_names_from_field(node, bufnr, names)
      end
      for child in node:iter_children() do
        walk_params(child)
      end
    end
    walk_params(fn_node)
  end

  local function walk_locals(node)
    if local_decl_node_types[node:type()] then
      add_names_from_field(node, bufnr, names)
    end
    for child in node:iter_children() do
      walk_locals(child)
    end
  end
  walk_locals(body_node)

  return names
end

local function is_field_node(node, field_name)
  local parent = node:parent()
  if not parent then
    return false
  end
  for _, child in ipairs(parent:field(field_name)) do
    if child == node then
      return true
    end
  end
  return false
end

local function is_function_call_identifier(node)
  local parent = node:parent()
  if parent and parent:type() == "call_expression" and is_field_node(node, "function") then
    return true
  end
  if parent and parent:parent() and parent:parent():type() == "call_expression" and is_field_node(parent, "function") then
    return true
  end
  return false
end

local function is_member_expression_part(node)
  local parent = node:parent()
  if parent and parent:type() == "member_expression" then
    return true
  end
  if parent and parent:parent() and parent:parent():type() == "member_expression" then
    return true
  end
  return false
end

local function safe_parse_query(lang, query_string)
  local ok, parsed = pcall(vim.treesitter.query.parse, lang, query_string)
  if ok then
    return parsed
  end
  return nil
end

local function collect_vars_recursively(filepath, visited)
  filepath = vim.fn.expand(filepath)
  if not filepath or visited[filepath] then
    return {}
  end
  visited[filepath] = true

  local file = io.open(filepath, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()

  local parser = vim.treesitter.get_parser(0, "solidity")
  local tree = parser:parse_str(content)[1]
  if not tree then
    return {}
  end
  local root = tree:root()
  local all_vars = {}
end

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
  local definition_names = collect_definition_names(root, bufnr)

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

  -- Step 2.1: Find state variables from this contract

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

  -- Step 2.2: Find state variables from inherition contracts

  -- local imports = {}
  -- local import_query = vim.treesitter.query.parse(
  --   "solidity",
  --   [[
  --     (import_directive
  --       import_name: (identifier) @name
  --       source: (string) @source)
  --   ]]
  -- )

  -- for _, match in import_query:iter_matches(root, 0) do
  --   local name_node = match.name
  --   local source_node = match.source
  --
  --   vim.notify(
  --     "Found import: "
  --       .. vim.treesitter.get_node_text(name_node, 0)
  --       .. " from "
  --       .. vim.treesitter.get_node_text(source_node, 0),
  --     vim.log.levels.INFO
  --   )
  -- if name_node and source_node then
  --   -- Use the directive node's unique ID as a key for grouping.
  --   local directive_id = directive_node:id()
  --
  --   if not imports[directive_id] then
  --     imports[directive_id] = {
  --       source = vim.treesitter.get_node_text(source_node, 0),
  --       names = {},
  --     }
  --   end
  --
  --   table.insert(imports[directive_id].names, vim.treesitter.get_node_text(name_node, 0))
  -- end
  -- end

  -- Step 3: Highlight state variable usages in function bodies

  local function_body_queries = {
    safe_parse_query("solidity", "(function_definition body: (function_body) @body)"),
    safe_parse_query("solidity", "(constructor_definition body: (function_body) @body)"),
    safe_parse_query("solidity", "(fallback_definition body: (function_body) @body)"),
    safe_parse_query("solidity", "(receive_definition body: (function_body) @body)"),
    safe_parse_query("solidity", "(modifier_definition body: (function_body) @body)"),
  }

  local id_query = safe_parse_query(
    "solidity",
    [[
       (identifier) @id 
    ]]
  )

  local external_call_query = safe_parse_query(
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

  if not id_query or not external_call_query then
    return
  end

  local function process_body_node(body_node)
    local local_names = collect_local_names(body_node, bufnr)

    -- highlight external calls
    for _, call_node, _ in external_call_query:iter_captures(body_node, bufnr, 0, -1) do
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
    for _, id_node, _ in id_query:iter_captures(body_node, bufnr, 0, -1) do
      local id_text = vim.treesitter.get_node_text(id_node, bufnr)
      if state_var_names[id_text] then
        -- vim.notify("Found state_variable in function body: " .. id_text, vim.log.levels.INFO)
        local start_row, start_col, end_row, end_col = id_node:range()
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = "@variable.builtin", -- Corresponds to @variable.builtin
        })
      elseif
        not local_names[id_text]
        and not builtin_identifiers[id_text]
        and not definition_names[id_text]
        and not is_function_call_identifier(id_node)
        and not is_member_expression_part(id_node)
      then
        local start_row, start_col, end_row, end_col = id_node:range()
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = "@variable.inherited",
        })
      end
    end
  end

  for _, query in ipairs(function_body_queries) do
    if query then
      for _, body_node, _ in query:iter_captures(root, bufnr, 0, -1) do
        process_body_node(body_node)
      end
    end
  end
end

local function apply_highlight_defaults()
  local function link(group, target)
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end

  link("@variable.member.solidity", "@variable")
  link("@keyword.function.solidity", "@keyword")
  link("@variable.parameter.solidity", "@variable")
  link("@function.method.call.solidity", "@variable")
  link("@variable.inherited.solidity", "@variable.builtin")
  link("@variable.inherited", "@variable.builtin")
end

-- Setup function to activate the highlighting via autocommands
function M.setup()
  apply_highlight_defaults()

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

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      apply_highlight_defaults()
    end,
  })
end

return M
