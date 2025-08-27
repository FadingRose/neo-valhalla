local M = {}

local separator = package.config:sub(1, 1)

local dir_root = function()
  local git_dir = vim.fn.finddir(".git", vim.fn.getcwd() .. ";")

  if git_dir == "" then
    return nil
  end
  return git_dir
end

local auditor_root = function()
  local root = dir_root()
  if not root then
    return nil
  end
  return root .. separator .. ".auditor"
end

local scope_cache = nil

function M.setup(opts)
  opts = opts or {}
  vim.keymap.set("n", "<D-a>sl", function()
    local scope = M.get_scope()
    if not scope then
      print("No scope information available.")
      return
    end

    local includes = M.get_include_paths()
    if #includes == 0 then
      print("No 'include' paths found in scope.")
      return
    end

    print("Audit Scope 'include' Paths:")
    for _, path in ipairs(includes) do
      print("- " .. path)
    end
  end, { desc = "List Audit Scope" })
end

function M.add_scope()
  local telescope = require("telescope.builtin")

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values

  local root = dir_root()
  if not root then
    vim.notify("Could not find project root.", vim.log.levels.ERROR)
    return
  end

  local function add_selections_to_scope(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local selections = picker:get_multi_selection()

    if vim.tbl_isempty(selections) then
      local current_entry = action_state.get_selected_entry()
      if current_entry then
        selections = { current_entry }
      else
        return -- No selection made
      end
    end
    actions.close(prompt_bufnr)

    local items = {}
    for _, entry in ipairs(selections) do
      table.insert(items, entry.value) -- `entry.value` holds the full file path.
    end

    if #items == 0 then
      return
    end

    local auditor_path = auditor_root()
    if not auditor_path then
      return
    end

    -- Ensure .auditor directory exists
    if vim.fn.isdirectory(auditor_path) == 0 then
      vim.fn.mkdir(auditor_path, "p")
    end

    local scope_file_path = auditor_path .. separator .. "scope.txt"

    -- create scope file if it doesn't exist
    if vim.fn.filereadable(scope_file_path) == 0 then
      local file = io.open(scope_file_path, "w")
      if file then
        file:close()
      else
        vim.notify("Failed to create scope file: " .. scope_file_path, vim.log.levels.ERROR)
        return
      end
    end

    -- Read existing lines to avoid duplicates
    local existing_lines = {}
    if vim.fn.filereadable(scope_file_path) == 1 then
      for _, line in ipairs(vim.fn.readfile(scope_file_path)) do
        existing_lines[vim.trim(line)] = true
      end
    end

    local file = io.open(scope_file_path, "a")
    if not file then
      vim.notify("Failed to open scope file: " .. scope_file_path, vim.log.levels.ERROR)
      return
    end

    local new_lines_count = 0
    for _, path in ipairs(items) do
      -- Make path relative to project root
      local rel_path = path:gsub(root .. separator, "", 1)
      local line_to_add = "+ " .. rel_path

      if not existing_lines[line_to_add] then
        file:write(line_to_add .. "\n")
        new_lines_count = new_lines_count + 1
      end
    end
    file:close()

    if new_lines_count > 0 then
      M.clear_cache()
      vim.notify("Added " .. new_lines_count .. " file(s) to audit scope.")
    else
      vim.notify("Selected file(s) are already in the audit scope.")
    end
  end

  -- Use Telescope's file finder
  require("telescope.builtin").git_files({
    -- search_file = "*.sol",
    attach_mappings = function(prompt_bufnr, map)
      -- Map <CR> to our custom action in both insert and normal mode.
      -- This will process single and multiple selections.
      map({ "i", "n" }, "<CR>", function()
        add_selections_to_scope(prompt_bufnr)
      end)
      return true
    end,
  })
end

--- Get list of 'include' paths from scope.txt
---@return table|nil
function M.get_scope()
  if scope_cache ~= nil then
    return scope_cache
  end

  local scope_file = auditor_root() .. separator .. "scope.txt"
  if vim.fn.filereadable(scope_file) == 0 then
    M.add_scope()
  end

  return scope_cache
end

--- 清除缓存，以便下次调用时重新加载
function M.clear_cache()
  scope_cache = nil
end

return M
