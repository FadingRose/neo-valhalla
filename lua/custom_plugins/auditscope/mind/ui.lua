-- lua/auditscope/mind/ui.lua
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local NuiTree = require("nui.tree")
local event = require("nui.utils.autocmd").event
local db = require("custom_plugins.auditscope.mind.db")
local uv = vim.uv or vim.loop -- Add this line

local M = {}
local dashboard_win = nil
local config = {}

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", {
    icons = {
      hypothesis = "❓",
      insight = "💡",
      fact = "📌",
      question = "🧐",
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

  return {
    file = file,
    start_line = start_line_to_use,
    end_line = end_line_to_use,
    text = selected_text,
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

-- Pin window management
local function create_pin_window()
  if pin_win then
    pin_win:unmount()
  end

  local pin_win = Popup({
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

    local pinned_node = node_map[choice]
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
function M.create_node(type)
  local ctx = get_context()

  show_input_buffer("New " .. type, "", function(value)
    if value and #value > 0 then
      local node = {
        id = tostring(os.time()) .. math.random(100, 999),
        type = type,
        text = value,
        file = ctx.file,
        start_line = ctx.start_line,
        end_line = ctx.end_line,
        code_snippet = ctx.text,
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
        db.add_edge(source_node.id, target.id, rel)
        print(string.format("Linked: %s --[%s]--> %s", source_node.text, rel, target.text))
        if dashboard_win then
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
  if dashboard_win then
    dashboard_win:unmount()
    dashboard_win = nil
    return
  end

  dashboard_win = Popup({
    enter = true,
    focusable = true,
    border = { style = "rounded", text = { top = " AuditMind Graph " } },
    position = {
      row = "50%", -- Center vertically
      col = "50%", -- Anchor to the right
    },
    size = { width = "90%", height = "90%" },
  })
  dashboard_win:mount()

  dashboard_win:on(event.BufLeave, function()
    dashboard_win:unmount()
    dashboard_win = nil
  end)

  -- 快捷键：回车跳转到代码
  dashboard_win:map("n", "<CR>", function()
    local tree = dashboard_win.tree
    local node = tree:get_node()
    if node and node.data and node.data.file then
      dashboard_win:unmount()
      dashboard_win = nil
      vim.cmd("e " .. node.data.file)
      vim.api.nvim_win_set_cursor(0, { node.data.start_line, 0 })
    end
  end)

  local function toggle_expand()
    local tree = dashboard_win.tree
    local node = tree:get_node()
    if node and node:has_children() then
      if node:is_expanded() then
        node:collapse()
      else
        node:expand()
      end
      tree:render()
    end
  end

  dashboard_win:map("n", "<Tab>", toggle_expand)
  dashboard_win:map("n", "o", toggle_expand)
  M.refresh_dashboard()
end

function M.refresh_dashboard()
  if not dashboard_win then
    return
  end

  local nodes = db.get_nodes()
  local edges = db.get_edges()

  -- 1. 构建查找表 (Map)
  local node_map = {}
  for _, n in ipairs(nodes) do
    node_map[n.id] = n
  end

  -- 2. 构建反向边映射: Target ID -> List of Edges (指所有指向这个节点的边)
  local incoming_map = {}
  for _, edge in ipairs(edges) do
    if not incoming_map[edge.to] then
      incoming_map[edge.to] = {}
    end
    table.insert(incoming_map[edge.to], edge)
  end

  local processed_ids = {} -- 记录已经被放入树中的节点 ID (作为跟或子节点)

  -- 3. 递归构建树节点的辅助函数
  -- parent_id: 当前正在构建的父节点ID
  -- path: 用于检测循环引用的路径表
  local function build_tree_nodes(parent_id, path)
    local children_ui_nodes = {}
    local incoming = incoming_map[parent_id] or {}

    for _, edge in ipairs(incoming) do
      local src_node_id = edge.from
      local src_node = node_map[src_node_id]

      -- 只有当源节点存在，且不在当前递归路径中（防止死循环 A->B->A）
      if src_node and not path[src_node_id] then
        -- 记录新路径
        local new_path = vim.deepcopy(path)
        new_path[src_node_id] = true

        -- 标记为全局已处理，避免出现在孤立节点列表中
        processed_ids[src_node_id] = true

        -- 递归获取子节点的子节点 (Grandchildren)
        local grand_children = build_tree_nodes(src_node_id, new_path)

        -- 构建 NuiTree 节点
        local ui_node = NuiTree.Node({
          text = string.format(
            "  %s %s %s",
            config.icons[edge.relation] or "🔗",
            config.icons[src_node.type] or "🔹",
            sanitize_text(src_node.text)
          ),
          data = src_node,
        }, grand_children) -- 传入递归结果作为 children

        table.insert(children_ui_nodes, ui_node)
      end
    end

    return children_ui_nodes
  end

  local tree_nodes = {}

  -- 4. 策略：优先处理 Hypothesis 和 Question 作为根节点
  for _, node in ipairs(nodes) do
    if node.type == "hypothesis" or node.type == "question" then
      processed_ids[node.id] = true

      -- 开始递归构建子树
      local children = build_tree_nodes(node.id, { [node.id] = true })

      table.insert(
        tree_nodes,
        NuiTree.Node({
          text = string.format("%s %s", config.icons[node.type] or "🔹", sanitize_text(node.text)),
          data = node,
        }, children)
      )
    end
  end

  -- 5. 处理孤立节点（既不是跟节点，也没有被作为子节点引用过）
  for _, node in ipairs(nodes) do
    if not processed_ids[node.id] then
      -- 这里可以尝试检查该节点是否有子节点，如果有，也构建一棵树
      -- 即使它不是 Hypothesis/Question (例如孤立的 Insight -> Fact 链)
      local children = build_tree_nodes(node.id, { [node.id] = true })

      table.insert(
        tree_nodes,
        NuiTree.Node({
          text = string.format("%s %s", config.icons[node.type] or "🔹", sanitize_text(node.text)),
          data = node,
        }, children)
      )
    end
  end

  dashboard_win.tree = NuiTree({ nodes = tree_nodes, bufnr = dashboard_win.bufnr })
  dashboard_win.tree:render()
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
      if dashboard_win then
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
      show_input_buffer("Modify Node", node_to_modify.text, function(value)
        if value and #value > 0 then
          node_to_modify.text = value
          db.update_node(node_to_modify)
          print("Node modified: " .. value)
          if dashboard_win then
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
