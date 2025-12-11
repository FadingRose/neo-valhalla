local Path = require("plenary.path")
local M = {}

-- 初始状态为空
M.data = { nodes = {}, edges = {}, glance = {} }
M.file_path = nil
M.project_info = {
  root = nil,
  name = nil,
  commit = nil,
}

M.locked_commit = nil

local function get_git_context()
  local git_root = vim.fs.root(0, ".git")

  if not git_root then
    vim.notify("AuditScope: Not a git repository. Using logical root.", vim.log.levels.WARN)
    return vim.fn.getcwd(), "default_project", "no_commit"
  end

  local project_name = vim.fn.fnamemodify(git_root, ":t")

  -- 获取 Short Commit Hash
  local commit_hash = vim.fn.systemlist("git rev-parse --short HEAD")[1]
  if vim.v.shell_error ~= 0 or not commit_hash then
    commit_hash = "unknown"
  end

  return git_root, project_name, commit_hash
end

--- 锁定当前 commit hash
--- 一旦锁定，后续操作将使用锁定的 commit 而非动态获取
--- @param commit_hash string|nil 要锁定的 commit hash，nil 表示使用当前 commit
--- @return string|nil 锁定的 commit hash，失败返回 nil
function M.set_commit(commit_hash)
  if commit_hash == nil then
    vim.notify("AuditMind: No commit hash provided, locking to current commit.", vim.log.levels.INFO)
  end

  local _, _, current_commit_short = get_git_context() -- 获取当前 short hash
  if commit_hash:len() > current_commit_short:len() then
    commit_hash = commit_hash:sub(1, current_commit_short:len())
  end

  M.locked_commit = commit_hash

  vim.notify(string.format("AuditMind: Commit locked to %s", M.locked_commit), vim.log.levels.INFO)

  return M.locked_commit
end

--- 解除 commit 锁定
function M.unlock_commit()
  M.locked_commit = nil
  vim.notify("AuditMind: Commit lock released", vim.log.levels.INFO)
end

--- 获取当前使用的 commit（优先使用锁定值）
--- @return string commit hash
function M.get_effective_commit()
  if M.locked_commit then
    return M.locked_commit
  end
  local _, _, commit = get_git_context()
  return commit
end

function M.try_select_mind()
  local git_root, _, current_commit = get_git_context()

  local storage_dir = Path:new(git_root)
  if not storage_dir then
    return nil -- Silent failure
  end
  storage_dir = Path.joinpath(storage_dir, ".auiditscope.mind")

  --- 尝试列出所有可用的思维图谱文件
  if not storage_dir:exists() then
    vim.notify("AuditScope: No mind map history found.", vim.log.levels.WARN)
    return
  end

  local files = vim.fn.glob(storage_dir:absolute() .. "/*.json", 0, 1)
  local options = {}

  for _, file in ipairs(files) do
    local filename = vim.fn.fnamemodify(file, ":t")
    -- 解析格式: <ProjectName>_<CommitHash>.json
    -- 使用 greedy match 匹配最后一个 _ 之前的内容作为 ProjectName
    local p_name, c_hash = filename:match("^(.*)_(.*)%.json$")
    if p_name and c_hash then
      table.insert(options, {
        project = p_name,
        commit = c_hash,
        file = file,
      })
    end
  end

  if #options == 0 then
    vim.notify("AuditScope: No mind map files available.", vim.log.levels.INFO)
    return
  end

  vim.ui.select(options, {
    prompt = "Select Audit Mind Map:",
    format_item = function(item)
      local marker = (item.commit == current_commit) and " (Current)" or ""
      return string.format("%s - %s%s", item.commit, item.project, marker)
    end,
  }, function(choice)
    if choice then
      -- 锁定并加载选中的 commit
      M.set_commit(choice.commit)
      if M.TryLoadMind() then
        vim.notify(string.format("Loaded mind map for commit: %s", choice.commit), vim.log.levels.INFO)

        -- 刷新 UI 组件 (安全调用)
        local ok_signs, signs = pcall(require, "auditscope.mind.signs")
        if ok_signs then
          signs.refresh()
        end

        local ok_ui, ui = pcall(require, "auditscope.mind.ui")
        if ok_ui then
          ui.refresh_dashboard()
        end
      else
        vim.notify("Failed to load selected mind map.", vim.log.levels.ERROR)
      end
    end
  end)
end

--- 尝试载入审计思维图谱数据库
--- 如果成功则载入并设置M.data, M.file_path, M.project_info
--- 如果失败则静默返回 nil
function M.TryLoadMind()
  local git_root, project_name, commit_hash = get_git_context()

  -- 如果有锁定的 commit，使用锁定值
  if M.locked_commit then
    commit_hash = M.locked_commit
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
    return nil -- Silent failure
  end
  storage_dir = Path.joinpath(storage_dir, ".auiditscope.mind")

  -- 构建文件名: <ProjectName>_<CommitHash>.json
  local filename = string.format("%s_%s.json", project_name, commit_hash)
  M.file_path = Path.joinpath(storage_dir, filename)

  if not M.file_path then
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

  -- 如果有锁定的 commit，使用锁定值
  if M.locked_commit then
    commit_hash = M.locked_commit
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
      M.data = { nodes = {}, edges = {}, glance = {} }
    end
  else
    M.data = { nodes = {}, edges = {}, glance = {} }
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

function M.update_glance(file, line, count, skip_save)
  if not ensure_initialized() then
    return
  end
  if not M.data.glance then
    M.data.glance = {}
  end
  if not M.data.glance[file] then
    M.data.glance[file] = {}
  end

  -- Save line as string key for consistent JSON object behavior
  local line_key = tostring(line)

  if count > 0 then
    M.data.glance[file][line_key] = count
  else
    M.data.glance[file][line_key] = nil
  end

  if not skip_save then
    M.save()
  end
end

function M.get_glance(file)
  if not M.data.glance then
    return {}
  end
  return M.data.glance[file] or {}
end

return M
