local Path = require("plenary.path")
local db = require("custom_plugins.auditscope.mind.db")

local M = {}

local function format_time(ts)
  if not ts then
    return "unknown"
  end
  return os.date("%Y-%m-%d %H:%M", ts)
end

local function sanitize_text(text)
  if not text then
    return ""
  end
  local clean = tostring(text):gsub("[\r\n]+", " ")
  return clean
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

local function relative_path(file, root)
  if not file or not root then
    return file
  end
  local normalized_root = vim.fs.normalize(root)
  local normalized_file = vim.fs.normalize(file)
  local prefix = normalized_root .. "/"
  if vim.startswith(normalized_file, prefix) then
    return normalized_file:sub(#prefix + 1)
  end
  return normalized_file
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

local function group_nodes(nodes)
  local groups = {}
  for _, node in ipairs(nodes) do
    local t = node.type or "note"
    groups[t] = groups[t] or {}
    table.insert(groups[t], node)
  end
  return groups
end

local function format_reference(node)
  if not node.file or not node.start_line then
    return nil
  end
  local rel = relative_path(node.file, node.repo_root)
  local range = format_line_range(node.start_line, node.end_line)
  local commit = node.commit and ("@" .. node.commit) or ""
  return string.format("`%s:%s%s`", rel or "unknown", range, commit)
end

local function format_repo_label(node)
  local repo = node.repo_name or (node.repo_root and vim.fn.fnamemodify(node.repo_root, ":t")) or nil
  if repo then
    return repo
  end
  return nil
end

function M.generate(opts)
  opts = opts or {}

  local subject = db.get_subject()
  if not subject then
    vim.notify("AuditScope: No active subject. Use :AuditSubjectNew or :AuditSubjectSelect.", vim.log.levels.ERROR)
    return nil
  end

  local nodes = db.get_nodes()
  local storage = db.get_storage_paths()
  local reports_root = storage and storage.reports_dir
  if not reports_root or reports_root == "" then
    reports_root = vim.fs.joinpath(vim.fn.stdpath("data"), "auditscope", "reports")
  end

  local report_dir = Path:new(reports_root)
  if not report_dir:exists() then
    report_dir:mkdir({ parents = true })
  end

  local report_name = safe_filename(subject.id) or safe_filename(subject.title) or ("subject_" .. os.time())
  local report_path = Path:new(vim.fs.joinpath(report_dir:absolute(), report_name .. ".md"))
  if report_path:exists() and report_path:is_dir() then
    report_name = report_name .. "_" .. os.time()
    report_path = Path:new(vim.fs.joinpath(report_dir:absolute(), report_name .. ".md"))
  end

  local lines = {}
  table.insert(lines, "# " .. (subject.title or "Untitled Subject"))
  table.insert(lines, "")
  table.insert(lines, string.format("- Status: %s", subject.status or "active"))
  if subject.scope and subject.scope ~= "" then
    table.insert(lines, string.format("- Scope: %s", subject.scope))
  end
  table.insert(lines, string.format("- Created: %s", format_time(subject.created_at)))
  table.insert(lines, string.format("- Updated: %s", format_time(subject.updated_at)))
  table.insert(lines, "")

  table.insert(lines, "## Executive Summary")
  table.insert(lines, "")
  if subject.summary and subject.summary ~= "" then
    table.insert(lines, sanitize_text(subject.summary))
  else
    table.insert(lines, "_No summary yet._")
  end
  table.insert(lines, "")

  local groups = group_nodes(nodes)

  local function add_group_list(title, types, prefix)
    local items = {}
    for _, t in ipairs(types) do
      if groups[t] then
        for _, n in ipairs(groups[t]) do
          table.insert(items, n)
        end
      end
    end
    if #items == 0 then
      return
    end
    table.insert(lines, "## " .. title)
    table.insert(lines, "")
    local idx = 0
    for _, n in ipairs(items) do
      idx = idx + 1
      local text = sanitize_text(n.text or "")
      if text == "" then
        text = "(empty)"
      end
      local label = prefix and string.format("%s%d", prefix, idx) or tostring(idx)
      table.insert(lines, string.format("- [%s] %s", label, text))
      local fields = {}
      local repo_label = format_repo_label(n)
      if repo_label then
        table.insert(fields, "Repo: " .. repo_label)
      end
      local ref = format_reference(n)
      if ref then
        table.insert(fields, "Location: " .. ref)
      end
      if #fields > 0 then
        table.insert(lines, "  " .. table.concat(fields, " | "))
      end
    end
    table.insert(lines, "")
  end

  local function add_group_heading(title, types, prefix)
    local items = {}
    for _, t in ipairs(types) do
      if groups[t] then
        for _, n in ipairs(groups[t]) do
          table.insert(items, n)
        end
      end
    end
    if #items == 0 then
      return
    end
    table.insert(lines, "## " .. title)
    table.insert(lines, "")
    local idx = 0
    for _, n in ipairs(items) do
      idx = idx + 1
      local text = sanitize_text(n.text or "")
      if text == "" then
        text = "(empty)"
      end
      local label = prefix and string.format("%s%d", prefix, idx) or tostring(idx)
      table.insert(lines, string.format("### [%s] %s", label, text))
      local fields = {}
      local repo_label = format_repo_label(n)
      if repo_label then
        table.insert(fields, "Repo: " .. repo_label)
      end
      local ref = format_reference(n)
      if ref then
        table.insert(fields, "Location: " .. ref)
      end
      if #fields > 0 then
        table.insert(lines, table.concat(fields, " | "))
      end
      table.insert(lines, "")
    end
  end

  add_group_list("Evidence", { "evidence", "fact" }, "E")
  add_group_list("Notes", { "note" }, "N")
  add_group_list("Insights", { "insight" }, "I")
  add_group_list("Assumptions", { "assumption" }, "A")
  add_group_list("Invariants", { "invariant" }, "V")
  add_group_list("Open Questions", { "question" }, "Q")
  add_group_list("Hypotheses", { "hypothesis" }, "H")
  add_group_heading("Findings", { "finding" }, "F")
  add_group_heading("Decisions", { "decision" }, "D")
  add_group_heading("Risks", { "risk" }, "R")

  report_path:write(table.concat(lines, "\n"), "w")

  if opts.open then
    vim.cmd("edit " .. report_path:absolute())
  end

  vim.notify(string.format("AuditScope: Report generated at %s", report_path:absolute()), vim.log.levels.INFO)
  return report_path:absolute()
end

return M
