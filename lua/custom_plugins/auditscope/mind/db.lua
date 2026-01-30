local Path = require("plenary.path")
local M = {}

M.data = { subject = nil, nodes = {}, edges = {}, glance = {} }
M.file_path = nil
M.subject_index = { subjects = {} }
M.active_subject_id = nil
M.locked_commits = {}

local STORAGE_ROOT = vim.fs.joinpath(vim.fn.stdpath("data"), "auditscope")
local SUBJECTS_DIR = vim.fs.joinpath(STORAGE_ROOT, "subjects")
local REPORTS_DIR = vim.fs.joinpath(STORAGE_ROOT, "reports")
local STATE_FILE = vim.fs.joinpath(STORAGE_ROOT, "state.json")
local INDEX_FILE = vim.fs.joinpath(STORAGE_ROOT, "subjects.json")

local STORAGE_ROOT_PATH = Path:new(STORAGE_ROOT)
local SUBJECTS_DIR_PATH = Path:new(SUBJECTS_DIR)
local REPORTS_DIR_PATH = Path:new(REPORTS_DIR)
local STATE_FILE_PATH = Path:new(STATE_FILE)
local INDEX_FILE_PATH = Path:new(INDEX_FILE)

local function ensure_dirs()
  if not STORAGE_ROOT_PATH:exists() then
    STORAGE_ROOT_PATH:mkdir({ parents = true })
  end
  if not SUBJECTS_DIR_PATH:exists() then
    SUBJECTS_DIR_PATH:mkdir({ parents = true })
  end
  if not REPORTS_DIR_PATH:exists() then
    REPORTS_DIR_PATH:mkdir({ parents = true })
  end
end

local function load_json(path, fallback)
  if path:exists() then
    local content = path:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok and type(decoded) == "table" then
      return decoded
    end
  end
  return fallback
end

local function save_json(path, data)
  path:write(vim.json.encode(data), "w")
end

function M.init()
  ensure_dirs()
  M.load_index()
  M.load_state()
end

function M.get_storage_paths()
  ensure_dirs()
  return {
    root = STORAGE_ROOT,
    subjects_dir = SUBJECTS_DIR,
    reports_dir = REPORTS_DIR,
    state_file = STATE_FILE,
    index_file = INDEX_FILE,
  }
end

function M.load_index()
  ensure_dirs()
  M.subject_index = load_json(INDEX_FILE_PATH, { subjects = {} })
  if not M.subject_index.subjects then
    M.subject_index.subjects = {}
  end
  return M.subject_index
end

function M.save_index()
  ensure_dirs()
  save_json(INDEX_FILE_PATH, M.subject_index or { subjects = {} })
end

function M.load_state()
  ensure_dirs()
  local state = load_json(STATE_FILE_PATH, {})
  M.active_subject_id = state.active_subject_id
  return state
end

function M.save_state()
  ensure_dirs()
  save_json(STATE_FILE_PATH, { active_subject_id = M.active_subject_id })
end

function M.get_subjects()
  M.load_index()
  return M.subject_index.subjects
end

local function subject_path(subject_id)
  ensure_dirs()
  local filename = string.format("%s.json", subject_id)
  return Path:new(vim.fs.joinpath(SUBJECTS_DIR, filename))
end

local function resolve_subject_file(subject_id)
  local file = subject_path(subject_id)
  if file:exists() then
    return file
  end
  local alt = Path:new(vim.fs.joinpath(SUBJECTS_DIR, tostring(subject_id)))
  if alt:exists() then
    return alt
  end
  return file
end

local function is_path_within(path, root)
  local normalized_root = vim.fs.normalize(root)
  local normalized_path = vim.fs.normalize(path)
  local prefix = normalized_root .. "/"
  return normalized_path == normalized_root or vim.startswith(normalized_path, prefix)
end

local function safe_filename(value)
  if value == nil then
    return nil
  end
  local name = tostring(value)
  if name == "" then
    return nil
  end
  name = name:gsub("[/\\]", "_")
  name = name:gsub("%s+", "_")
  name = name:gsub("[^%w%._-]", "_")
  name = name:gsub("_+", "_")
  name = name:gsub("^[_%.]+", "")
  name = name:gsub("[_%.]+$", "")
  if name == "" then
    return nil
  end
  return name
end

local function report_path_for_subject(meta)
  if not meta then
    return nil
  end
  local report_name = safe_filename(meta.id) or safe_filename(meta.title)
  if not report_name then
    return nil
  end
  return vim.fs.joinpath(REPORTS_DIR, report_name .. ".md")
end

local function new_subject_meta(title, opts)
  local now = os.time()
  return {
    id = opts.id,
    title = title,
    status = opts.status or "active",
    scope = opts.scope or "",
    created_at = opts.created_at or now,
    updated_at = opts.updated_at or now,
  }
end

function M.get_subject()
  return M.data.subject
end

function M.compute_subject_stats(meta)
  if not meta or not meta.id then
    return nil
  end

  local file = resolve_subject_file(meta.id)
  local file_path = file:absolute()
  if not is_path_within(file_path, SUBJECTS_DIR) then
    return nil
  end

  if not file:exists() then
    return {
      nodes = 0,
      edges = 0,
      summary = false,
      report = false,
    }
  end

  local content = file:read()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return {
      nodes = 0,
      edges = 0,
      summary = false,
      report = false,
    }
  end

  local subject = decoded.subject or {}
  local nodes = decoded.nodes or {}
  local edges = decoded.edges or {}
  local summary = subject.summary
  local report_path = report_path_for_subject(subject)
  local report_exists = false
  if report_path then
    local report_file = Path:new(report_path)
    report_exists = report_file:exists() and not report_file:is_dir()
  end

  local stats = {
    nodes = #nodes,
    edges = #edges,
    summary = summary ~= nil and summary ~= "",
    report = report_exists,
  }

  local updates = {}
  if subject.title and subject.title ~= meta.title then
    updates.title = subject.title
  end
  if subject.status and subject.status ~= meta.status then
    updates.status = subject.status
  end
  if subject.updated_at and subject.updated_at ~= meta.updated_at then
    updates.updated_at = subject.updated_at
  end
  if subject.scope and subject.scope ~= meta.scope then
    updates.scope = subject.scope
  end

  return stats, updates
end

function M.hydrate_subjects_with_stats()
  local subjects = M.get_subjects()
  if #subjects == 0 then
    return subjects
  end

  local changed = false
  for _, item in ipairs(subjects) do
    local stats, updates = M.compute_subject_stats(item)
    if stats then
      if not vim.deep_equal(item.stats, stats) then
        item.stats = stats
        changed = true
      end
    end
    if updates and next(updates) then
      for key, value in pairs(updates) do
        item[key] = value
      end
      changed = true
    end
  end

  if changed then
    M.save_index()
  end

  return subjects
end

function M.delete_subject_confirmed(subject_id)
  local subjects = M.get_subjects()
  if #subjects == 0 then
    return false
  end

  local file = resolve_subject_file(subject_id)
  local file_path = file:absolute()
  if not is_path_within(file_path, SUBJECTS_DIR) then
    vim.notify("AuditScope: Refusing to delete outside subjects directory.", vim.log.levels.ERROR)
    return false
  end

  if file:exists() then
    file:rm()
  end

  local remaining = {}
  for _, item in ipairs(subjects) do
    if item.id ~= subject_id then
      table.insert(remaining, item)
    end
  end
  M.subject_index.subjects = remaining
  M.save_index()

  if M.active_subject_id == subject_id then
    M.active_subject_id = nil
    M.file_path = nil
    M.data = { subject = nil, nodes = {}, edges = {}, glance = {} }
    M.save_state()
  end

  return true
end

function M.delete_subject(subject_id)
  local subjects = M.get_subjects()
  if #subjects == 0 then
    vim.notify("AuditScope: No subjects found.", vim.log.levels.INFO)
    return
  end

  if not subject_id or subject_id == "" then
    vim.ui.select(subjects, {
      prompt = "Delete Audit Subject:",
      format_item = function(item)
        local updated = item.updated_at and os.date("%Y-%m-%d", item.updated_at) or "unknown"
        return string.format("%s [%s] (%s)", item.title or "Untitled", item.status or "active", updated)
      end,
    }, function(choice)
      if choice and choice.id then
        M.delete_subject(choice.id)
      end
    end)
    return
  end

  local target = nil
  for _, item in ipairs(subjects) do
    if item.id == subject_id then
      target = item
      break
    end
  end

  local title = target and target.title or subject_id
  vim.ui.input({
    prompt = string.format("Type DELETE to remove subject '%s': ", title),
  }, function(confirm)
    if confirm ~= "DELETE" then
      return
    end
    if M.delete_subject_confirmed(subject_id) then
      vim.notify("AuditScope: Subject deleted.", vim.log.levels.INFO)
    end
  end)
end

function M.set_active_subject(subject_id)
  if not subject_id then
    return nil
  end
  local file = subject_path(subject_id)
  if not file:exists() then
    return nil
  end
  M.file_path = file
  M.active_subject_id = subject_id
  M.save_state()
  M.load()
  if not M.data.subject then
    M.data.subject = new_subject_meta("Untitled Subject", { id = subject_id })
    M.touch_subject()
    save_json(M.file_path, M.data)
  elseif not M.data.subject.id then
    M.data.subject.id = subject_id
    M.save()
  end
  return M.data.subject
end

function M.create_subject(title, opts)
  opts = opts or {}
  M.load_index()

  local id = opts.id or (tostring(os.time()) .. tostring(math.random(100, 999)))
  local meta = new_subject_meta(title or "Untitled Subject", { id = id, status = opts.status, scope = opts.scope })

  local file = subject_path(id)
  M.file_path = file
  M.data = { subject = meta, nodes = {}, edges = {}, glance = {} }
  save_json(file, M.data)

  table.insert(M.subject_index.subjects, meta)
  M.save_index()

  M.active_subject_id = id
  M.save_state()

  return meta
end

function M.update_subject_meta(meta)
  if not meta or not meta.id then
    return
  end
  M.load_index()
  for i, item in ipairs(M.subject_index.subjects) do
    if item.id == meta.id then
      M.subject_index.subjects[i] = meta
      M.save_index()
      return
    end
  end
  table.insert(M.subject_index.subjects, meta)
  M.save_index()
end

function M.touch_subject()
  if not M.data.subject then
    return
  end
  M.data.subject.updated_at = os.time()
  M.update_subject_meta(M.data.subject)
end

function M.select_subject()
  local subjects = M.get_subjects()
  if #subjects == 0 then
    vim.notify("AuditScope: No subjects found. Use :AuditSubjectNew first.", vim.log.levels.INFO)
    return
  end

  table.sort(subjects, function(a, b)
    return (a.updated_at or 0) > (b.updated_at or 0)
  end)

  vim.ui.select(subjects, {
    prompt = "Select Audit Subject:",
    format_item = function(item)
      local updated = item.updated_at and os.date("%Y-%m-%d", item.updated_at) or "unknown"
      return string.format("%s [%s] (%s)", item.title or "Untitled", item.status or "active", updated)
    end,
  }, function(choice)
    if choice then
      M.set_active_subject(choice.id)
      vim.notify(string.format("AuditScope: Active subject set to %s", choice.title or choice.id), vim.log.levels.INFO)
    end
  end)
end

M.try_select_mind = M.select_subject

function M.get_repo_context()
  local git_root = vim.fs.root(0, ".git")
  if not git_root then
    return { root = nil, name = nil, commit = nil, remote = nil }
  end

  local project_name = vim.fn.fnamemodify(git_root, ":t")

  local commit_hash = vim.fn.systemlist("git rev-parse --short HEAD")[1]
  if vim.v.shell_error ~= 0 or not commit_hash then
    commit_hash = nil
  end

  local remote = vim.fn.systemlist("git remote get-url origin")[1]
  if vim.v.shell_error ~= 0 or not remote then
    remote = nil
  end

  return {
    root = git_root,
    name = project_name,
    commit = commit_hash,
    remote = remote,
  }
end

function M.set_commit(commit_hash)
  local ctx = M.get_repo_context()
  local root = ctx.root or "nogit"

  if commit_hash == nil or commit_hash == "" then
    vim.notify("AuditScope: No commit hash provided, locking to current commit.", vim.log.levels.INFO)
    commit_hash = ctx.commit
  end

  if not commit_hash then
    vim.notify("AuditScope: No commit available to lock.", vim.log.levels.WARN)
    return nil
  end

  M.locked_commits[root] = commit_hash
  vim.notify(string.format("AuditScope: Commit locked to %s", commit_hash), vim.log.levels.INFO)

  return commit_hash
end

function M.unlock_commit()
  local ctx = M.get_repo_context()
  local root = ctx.root or "nogit"
  M.locked_commits[root] = nil
  vim.notify("AuditScope: Commit lock released", vim.log.levels.INFO)
end

function M.get_effective_commit()
  local ctx = M.get_repo_context()
  local root = ctx.root or "nogit"
  return M.locked_commits[root] or ctx.commit
end

function M.TryLoadMind()
  M.load_state()
  if M.active_subject_id then
    return M.set_active_subject(M.active_subject_id)
  end
  return nil
end

function M.CreateMind(opts)
  opts = opts or {}
  local ctx = M.get_repo_context()
  local title = opts.title or opts.project_name or ctx.name or ("Subject " .. os.date("%Y-%m-%d %H:%M"))
  local meta = M.create_subject(title, { status = opts.status, scope = opts.scope })
  vim.notify(string.format("AuditScope: Subject created: %s", meta.title), vim.log.levels.INFO)
  return meta
end

function M.load()
  if M.file_path and M.file_path:exists() then
    local content = M.file_path:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok and type(decoded) == "table" then
      M.data = decoded
    else
      M.data = { subject = nil, nodes = {}, edges = {}, glance = {} }
    end
  else
    M.data = { subject = nil, nodes = {}, edges = {}, glance = {} }
  end

  M.data.nodes = M.data.nodes or {}
  M.data.edges = M.data.edges or {}
  M.data.glance = M.data.glance or {}

  return M.data
end

local function ensure_initialized()
  if not M.file_path or not M.data.subject then
    vim.notify("AuditScope: No active subject. Run :AuditSubjectNew or :AuditSubjectSelect.", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.set_summary(summary)
  if not ensure_initialized() then
    return nil
  end
  M.data.subject.summary = summary or ""
  M.save()
  return M.data.subject.summary
end

function M.save()
  if not ensure_initialized() then
    return
  end

  M.touch_subject()
  save_json(M.file_path, M.data)

  local has_signs, signs = pcall(require, "custom_plugins.auditscope.mind.sign")
  if has_signs and signs.refresh then
    signs.refresh()
  end

  local has_ui, ui = pcall(require, "custom_plugins.auditscope.mind.ui")
  if has_ui and ui.refresh_dashboard then
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

function M.clean_glance(file)
  if not ensure_initialized() then
    return
  end
  if M.data.glance and M.data.glance[file] then
    M.data.glance[file] = {}
    M.save()
  end
end

return M
