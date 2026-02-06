local M = {}

local default_config = {
  persist = true,
  storage_path = vim.fn.stdpath("state") .. "/tab-extend/tabnames.json",
  project_key = nil, -- string or function() -> string
  use_tabline = false,
}

local function resolve_project_key(config)
  if type(config.project_key) == "function" then
    return config.project_key()
  end
  if type(config.project_key) == "string" and config.project_key ~= "" then
    return config.project_key
  end
  return vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
end

local function read_store(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local content = table.concat(vim.fn.readfile(path), "\n")
  if content == "" then
    return {}
  end
  local ok, decoded = pcall(vim.fn.json_decode, content)
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local function write_store(path, data)
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local encoded = vim.fn.json_encode(data)
  if not encoded then
    return
  end
  vim.fn.writefile({ encoded }, path)
end

local function get_tab_name(tabpage)
  return vim.t[tabpage].tab_name
end

local function set_tab_name(tabpage, name)
  local trimmed = vim.trim(name or "")
  if trimmed == "" then
    vim.t[tabpage].tab_name = nil
    return false
  end
  vim.t[tabpage].tab_name = trimmed
  return true
end

local function tab_display_name(tabpage)
  local name = get_tab_name(tabpage)
  if name and name ~= "" then
    return name
  end
  local num = vim.api.nvim_tabpage_get_number(tabpage)
  return "Tab " .. num
end

local function tab_context(tabpage)
  local win = vim.api.nvim_tabpage_get_win(tabpage)
  if not win or win == 0 then
    return ""
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local bufname = vim.api.nvim_buf_get_name(buf)
  if bufname == "" then
    return "[No Name]"
  end
  return vim.fn.fnamemodify(bufname, ":t")
end

function M.save()
  if not M.config.persist or not M.project_key then
    return
  end
  local tabs = vim.api.nvim_list_tabpages()
  local names = {}
  for _, tabpage in ipairs(tabs) do
    local name = get_tab_name(tabpage) or ""
    table.insert(names, name)
  end

  local data = read_store(M.config.storage_path)
  data[M.project_key] = names
  write_store(M.config.storage_path, data)
end

function M.load()
  if not M.config.persist or not M.project_key then
    return
  end
  local data = read_store(M.config.storage_path)
  local names = data[M.project_key]
  if type(names) ~= "table" then
    return
  end
  local tabs = vim.api.nvim_list_tabpages()
  for idx, tabpage in ipairs(tabs) do
    local name = names[idx]
    if type(name) == "string" and name ~= "" then
      set_tab_name(tabpage, name)
    end
  end
end

function M.rename(new_name)
  local tabpage = vim.api.nvim_get_current_tabpage()
  if new_name and new_name ~= "" then
    local ok = set_tab_name(tabpage, new_name)
    if ok then
      M.save()
    else
      vim.notify("Tab name cleared.", vim.log.levels.INFO)
      M.save()
    end
    return
  end

  local current = get_tab_name(tabpage) or ""
  vim.ui.input({ prompt = "Tab name: ", default = current }, function(input)
    if input == nil then
      return
    end
    local ok = set_tab_name(tabpage, input)
    if ok then
      vim.notify("Tab renamed to: " .. get_tab_name(tabpage))
    else
      vim.notify("Tab name cleared.", vim.log.levels.INFO)
    end
    M.save()
  end)
end

function M.pick_tab()
  local tabs = vim.api.nvim_list_tabpages()
  if #tabs == 0 then
    vim.notify("No tabs available.", vim.log.levels.WARN)
    return
  end
  local items = {}
  for _, tabpage in ipairs(tabs) do
    local num = vim.api.nvim_tabpage_get_number(tabpage)
    local name = tab_display_name(tabpage)
    local context = tab_context(tabpage)
    local label = string.format("%d. %s - %s", num, name, context)
    table.insert(items, { tabpage = tabpage, label = label })
  end

  vim.ui.select(items, {
    prompt = "Switch to tab",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    vim.api.nvim_set_current_tabpage(choice.tabpage)
  end)
end

function M.tabline()
  local line = ""
  local current = vim.api.nvim_get_current_tabpage()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local num = vim.api.nvim_tabpage_get_number(tabpage)
    local name = tab_display_name(tabpage)
    local hl = tabpage == current and "%#TabLineSel#" or "%#TabLine#"
    line = line .. hl .. " " .. num .. ":" .. name .. " "
  end
  line = line .. "%#TabLineFill#"
  return line
end

local function setup_commands()
  vim.api.nvim_create_user_command("TabRename", function(opts)
    M.rename(opts.args)
  end, { nargs = "?", desc = "Rename current tab (empty clears)" })

  vim.api.nvim_create_user_command("TabList", function()
    M.pick_tab()
  end, { desc = "List and switch tabs" })
end

local function setup_autocmds()
  if not M.config.persist then
    return
  end
  local group = vim.api.nvim_create_augroup("TabExtend", { clear = true })
  vim.api.nvim_create_autocmd({ "VimLeavePre", "TabClosed" }, {
    group = group,
    callback = function()
      M.save()
    end,
  })
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      M.load()
    end,
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
  M.project_key = resolve_project_key(M.config)

  setup_commands()
  setup_autocmds()
  M.load()

  if M.config.use_tabline then
    vim.o.tabline = "%!v:lua.require('custom_plugins.tab-extend').tabline()"
  end
end

return M
