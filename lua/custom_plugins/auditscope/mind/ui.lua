-- lua/auditscope/mind/ui.lua
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local NuiTree = require("nui.tree")
local event = require("nui.utils.autocmd").event
local db = require("custom_plugins.auditscope.mind.db")
local ontology = require("custom_plugins.auditscope.mind.ontology")
local uv = vim.uv or vim.loop -- Add this line

local M = {}
local dashboard = nil
local pin_win = nil
local pinned_node = nil
local config = {}

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", {
    icons = {
      hypothesis = "❓",
      insight = "💡",
      fact = "📌",
      question = "🧐",
      finding = "🧭",
      decision = "🧷",
      evidence = "🔍",
      risk = "⚠️",
      note = "🗒️",
      assumption = "🧩",
      invariant = "🧱",
      supports = "✅",
      refutes = "❌",
      relates = "🔗",
    },
    auto_trace = false,
    show_glance = false,
  }, user_config or {})

  if config.auto_trace then
    M.set_auto_trace(true)
  end
end

local function sanitize_text(text)
  if not text then
    return ""
  end
  return text:gsub("[\r\n]+", " ")
end

local function sort_nodes_by_timestamp(nodes)
  table.sort(nodes, function(a, b)
    return (a.timestamp or 0) > (b.timestamp or 0)
  end)
  return nodes
end

local function build_partitions(nodes, mode)
  local groups = {}
  local list = {}
  for _, node in ipairs(nodes) do
    local key
    local label
    if mode == "file" then
      local rel = node.file and vim.fn.fnamemodify(node.file, ":.") or "unknown"
      key = "file:" .. rel
      label = rel
    else
      local node_type = node.type or "note"
      key = "type:" .. node_type
      label = string.format("%s %s", config.icons[node_type] or "🔹", node_type)
    end
    if not groups[key] then
      groups[key] = {
        key = key,
        label = label,
        nodes = {},
        latest = 0,
      }
    end
    table.insert(groups[key].nodes, node)
    local ts = node.timestamp or 0
    if ts > groups[key].latest then
      groups[key].latest = ts
    end
  end
  for _, group in pairs(groups) do
    sort_nodes_by_timestamp(group.nodes)
    table.insert(list, group)
  end
  table.sort(list, function(a, b)
    return (a.latest or 0) > (b.latest or 0)
  end)
  return list
end

local function update_tab_popup()
  if not dashboard or not dashboard.tab_popup then
    return
  end
  local mode = dashboard.partition_mode or "type"
  local type_label = mode == "type" and "[Type]" or " Type "
  local file_label = mode == "file" and "[File]" or " File "
  local lines = {
    string.format("Tabs: %s | %s", type_label, file_label),
    "Keys: t toggle | <Tab> focus | q close",
  }
  vim.api.nvim_buf_set_lines(dashboard.tab_popup.bufnr, 0, -1, false, lines)
end

-- 辅助：获取当前上下文
local function get_context()
  local file = vim.fn.expand("%:p")
  local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
  local selected_text = ""
  local start_line_to_use = current_line_num
  local end_line_to_use = current_line_num

  local mode = vim.fn.mode()
  if mode:find("v") then -- Check if in any visual mode ('v', 'V', '^V')
    local start_cursor_pos = vim.api.nvim_buf_get_mark(0, "<")
    local end_cursor_pos = vim.api.nvim_buf_get_mark(0, ">")

    if start_cursor_pos and end_cursor_pos then
      local start_line = start_cursor_pos[1]
      local end_line = end_cursor_pos[1]
      local start_col = start_cursor_pos[2]
      local end_col = end_cursor_pos[2]

      start_line_to_use = start_line
      end_line_to_use = end_line

      local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

      if #lines == 1 and start_line == end_line then
        selected_text = lines[1]:sub(start_col + 1, end_col + 1)
      else
        selected_text = table.concat(lines, "\n")
      end
    end
  else
    selected_text = vim.trim(vim.api.nvim_get_current_line())
  end

  -- If no selection or visual mode is not active, ensure text is current line
  if selected_text == "" then
    selected_text = vim.trim(vim.api.nvim_get_current_line())
    start_line_to_use = current_line_num
    end_line_to_use = current_line_num
  end

  local repo_context = db.get_repo_context()
  local effective_commit = db.get_effective_commit()

  return {
    file = file,
    start_line = start_line_to_use,
    end_line = end_line_to_use,
    text = selected_text,
    repo = repo_context,
    commit = effective_commit,
  }
end

local function format_line_range(start_line, end_line)
  if not start_line then
    return ""
  end
  if not end_line or start_line == end_line then
    return tostring(start_line)
  end
  return string.format("%d-%d", start_line, end_line)
end

local function unlink_node(source_node, on_complete)
  local edges = db.get_edges()
  local nodes = db.get_nodes()
  local node_map = {}
  for _, n in ipairs(nodes) do
    node_map[n.id] = n
  end

  local links = {}
  local link_map = {}

  for _, edge in ipairs(edges) do
    local other_node = nil
    local label_prefix = ""

    if edge.from == source_node.id then
      other_node = node_map[edge.to]
      label_prefix = "--> " .. (edge.relation or "relates")
    elseif edge.to == source_node.id then
      other_node = node_map[edge.from]
      label_prefix = "<-- " .. (edge.relation or "relates")
    end

    if other_node then
      local label = string.format(
        "%s: %s %s (%s)",
        label_prefix,
        config.icons[other_node.type] or "?",
        other_node.text,
        vim.fn.fnamemodify(other_node.file, ":t")
      )
      table.insert(links, label)
      link_map[label] = edge
    end
  end

  if #links == 0 then
    print("No links to remove.")
    return
  end

  vim.ui.select(links, { prompt = "Unlink node:" }, function(choice)
    if choice then
      local edge = link_map[choice]
      if db.delete_edge then
        -- Assuming db.delete_edge(from, to) or similar. Adjust based on actual db implementation.
        db.delete_edge(edge.from, edge.to)
        print("Link removed.")
      else
        print("Error: db.delete_edge not implemented.")
      end
      if on_complete then
        on_complete()
      end
    end
  end)
end

local function show_input_buffer(title, initial_value, on_submit, node_context)
  local input_popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " " .. title .. " ",
        top_align = "center",
        bottom = " <C-s> Submit | <Esc> Cancel" .. (node_context and " | <C-l> Link | <C-d> Unlink " or " "),
        bottom_align = "center",
      },
    },
    -- If using layout, size/position controlled by layout, else default
    position = node_context and nil or "50%",
    size = node_context and nil or { width = "60%", height = "40%" },
  })

  local layout = nil
  local info_popup = nil

  if node_context then
    info_popup = Popup({
      enter = false,
      focusable = false,
      border = {
        style = "rounded",
        text = { top = " Linked Nodes " },
      },
    })

    layout = Layout(
      {
        position = "50%",
        size = { width = "60%", height = "50%" },
      },
      Layout.Box({
        Layout.Box(info_popup, { size = "30%" }),
        Layout.Box(input_popup, { size = "70%" }),
      }, { dir = "col" })
    )
  end

  -- Refresh Info View
  local function refresh_info()
    if not info_popup or not node_context then
      return
    end
    local edges = db.get_edges()
    local nodes = db.get_nodes()
    local node_map = {}
    for _, n in ipairs(nodes) do
      node_map[n.id] = n
    end

    local lines = {}
    for _, edge in ipairs(edges) do
      local other = nil
      local rel_txt = ""
      if edge.from == node_context.id then
        other = node_map[edge.to]
        rel_txt = string.format("--> [%s] ", edge.relation)
      elseif edge.to == node_context.id then
        other = node_map[edge.from]
        rel_txt = string.format("<-- [%s] ", edge.relation)
      end

      if other then
        table.insert(lines, string.format("%s%s %s", rel_txt, config.icons[other.type] or "*", other.text))
      end
    end

    if #lines == 0 then
      table.insert(lines, "(No links)")
    end

    vim.api.nvim_buf_set_lines(info_popup.bufnr, 0, -1, false, lines)
  end

  -- Mount
  if layout then
    layout:mount()
    refresh_info()
  else
    input_popup:mount()
  end

  -- Set Content
  if initial_value and #initial_value > 0 then
    vim.api.nvim_buf_set_lines(input_popup.bufnr, 0, -1, false, vim.split(initial_value, "\n"))
  end

  -- Submit Handler
  local function submit()
    local lines = vim.api.nvim_buf_get_lines(input_popup.bufnr, 0, -1, false)
    local value = vim.trim(table.concat(lines, "\n"))
    if layout then
      layout:unmount()
    else
      input_popup:unmount()
    end
    on_submit(value)
  end

  local function close()
    if layout then
      layout:unmount()
    else
      input_popup:unmount()
    end
  end

  -- Mappings
  input_popup:map("n", "<C-s>", submit)
  input_popup:map("i", "<C-s>", submit)
  input_popup:map("n", "<Esc>", close)

  -- Add extra mappings if context exists
  if node_context then
    input_popup:map("i", "<C-l>", function()
      M.link_node(node_context, refresh_info)
    end)
    input_popup:map("n", "<C-l>", function()
      M.link_node(node_context, refresh_info)
    end)

    input_popup:map("i", "<C-d>", function()
      unlink_node(node_context, refresh_info)
    end)
    input_popup:map("n", "<C-d>", function()
      unlink_node(node_context, refresh_info)
    end)
  end

  -- Note: Removed BufLeave auto-close to support modals (vim.ui.select) used in link actions
end

local function show_input_split(title, initial_value, on_submit)
  local origin_win = vim.api.nvim_get_current_win()
  vim.cmd("botright 8split")

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = true

  vim.wo[win].wrap = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = true
  vim.wo[win].winfixheight = true
  if title and title ~= "" then
    vim.wo[win].winbar = " " .. title .. "  (<C-s> Save | <Esc> Save | <C-c> Cancel) "
  end

  if initial_value and #initial_value > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial_value, "\n"))
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_win_is_valid(origin_win) then
      vim.api.nvim_set_current_win(origin_win)
    end
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local value = vim.trim(table.concat(lines, "\n"))
    close()
    on_submit(value)
  end

  local function cancel()
    close()
  end

  vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buf })
  vim.keymap.set({ "n", "i" }, "<Esc>", submit, { buffer = buf })
  vim.keymap.set({ "n", "i" }, "<C-c>", cancel, { buffer = buf })
end

-- Pin window management
local function create_pin_window()
  if pin_win then
    pin_win:unmount()
  end

  pin_win = Popup({
    enter = false,
    focusable = false,
    border = {
      style = "rounded",
      text = {
        top = " 📌 Pinned ",
        top_align = "center",
      },
    },
    position = {
      row = 1,
      col = "100%",
    },
    size = {
      width = 40,
      height = 5,
    },
    anchor = "NE",
    zindex = 50,
  })

  pin_win:mount()

  -- Don't close on BufLeave - keep it persistent
  return pin_win
end

local function update_pin_content()
  if not pin_win or not pinned_node then
    return
  end

  local lines = {}
  local icon = config.icons[pinned_node.type] or "🔹"
  table.insert(lines, string.format("%s %s", icon, pinned_node.type:upper()))
  table.insert(lines, "")

  -- Sanitize and wrap text to fit window width
  local text = sanitize_text(pinned_node.text) or ""
  local max_width = 38
  for i = 1, #text, max_width do
    local line = text:sub(i, i + max_width - 1)
    -- Ensure no newlines in each line segment
    line = line:gsub("[\r\n]+", " ")
    table.insert(lines, line)
  end

  -- Ensure all lines are valid strings without newlines
  for idx, line in ipairs(lines) do
    lines[idx] = tostring(line):gsub("[\r\n]+", " ")
  end

  vim.api.nvim_buf_set_lines(pin_win.bufnr, 0, -1, false, lines)
end

function M.pin_node()
  local nodes = db.get_nodes()
  local items = {}
  local node_map = {}

  for _, n in ipairs(nodes) do
    if n.type == "question" or n.type == "hypothesis" then
      local label = string.format(
        "%s %s (%s:%s)",
        config.icons[n.type],
        n.text,
        vim.fn.fnamemodify(n.file, ":t"),
        format_line_range(n.start_line, n.end_line)
      )
      table.insert(items, label)
      node_map[label] = n
    end
  end

  if #items == 0 then
    print("No questions or hypotheses to pin.")
    return
  end

  vim.ui.select(items, { prompt = "Select node to pin:" }, function(choice)
    if not choice then
      return
    end

    pinned_node = node_map[choice]
    create_pin_window()
    update_pin_content()
    print("Pinned: " .. pinned_node.text)
  end)
end

function M.unpin_node()
  if pin_win then
    pin_win:unmount()
    pin_win = nil
  end
  pinned_node = nil
  print("Unpinned node.")
end

function M.toggle_pin()
  if pin_win and pinned_node then
    M.unpin_node()
  else
    M.pin_node()
  end
end

function M.get_pinned_node()
  return pinned_node
end

-- 1. 创建新节点
function M.create_node(type, opts)
  opts = opts or {}
  local ctx = get_context()

  local input_fn = show_input_buffer
  if opts.input == "split" then
    input_fn = show_input_split
  end

  input_fn("New " .. type, "", function(value)
    if value and #value > 0 then
      local repo = ctx.repo or {}
      local node = {
        id = tostring(os.time()) .. math.random(100, 999),
        type = type,
        text = value,
        file = ctx.file,
        start_line = ctx.start_line,
        end_line = ctx.end_line,
        code_snippet = ctx.text,
        repo_root = repo.root,
        repo_name = repo.name,
        repo_remote = repo.remote,
        commit = ctx.commit or repo.commit,
        timestamp = os.time(),
      }
      db.add_node(node)
      print("Node added: " .. value)

      -- 创建完节点后，询问是否要连接（Workflow）
      vim.defer_fn(function()
        M.link_node(node)
      end, 100)
    end
  end)
end

-- 2. 连接节点 (Link)
function M.link_node(source_node, on_complete)
  local nodes = db.get_nodes()
  if #nodes <= 1 then
    print("No other nodes to link.")
    return
  end

  local items = {}
  local node_map = {}

  for _, n in ipairs(nodes) do
    if n.id ~= source_node.id then
      local label = string.format(
        "%s %s (%s:%d)",
        config.icons[n.type],
        n.text,
        vim.fn.fnamemodify(n.file, ":t"),
        format_line_range(n.start_line, n.end_line)
      )
      table.insert(items, label)
      node_map[label] = n
    end
  end

  vim.ui.select(items, { prompt = "Link to existing thought?" }, function(choice)
    if not choice then
      return
    end
    local target = node_map[choice]

    vim.ui.select({ "supports", "refutes", "relates" }, { prompt = "Relation Type:" }, function(rel)
      if rel then
        if not ontology.is_link_allowed(source_node.type, target.type) then
          vim.notify(
            string.format(
              "AuditScope: link violates level rule (%s -> %s).",
              tostring(source_node.type or "unknown"),
              tostring(target.type or "unknown")
            ),
            vim.log.levels.WARN
          )
        end
        db.add_edge(source_node.id, target.id, rel)
        print(string.format("Linked: %s --[%s]--> %s", source_node.text, rel, target.text))
        if dashboard then
          M.refresh_dashboard()
        end
        if on_complete then
          on_complete()
        end
      end
    end)
  end)
end

-- 3. Dashboard (思维导图视图)
function M.toggle_dashboard()
  if dashboard and dashboard.layout then
    dashboard.layout:unmount()
    dashboard = nil
    return
  end

  local subject = db.get_subject()
  local title = subject and subject.title or "AuditMind Graph"

  local tab_popup = Popup({
    enter = false,
    focusable = false,
    border = { style = "rounded", text = { top = " " .. title .. " " } },
  })

  local partition_popup = Popup({
    enter = true,
    focusable = true,
    border = { style = "rounded", text = { top = " Partitions " } },
  })

  local list_popup = Popup({
    enter = false,
    focusable = true,
    border = { style = "rounded", text = { top = " Nodes " } },
  })

  local detail_popup = Popup({
    enter = false,
    focusable = false,
    border = { style = "rounded", text = { top = " Details " } },
  })

  local layout = Layout(
    {
      position = "50%",
      size = { width = "90%", height = "90%" },
    },
    Layout.Box({
      Layout.Box({
        Layout.Box(tab_popup, { size = 3 }),
        Layout.Box(partition_popup, { size = "40%" }),
        Layout.Box(list_popup, { size = "60%" }),
      }, { dir = "col", size = "60%" }),
      Layout.Box(detail_popup, { size = "40%" }),
    }, { dir = "row" })
  )

  dashboard = {
    layout = layout,
    tab_popup = tab_popup,
    partition_popup = partition_popup,
    list_popup = list_popup,
    detail_popup = detail_popup,
    partition_tree = nil,
    list_tree = nil,
    partitions = {},
    nodes = {},
    partition_mode = "type",
    selected_partition_key = nil,
    selected_node_id = nil,
  }

  layout:mount()
  update_tab_popup()

  local function close_dashboard()
    if dashboard and dashboard.layout then
      dashboard.layout:unmount()
      dashboard = nil
    end
  end

  local function focus_list()
    if dashboard and dashboard.list_popup and dashboard.list_popup.winid then
      vim.api.nvim_set_current_win(dashboard.list_popup.winid)
    end
  end

  local function focus_partitions()
    if dashboard and dashboard.partition_popup and dashboard.partition_popup.winid then
      vim.api.nvim_set_current_win(dashboard.partition_popup.winid)
    end
  end

  local function toggle_tab()
    if not dashboard then
      return
    end
    dashboard.partition_mode = dashboard.partition_mode == "type" and "file" or "type"
    dashboard.selected_partition_key = nil
    dashboard.selected_node_id = nil
    update_tab_popup()
    M.refresh_dashboard()
  end

  -- 快捷键：回车跳转到代码
  list_popup:map("n", "<CR>", function()
    local tree = dashboard and dashboard.list_tree or nil
    if not tree then
      return
    end
    local node = tree:get_node()
    if node and node.data and node.data.file then
      close_dashboard()
      vim.cmd("e " .. node.data.file)
      vim.api.nvim_win_set_cursor(0, { node.data.start_line, 0 })
    end
  end)

  partition_popup:map("n", "q", close_dashboard)
  partition_popup:map("n", "t", toggle_tab)
  partition_popup:map("n", "<Tab>", focus_list)

  list_popup:map("n", "q", close_dashboard)
  list_popup:map("n", "t", toggle_tab)
  list_popup:map("n", "<S-Tab>", focus_partitions)
  list_popup:map("n", "<Tab>", focus_partitions)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = partition_popup.bufnr,
    callback = function()
      if not dashboard or not dashboard.partition_tree then
        return
      end
      local node = dashboard.partition_tree:get_node()
      if node and node.data and node.data.key ~= dashboard.selected_partition_key then
        dashboard.selected_partition_key = node.data.key
        dashboard.selected_node_id = nil
        M.refresh_dashboard_list()
      end
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_popup.bufnr,
    callback = function()
      if not dashboard or not dashboard.list_tree then
        return
      end
      local node = dashboard.list_tree:get_node()
      if node and node.data then
        if dashboard.selected_node_id ~= node.data.id then
          dashboard.selected_node_id = node.data.id
        end
        M.refresh_dashboard_details()
      end
    end,
  })

  M.refresh_dashboard()
end

function M.refresh_dashboard_details()
  if not dashboard or not dashboard.list_tree or not dashboard.detail_popup then
    return
  end
  local node = dashboard.list_tree:get_node()
  if not node or not node.data then
    vim.api.nvim_buf_set_lines(dashboard.detail_popup.bufnr, 0, -1, false, { "No node selected." })
    return
  end

  local data = node.data
  local lines = {}

  local function add_line(value)
    if value and value ~= "" then
      table.insert(lines, value)
    end
  end

  local function wrap_text(text, width)
    local out = {}
    local current = ""
    for word in tostring(text):gmatch("%S+") do
      if #current == 0 then
        current = word
      elseif #current + #word + 1 <= width then
        current = current .. " " .. word
      else
        table.insert(out, current)
        current = word
      end
    end
    if current ~= "" then
      table.insert(out, current)
    end
    return out
  end

  local width = 60
  if dashboard.detail_popup.winid and vim.api.nvim_win_is_valid(dashboard.detail_popup.winid) then
    width = math.max(20, vim.api.nvim_win_get_width(dashboard.detail_popup.winid) - 2)
  end

  add_line(string.format("Type: %s", data.type or "note"))
  add_line("")
  add_line("Keys: <CR> open | t tabs | <Tab> focus | q close")
  add_line("")
  add_line("Text:")
  local wrapped = wrap_text(data.text or "", width)
  if #wrapped == 0 then
    table.insert(lines, "  (empty)")
  else
    for _, line in ipairs(wrapped) do
      table.insert(lines, "  " .. line)
    end
  end

  add_line("")
  if data.repo_name then
    add_line("Repo: " .. data.repo_name)
  end
  if data.file and data.start_line then
    add_line(string.format("Location: %s:%s", vim.fn.fnamemodify(data.file, ":."), format_line_range(data.start_line, data.end_line)))
  end
  if data.commit then
    add_line("Commit: " .. data.commit)
  end

  local edges = db.get_edges()
  local incoming = {}
  local outgoing = {}
  for _, edge in ipairs(edges) do
    if edge.to == data.id then
      table.insert(incoming, edge)
    elseif edge.from == data.id then
      table.insert(outgoing, edge)
    end
  end

  if #incoming > 0 then
    add_line("")
    add_line("Incoming:")
    for _, edge in ipairs(incoming) do
      table.insert(lines, string.format("  <- [%s] %s", edge.relation or "relates", edge.from or "unknown"))
    end
  end

  if #outgoing > 0 then
    add_line("")
    add_line("Outgoing:")
    for _, edge in ipairs(outgoing) do
      table.insert(lines, string.format("  -> [%s] %s", edge.relation or "relates", edge.to or "unknown"))
    end
  end

  vim.api.nvim_buf_set_lines(dashboard.detail_popup.bufnr, 0, -1, false, lines)
end

function M.refresh_dashboard_partitions()
  if not dashboard or not dashboard.partition_popup then
    return
  end

  local partition_nodes = {}
  for _, part in ipairs(dashboard.partitions or {}) do
    local label = string.format("%s (%d)", part.label, #part.nodes)
    table.insert(
      partition_nodes,
      NuiTree.Node({
        text = label,
        data = { key = part.key, partition = part },
      })
    )
  end

  dashboard.partition_tree = NuiTree({
    nodes = partition_nodes,
    bufnr = dashboard.partition_popup.bufnr,
    get_node_id = function(node)
      return node.data and node.data.key or tostring(node.text)
    end,
  })
  dashboard.partition_tree:render()

  local selected_key = dashboard.selected_partition_key
  if selected_key then
    local _, start_line = dashboard.partition_tree:get_node(selected_key)
    if start_line and dashboard.partition_popup.winid and vim.api.nvim_win_is_valid(dashboard.partition_popup.winid) then
      vim.api.nvim_win_set_cursor(dashboard.partition_popup.winid, { start_line, 0 })
    else
      dashboard.selected_partition_key = nil
    end
  end

  if not dashboard.selected_partition_key and #partition_nodes > 0 then
    dashboard.selected_partition_key = partition_nodes[1].data.key
    if dashboard.partition_popup.winid and vim.api.nvim_win_is_valid(dashboard.partition_popup.winid) then
      vim.api.nvim_win_set_cursor(dashboard.partition_popup.winid, { 1, 0 })
    end
  end
end

function M.refresh_dashboard_list()
  if not dashboard or not dashboard.list_popup then
    return
  end

  local selected_partition = nil
  for _, part in ipairs(dashboard.partitions or {}) do
    if part.key == dashboard.selected_partition_key then
      selected_partition = part
      break
    end
  end

  if not selected_partition and #dashboard.partitions > 0 then
    selected_partition = dashboard.partitions[1]
    dashboard.selected_partition_key = selected_partition.key
  end

  local list_nodes = {}
  if selected_partition then
    for _, node in ipairs(selected_partition.nodes) do
      table.insert(
        list_nodes,
        NuiTree.Node({
          text = string.format("%s %s", config.icons[node.type] or "🔹", sanitize_text(node.text)),
          data = node,
        })
      )
    end
  end

  dashboard.list_tree = NuiTree({
    nodes = list_nodes,
    bufnr = dashboard.list_popup.bufnr,
    get_node_id = function(node)
      return node.data and node.data.id or tostring(node.text)
    end,
  })
  dashboard.list_tree:render()

  if dashboard.selected_node_id then
    local _, start_line = dashboard.list_tree:get_node(dashboard.selected_node_id)
    if start_line and dashboard.list_popup.winid and vim.api.nvim_win_is_valid(dashboard.list_popup.winid) then
      vim.api.nvim_win_set_cursor(dashboard.list_popup.winid, { start_line, 0 })
    else
      dashboard.selected_node_id = nil
    end
  end

  if not dashboard.selected_node_id and #list_nodes > 0 then
    dashboard.selected_node_id = list_nodes[1].data.id
    if dashboard.list_popup.winid and vim.api.nvim_win_is_valid(dashboard.list_popup.winid) then
      vim.api.nvim_win_set_cursor(dashboard.list_popup.winid, { 1, 0 })
    end
  end

  M.refresh_dashboard_details()
end

function M.refresh_dashboard()
  if not dashboard or not dashboard.partition_popup or not dashboard.list_popup then
    return
  end

  local nodes = db.get_nodes()
  dashboard.nodes = nodes
  dashboard.partitions = build_partitions(nodes, dashboard.partition_mode)
  M.refresh_dashboard_partitions()
  M.refresh_dashboard_list()
end

-- 4. 删除节点
function M.delete_node()
  local nodes = db.get_nodes()
  if #nodes == 0 then
    print("No nodes to delete.")
    return
  end

  local items = {}
  local node_map = {}
  for _, n in ipairs(nodes) do
    local label = string.format(
      "%s %s (%s:%d)",
      config.icons[n.type],
      n.text,
      vim.fn.fnamemodify(n.file, ":t"),
      format_line_range(n.start_line, n.end_line)
    )
    table.insert(items, label)
    node_map[label] = n
  end

  vim.ui.select(items, { prompt = "Select node to delete:" }, function(choice)
    if not choice then
      return
    end
    local node_to_delete = node_map[choice]
    if node_to_delete then
      db.delete_node(node_to_delete.id)
      print("Node deleted: " .. node_to_delete.text)
      if dashboard then
        M.refresh_dashboard()
      end
    end
  end)
end

-- 5. 修改节点
function M.modify_node()
  local raw_nodes = db.get_nodes()
  if #raw_nodes == 0 then
    print("No nodes to modify.")
    return
  end

  -- 创建列表副本以进行排序，避免影响原始数据
  local nodes = {}
  for _, n in ipairs(raw_nodes) do
    table.insert(nodes, n)
  end

  -- 获取当前上下文用于智能排序
  local current_file = vim.fn.expand("%:p")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  -- 计算节点与当前光标的相关性距离
  local function get_relevance_score(n)
    -- 如果不是当前文件，优先级最低（距离设为无穷大）
    if n.file ~= current_file then
      return math.huge
    end

    local start_line = n.start_line or 0
    local end_line = n.end_line or start_line

    -- 光标在节点范围内：最高优先级（距离为0）
    if current_line >= start_line and current_line <= end_line then
      return 0
    end

    -- 计算到范围边界的最近距离
    if current_line < start_line then
      return start_line - current_line
    else
      return current_line - end_line
    end
  end

  table.sort(nodes, function(a, b)
    local score_a = get_relevance_score(a)
    local score_b = get_relevance_score(b)

    -- 距离越小越靠前
    if score_a ~= score_b then
      return score_a < score_b
    end

    -- 距离相同时（例如都是其他文件），按时间倒序（最新的在前）
    return (a.timestamp or 0) > (b.timestamp or 0)
  end)

  local items = {}
  local node_map = {}
  for _, n in ipairs(nodes) do
    local label = string.format(
      "%s %s (%s:%d)",
      config.icons[n.type],
      n.text,
      vim.fn.fnamemodify(n.file, ":t"),
      format_line_range(n.start_line, n.end_line)
    )
    table.insert(items, label)
    node_map[label] = n
  end

  vim.ui.select(items, { prompt = "Select node to modify:" }, function(choice)
    if not choice then
      return
    end
    local node_to_modify = node_map[choice]

    if node_to_modify then
      -- Pass node_to_modify to show_input_buffer context
      show_input_split("Modify Node", node_to_modify.text, function(value)
        if value and #value > 0 then
          node_to_modify.text = value
          db.update_node(node_to_modify)
          print("Node modified: " .. value)
          if dashboard then
            M.refresh_dashboard()
          end
        end
      end, node_to_modify)
    end
  end)
end

-- 6. Attention / Glance Tracking (tqdm style)
local glance_ns = vim.api.nvim_create_namespace("auditscope_glance")
local PARTIAL_BLOCKS = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" }
local MAX_GLANCE_LEVEL = 10

local function get_file_max_glance(file)
  local data = db.get_glance(file)
  local max_val = 20 -- 基础阈值，避免初期数据较少时进度条波动过大
  for _, count in pairs(data) do
    if count > max_val then
      max_val = count
    end
  end
  return max_val
end

local function update_glance_extmark(bufnr, file, line, count)
  if not config.show_glance then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, glance_ns, line - 1, line)
  if count <= 0 then
    return
  end

  -- Calculate scale based on the file's max activity (min 20)
  local max_level = get_file_max_glance(file)
  max_level = math.max(max_level, count)

  -- Use a fixed width (e.g., 25 chars) to ensure consistent precision measurement
  local width = 25
  -- Calculate ratio against the actual max_level, not a hardcoded constant
  local ratio = count / max_level

  if ratio > 1.0 then
    ratio = 1.0
  end

  -- Calculate total 1/8th ticks
  local total_ticks = math.floor(ratio * width * 8)
  local full_blocks = math.floor(total_ticks / 8)
  local remainder = total_ticks % 8

  local bar_str = string.rep("█", full_blocks)
  if remainder > 0 then
    bar_str = bar_str .. PARTIAL_BLOCKS[remainder]
  end

  local current_len = full_blocks + (remainder > 0 and 1 or 0)
  local empty = width - current_len
  local empty_str = string.rep(" ", math.max(0, empty))

  local h_group = "String" -- Greenish usually
  if ratio > 0.8 then
    h_group = "Error" -- Red/High attention
  elseif ratio > 0.4 then
    h_group = "WarningMsg" -- Yellow/Orange
  end

  local virt_text = {
    { " ▕", "Comment" },
    { bar_str, h_group },
    { empty_str, "Comment" },
    { string.format("▏%4d", count), "Comment" },
  }

  vim.api.nvim_buf_set_extmark(bufnr, glance_ns, line - 1, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol_right_align",
    hl_mode = "blend",
  })
end

function M.increment_glance(skip_save)
  local file = vim.fn.expand("%:p")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = vim.api.nvim_get_current_buf()

  local current_data = db.get_glance(file)

  -- keys are strings in JSON/DB
  local current_count = current_data[tostring(line)] or 0
  local new_count = current_count + 1

  db.update_glance(file, line, new_count, skip_save)
  update_glance_extmark(bufnr, file, line, new_count)
end

function M.decrement_glance()
  local file = vim.fn.expand("%:p")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = vim.api.nvim_get_current_buf()

  local current_data = db.get_glance(file)
  local current_count = current_data[tostring(line)] or 0

  if current_count > 0 then
    local new_count = current_count - 1
    db.update_glance(file, line, new_count)
    update_glance_extmark(bufnr, file, line, new_count)
  end
end

function M.toggle_auto_trace()
  M.set_auto_trace(not AUTO_TRACE_ENABLED)
end

function M.set_auto_trace(enabled)
  AUTO_TRACE_ENABLED = enabled
  local group_name = "AuditScopeAutoTrace"
  vim.api.nvim_create_augroup(group_name, { clear = true })

  if enabled then
    -- Save DB on specific events to prevent data loss when skip_save is used
    vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "VimLeavePre" }, {
      group = group_name,
      callback = function()
        db.save()
      end,
    })

    -- Trace logic with debounce (200ms)
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = group_name,
      callback = function()
        if TRACE_TIMER then
          TRACE_TIMER:stop()
          if not TRACE_TIMER:is_closing() then
            TRACE_TIMER:close()
          end
        end

        TRACE_TIMER = uv.new_timer()
        TRACE_TIMER:start(
          200,
          0,
          vim.schedule_wrap(function()
            if not AUTO_TRACE_ENABLED then
              return
            end
            local file = vim.fn.expand("%:p")
            local line = vim.api.nvim_win_get_cursor(0)[1]
            local pos_key = file .. ":" .. line

            -- Only increment if we have settled on a new line/file position
            if pos_key ~= LAST_TRACE_POS then
              LAST_TRACE_POS = pos_key
              -- Skip immediate save for performance
              M.increment_glance(true)
            end

            if TRACE_TIMER and not TRACE_TIMER:is_closing() then
              TRACE_TIMER:close()
            end
            TRACE_TIMER = nil
          end)
        )
      end,
    })
    print("AuditScope: Auto Trace Enabled")
  else
    if TRACE_TIMER then
      TRACE_TIMER:stop()
      if not TRACE_TIMER:is_closing() then
        TRACE_TIMER:close()
      end
      TRACE_TIMER = nil
    end
    print("AuditScope: Auto Trace Disabled")
  end
end

function M.clean_glance()
  local file = vim.fn.expand("%:p")
  db.clean_glance(file)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, glance_ns, 0, -1)
end

function M.toggle_show_glance()
  config.show_glance = not config.show_glance
  local file = vim.fn.expand("%:p")
  local bufnr = vim.api.nvim_get_current_buf()
  if config.show_glance then
    -- Reapply marks for current file
    local data = db.get_glance(file)
    for line_str, count in pairs(data) do
      local line = tonumber(line_str)
      if line then
        update_glance_extmark(bufnr, file, line, count)
      end
    end
  else
    -- Clear all glance marks in buffer
    vim.api.nvim_buf_clear_namespace(bufnr, glance_ns, 0, -1)
  end
  print("Glance display " .. (config.show_glance and "enabled" or "disabled"))
end

-- Restore glance marks when entering a buffer
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("AuditScopeGlanceRestore", { clear = true }),
  callback = function(args)
    local file = vim.api.nvim_buf_get_name(args.buf)
    if not file or file == "" then
      return
    end

    if not (file:match("%.sol$") or file:match("%.rs$")) then
      return
    end

    local data = db.get_glance(file)

    local max_val = 20
    for _, count in pairs(data) do
      if count > max_val then
        max_val = count
      end
    end

    for line_str, count in pairs(data) do
      local line = tonumber(line_str)
      if line then
        update_glance_extmark(args.buf, file, line, count)
      end
    end
  end,
})

return M
