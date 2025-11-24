-- lua/auditscope/mind/ui.lua
local Input = require("nui.input")
local Popup = require("nui.popup")
local NuiTree = require("nui.tree")
local event = require("nui.utils.autocmd").event
local db = require("custom_plugins.auditscope.mind.db")

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
  }, user_config or {})
end

-- 辅助：获取当前上下文
local function get_context()
  return {
    file = vim.fn.expand("%:p"),
    line = vim.api.nvim_win_get_cursor(0)[1],
    text = vim.trim(vim.api.nvim_get_current_line()),
  }
end

-- 1. 创建新节点
function M.create_node(type)
  local ctx = get_context()

  local input = Input({
    position = "50%",
    size = { width = 60 },
    border = { style = "rounded", text = { top = " New " .. type .. " " } },
  }, {
    on_submit = function(value)
      if value and #value > 0 then
        local node = {
          id = tostring(os.time()) .. math.random(100, 999),
          type = type,
          text = value,
          file = ctx.file,
          line = ctx.line,
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
    end,
  })
  input:mount()
end

-- 2. 连接节点 (Link)
function M.link_node(source_node)
  local nodes = db.get_nodes()
  if #nodes <= 1 then
    return
  end -- 没有其他节点可连

  local items = {}
  local node_map = {}

  for _, n in ipairs(nodes) do
    if n.id ~= source_node.id then
      local label =
        string.format("%s %s (%s:%d)", config.icons[n.type], n.text, vim.fn.fnamemodify(n.file, ":t"), n.line)
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
        -- 注意方向：如果是 Fact 支持 Hypothesis，From=Fact, To=Hypothesis
        -- 为了简化，我们总是让 source 指向 target，用户自己决定逻辑
        db.add_edge(source_node.id, target.id, rel)
        print(string.format("Linked: %s --[%s]--> %s", source_node.text, rel, target.text))
        if dashboard_win then
          M.refresh_dashboard()
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
    position = "right",
    size = { width = "40%", height = "80%" },
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
      vim.api.nvim_win_set_cursor(0, { node.data.line, 0 })
    end
  end)

  M.refresh_dashboard()
end

function M.refresh_dashboard()
  if not dashboard_win then
    return
  end

  local nodes = db.get_nodes()
  local edges = db.get_edges()
  local tree_nodes = {}

  -- 策略：将 Hypothesis 和 Question 作为顶级节点
  -- 将 Supports/Refutes 的节点作为子节点

  local processed_ids = {}

  for _, node in ipairs(nodes) do
    if node.type == "hypothesis" or node.type == "question" then
      local children = {}
      local incoming = db.get_incoming_edges(node.id)

      for _, edge in ipairs(incoming) do
        -- 找到源节点
        local src_node = nil
        for _, n in ipairs(nodes) do
          if n.id == edge.from then
            src_node = n
            break
          end
        end

        if src_node then
          table.insert(
            children,
            NuiTree.Node({
              text = string.format(
                "  %s %s %s",
                config.icons[edge.relation],
                config.icons[src_node.type],
                src_node.text
              ),
              data = src_node,
            })
          )
        end
      end

      table.insert(
        tree_nodes,
        NuiTree.Node({
          text = string.format("%s %s", config.icons[node.type], node.text),
          data = node,
        }, children)
      )

      processed_ids[node.id] = true
    end
  end

  -- 把剩下的孤立节点也放进去
  for _, node in ipairs(nodes) do
    if not processed_ids[node.id] then
      table.insert(
        tree_nodes,
        NuiTree.Node({
          text = string.format("%s %s", config.icons[node.type], node.text),
          data = node,
        })
      )
    end
  end

  dashboard_win.tree = NuiTree({ nodes = tree_nodes, bufid = dashboard_win.bufnr })
  dashboard_win.tree:render()
end

return M
