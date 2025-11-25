local Path = require("plenary.path")
local M = {}

-- 初始状态为空
M.data = { nodes = {}, edges = {} }
M.file_path = nil
M.project_info = {
  root = nil,
  name = nil,
  commit = nil,
}

-- 辅助：获取 Git 信息
local function get_git_context()
  -- 向上查找 .git 目录
  local dot_git_path = vim.fs.find(".git", {
    path = vim.fn.getcwd(),
    upward = true,
    type = "directory",
  })[1]

  if not dot_git_path then
    vim.notify("AuditScope: Not a git repository. Using logical root.", vim.log.levels.WARN)
    return vim.fn.getcwd(), "default_project", "no_commit"
  end

  local git_root = vim.fn.fnamemodify(dot_git_path, ":h")
  local project_name = vim.fn.fnamemodify(git_root, ":t")

  -- 获取 Short Commit Hash
  local cmd = string.format("git -C %s rev-parse --short HEAD", git_root)
  local handle = io.popen(cmd)
  local commit_hash = handle:read("*a")
  handle:close()

  if commit_hash then
    commit_hash = commit_hash:gsub("%s+", "")
  else
    commit_hash = "unknown"
  end

  return git_root, project_name, commit_hash
end

--- 尝试载入审计思维图谱数据库
--- 如果成功则载入并设置M.data, M.file_path, M.project_info
--- 如果失败则静默返回 nil
function M.TryLoadMind()
  local git_root, project_name, commit_hash = get_git_context()

  -- 更新内部状态信息
  M.project_info = {
    root = git_root,
    name = project_name,
    commit = commit_hash,
  }

  -- 构建存储目录: <GitRoot>/.auditscope.mind/
  local storage_dir = Path:new(git_root)
  if not storage_dir then
    return nil -- Silent failure
  end
  storage_dir = Path.joinpath(storage_dir, ".auiditscope.mind")

  -- 构建文件名: <ProjectName>_<CommitHash>.json
  local filename = string.format("%s_%s.json", project_name, commit_hash)
  M.file_path = Path.joinpath(storage_dir, filename)

  -- 检查文件是否存在，不存在则静默失败
  if not M.file_path:exists() then
    M.file_path = nil -- Reset file_path if it doesn't exist
    M.project_info = { -- Also reset project_info if file not found
      root = nil,
      name = nil,
      commit = nil,
    }
    return nil
  end

  -- 尝试加载现有数据
  M.load()

  -- 如果加载M.data后仍然是初始空状态，可能文件内容无效，静默失败
  -- 否则，返回项目信息
  if next(M.data.nodes) == nil and next(M.data.edges) == nil then
    M.project_info = { -- Reset project_info if loaded data is empty
      root = nil,
      name = nil,
      commit = nil,
    }
    return nil
  end

  return M.project_info
end

--- 初始化审计思维图谱数据库
--- @param opts table|nil 可选配置，例如 { force_name = "custom_session" }
function M.CreateMind(opts)
  opts = opts or {}

  local git_root, project_name, commit_hash = get_git_context()

  -- 允许用户覆盖项目名（可选）
  if opts.project_name then
    project_name = opts.project_name
  end

  -- 更新内部状态信息
  M.project_info = {
    root = git_root,
    name = project_name,
    commit = commit_hash,
  }

  -- 构建存储目录: <GitRoot>/.auditscope.mind/
  local storage_dir = Path:new(git_root)
  if not storage_dir then
    vim.notify("AuditScope: Failed to create Path object for storage directory.", vim.log.levels.ERROR)
    return nil -- Or handle error appropriately
  end
  storage_dir = Path.joinpath(storage_dir, ".auiditscope.mind")

  -- 确保目录存在
  if not storage_dir:exists() then
    storage_dir:mkdir({ parents = true })
  end

  -- 构建文件名: <ProjectName>_<CommitHash>.json
  local filename = string.format("%s_%s.json", project_name, commit_hash)
  M.file_path = Path.joinpath(storage_dir, filename)

  -- 尝试加载现有数据，如果文件不存在则初始化为空
  M.load()

  vim.notify(
    string.format("AuditMind Session Started:\nProject: %s\nCommit: %s", project_name, commit_hash),
    vim.log.levels.INFO
  )

  return M.project_info
end

function M.load()
  if M.file_path and M.file_path:exists() then
    local content = M.file_path:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok then
      M.data = decoded
    else
      M.data = { nodes = {}, edges = {} }
    end
  else
    M.data = { nodes = {}, edges = {} }
  end
end

-- 检查 DB 是否已初始化
local function ensure_initialized()
  if not M.file_path then
    vim.notify("AuditMind DB not initialized. Please run :AuditCreateMind first.", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.save()
  if not ensure_initialized() then
    return
  end

  M.file_path:write(vim.json.encode(M.data), "w")

  -- 通知 UI 刷新 (使用安全调用以防循环依赖)
  local has_signs, signs = pcall(require, "auditscope.mind.signs")
  if has_signs then
    signs.refresh()
  end

  local has_ui, ui = pcall(require, "auditscope.mind.ui")
  if has_ui then
    ui.refresh_dashboard()
  end
end

-- === 数据操作 API ===

function M.add_node(node)
  if not ensure_initialized() then
    return nil
  end
  table.insert(M.data.nodes, node)
  M.save()
  return node
end

function M.add_edge(from_id, to_id, relation)
  if not ensure_initialized() then
    return nil
  end
  table.insert(M.data.edges, { from = from_id, to = to_id, relation = relation })
  M.save()
  return { from = from_id, to = to_id, relation = relation }
end

function M.delete_edge(from_id, to_id)
  if not ensure_initialized() then
    return false
  end

  local new_edges = {}
  local changed = false

  for _, edge in ipairs(M.data.edges) do
    if edge.from == from_id and edge.to == to_id then
      changed = true
    else
      table.insert(new_edges, edge)
    end
  end

  if changed then
    M.data.edges = new_edges
    M.save()
  end
  return changed
end

function M.get_nodes()
  return M.data.nodes or {}
end

function M.get_edges()
  return M.data.edges or {}
end

function M.get_incoming_edges(node_id)
  local incoming = {}
  if M.data.edges then
    for _, edge in ipairs(M.data.edges) do
      if edge.to == node_id then
        table.insert(incoming, edge)
      end
    end
  end
  return incoming
end

function M.update_node(updated_node)
  if not ensure_initialized() then
    return nil
  end
  for i, node in ipairs(M.data.nodes) do
    if node.id == updated_node.id then
      M.data.nodes[i] = updated_node
      M.save()
      return updated_node
    end
  end
  return nil -- Node not found
end

function M.delete_node(node_id)
  if not ensure_initialized() then
    return false
  end

  local original_node_count = #M.data.nodes
  local original_edge_count = #M.data.edges

  -- Remove the node
  local new_nodes = {}
  for _, node in ipairs(M.data.nodes) do
    if node.id ~= node_id then
      table.insert(new_nodes, node)
    end
  end
  M.data.nodes = new_nodes

  -- Remove associated edges
  local new_edges = {}
  for _, edge in ipairs(M.data.edges) do
    if edge.from ~= node_id and edge.to ~= node_id then
      table.insert(new_edges, edge)
    end
  end
  M.data.edges = new_edges

  if #M.data.nodes < original_node_count or #M.data.edges < original_edge_count then
    M.save()
    return true
  end
  return false -- Node not found or no changes made
end

return M
