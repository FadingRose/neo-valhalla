local db = require("custom_plugins.auditscope.mind.db")
local ontology = require("custom_plugins.auditscope.mind.ontology")

local M = {}
local config = {
  llm = {
    provider = "openrouter",
    model = "google/gemini-3-flash-preview",
    max_candidates = 40,
    max_links = 3,
    min_confidence = 0.35,
    timeout_ms = 30000,
  },
}

local RELATIONS = {
  supports = true,
  refutes = true,
  relates = true,
}

local inflight = false

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
end

local function notify_err(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

local function normalize_relation(value)
  if not value then
    return "relates"
  end
  local rel = tostring(value):lower()
  if RELATIONS[rel] then
    return rel
  end
  return "relates"
end

local function sanitize(text, max_len)
  if not text then
    return ""
  end
  local clean = tostring(text):gsub("[\r\n]+", " ")
  if max_len and #clean > max_len then
    return clean:sub(1, max_len) .. "..."
  end
  return clean
end

local function format_level_map()
  local items = {}
  for k, v in pairs(ontology.levels or {}) do
    table.insert(items, string.format("%s=L%d", k, v))
  end
  table.sort(items)
  return table.concat(items, ", ")
end

local function pick_source_node()
  local nodes = db.get_nodes()
  if #nodes == 0 then
    return nil
  end

  local file = vim.fn.expand("%:p")
  local line = vim.api.nvim_win_get_cursor(0)[1]

  local best = nil
  local best_score = math.huge

  for _, n in ipairs(nodes) do
    if n.file == file and n.start_line then
      local start_line = n.start_line or 0
      local end_line = n.end_line or start_line
      local score = 0
      if line < start_line then
        score = start_line - line
      elseif line > end_line then
        score = line - end_line
      else
        score = 0
      end
      if score < best_score then
        best_score = score
        best = n
      end
    end
  end

  if best then
    return best
  end

  table.sort(nodes, function(a, b)
    return (a.timestamp or 0) > (b.timestamp or 0)
  end)

  return nodes[1]
end

local function build_prompt(source, candidates)
  local source_block = string.format(
    "SOURCE NODE:\n[id=%s] type=%s\ntext=%s\nfile=%s\nlines=%s\nsnippet=%s",
    source.id or "",
    source.type or "note",
    sanitize(source.text, 400),
    source.file or "",
    source.start_line and source.end_line and (source.start_line .. "-" .. source.end_line) or "",
    sanitize(source.code_snippet, 400)
  )

  local lines = { source_block, "", "CANDIDATES:" }
  for _, n in ipairs(candidates) do
    local line_range = ""
    if n.start_line then
      line_range = n.end_line and (n.start_line .. "-" .. n.end_line) or tostring(n.start_line)
    end
    table.insert(lines, string.format(
      "[id=%s] type=%s text=%s file=%s lines=%s snippet=%s",
      n.id or "",
      n.type or "note",
      sanitize(n.text, 200),
      n.file or "",
      line_range,
      sanitize(n.code_snippet, 200)
    ))
  end

  return table.concat(lines, "\n")
end

local function request_openrouter_async(payload, on_done)
  local api_key = os.getenv("OPENROUTER_API_KEY")
  if not api_key or api_key == "" then
    notify_err("AuditScope: OPENROUTER_API_KEY is not set.")
    return
  end

  if vim.fn.executable("curl") ~= 1 then
    notify_err("AuditScope: curl is required for OpenRouter requests.")
    return
  end

  local cmd = {
    "curl",
    "-sS",
    "https://openrouter.ai/api/v1/chat/completions",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-H",
    "Content-Type: application/json",
  }

  local referrer = os.getenv("OPENROUTER_REFERRER") or "http://localhost"
  local title = os.getenv("OPENROUTER_TITLE") or "AuditScope"
  table.insert(cmd, "-H")
  table.insert(cmd, "HTTP-Referer: " .. referrer)
  table.insert(cmd, "-H")
  table.insert(cmd, "X-Title: " .. title)

  if config.llm.timeout_ms then
    table.insert(cmd, "--max-time")
    table.insert(cmd, tostring(math.ceil(config.llm.timeout_ms / 1000)))
  end

  table.insert(cmd, "-d")
  table.insert(cmd, vim.json.encode(payload))

  vim.system(cmd, { text = true }, function(result)
    if not result or result.code ~= 0 then
      local err = result and result.stderr or "unknown error"
      notify_err("AuditScope: OpenRouter request failed: " .. err)
      if on_done then
        on_done(nil)
      end
      return
    end

    if on_done then
      on_done(result.stdout)
    end
  end)
end

local function extract_json(text)
  if not text or text == "" then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, text)
  if ok then
    return decoded
  end
  local start_pos = text:find("{", 1, true)
  local end_pos = text:match(".*()}")
  if start_pos and end_pos and end_pos > start_pos then
    local chunk = text:sub(start_pos, end_pos)
    local ok2, decoded2 = pcall(vim.json.decode, chunk)
    if ok2 then
      return decoded2
    end
  end
  return nil
end

local function parse_links(content)
  local parsed = extract_json(content)
  if not parsed or type(parsed) ~= "table" then
    return nil
  end
  if parsed.links and type(parsed.links) == "table" then
    return parsed.links
  end
  if parsed and type(parsed) == "table" then
    return parsed
  end
  return nil
end

function M.auto_link(opts)
  opts = opts or {}

  if inflight then
    vim.notify("AuditScope: Auto-link already running.", vim.log.levels.INFO)
    return
  end

  local subject = db.get_subject()
  if not subject then
    notify_err("AuditScope: No active subject. Use :AuditSubjectNew or :AuditSubjectSelect.")
    return
  end

  local nodes = db.get_nodes()
  if #nodes < 2 then
    notify_err("AuditScope: Not enough nodes to auto-link.")
    return
  end

  local source = nil
  if opts.source_id then
    for _, n in ipairs(nodes) do
      if n.id == opts.source_id then
        source = n
        break
      end
    end
  end
  if not source then
    source = pick_source_node()
  end

  if not source then
    notify_err("AuditScope: Could not determine source node.")
    return
  end

  local candidates = {}
  for _, n in ipairs(nodes) do
    if n.id ~= source.id then
      if ontology.is_link_allowed(source.type, n.type) then
        table.insert(candidates, n)
      end
    end
  end

  if #candidates == 0 then
    notify_err("AuditScope: No eligible candidates (level rules).")
    return
  end

  table.sort(candidates, function(a, b)
    return (a.timestamp or 0) > (b.timestamp or 0)
  end)

  local max_candidates = config.llm.max_candidates or 40
  if #candidates > max_candidates then
    local trimmed = {}
    for i = 1, max_candidates do
      table.insert(trimmed, candidates[i])
    end
    candidates = trimmed
  end

  local prompt = build_prompt(source, candidates)
  local payload = {
    model = config.llm.model,
    temperature = 0.2,
    messages = {
      {
        role = "system",
        content = table.concat({
          "You are an audit assistant.",
          "Given a source node and a list of candidate nodes, select up to "
            .. tostring(config.llm.max_links)
            .. " best links from the source to candidates.",
          "Only consider candidates that are same-level or higher-level than the source.",
          "Level map: " .. format_level_map(),
          "Use relation values: supports, refutes, relates.",
          "Respond ONLY with JSON: {\"links\":[{\"target_id\":\"...\",\"relation\":\"...\",\"confidence\":0.0,\"reason\":\"...\"}]}",
        }, " "),
      },
      {
        role = "user",
        content = prompt,
      },
    },
  }

  inflight = true
  vim.notify("AuditScope: Auto-link running...", vim.log.levels.INFO)

  request_openrouter_async(payload, function(raw)
    inflight = false
    if not raw then
      return
    end

    local decoded = extract_json(raw)
    if not decoded then
      notify_err("AuditScope: Failed to parse OpenRouter response.")
      return
    end

    local content = decoded.choices
      and decoded.choices[1]
      and decoded.choices[1].message
      and decoded.choices[1].message.content

    local links = parse_links(content)
    if not links or #links == 0 then
      notify_err("AuditScope: No link suggestions returned.")
      return
    end

    local edges = db.get_edges()
    local edge_map = {}
    for _, edge in ipairs(edges) do
      local key = string.format("%s|%s|%s", edge.from or "", edge.to or "", edge.relation or "")
      edge_map[key] = true
    end

    local applied = 0
    local max_links = config.llm.max_links or 3
    for _, link in ipairs(links) do
      if applied >= max_links then
        break
      end
      if type(link) == "table" then
        local target_id = link.target_id or link.id or link.node_id
        local confidence = tonumber(link.confidence or 0) or 0
        if target_id and confidence >= (config.llm.min_confidence or 0) then
          local relation = normalize_relation(link.relation)
          local key = string.format("%s|%s|%s", source.id, target_id, relation)
          if not edge_map[key] then
            db.add_edge(source.id, target_id, relation)
            edge_map[key] = true
            applied = applied + 1
          end
        end
      end
    end

    if applied > 0 then
      vim.notify(string.format("AuditScope: Auto-linked %d node(s).", applied), vim.log.levels.INFO)
    else
      vim.notify("AuditScope: No links applied (low confidence or duplicates).", vim.log.levels.INFO)
    end
  end)
end

return M
