local M = {}

local CLI_PATH = "auditscope"
local PASSWORD = nil

function M.setup(opts)
  opts = opts or {}
  if opts.cli_path then
    CLI_PATH = opts.cli_path
  end
  if opts.password then
    PASSWORD = opts.password
  end
end

local function run_cli(args, opts)
  opts = opts or {}
  local cmd_str = CLI_PATH .. " " .. table.concat(args, " ")
  local output = vim.fn.systemlist(cmd_str)
  local exit_code = vim.v.shell_error
  
  if exit_code ~= 0 then
    local stderr = table.concat(output, "\n")
    return nil, stderr
  end
  
  local stdout = table.concat(output, "\n")
  if stdout and stdout ~= "" then
    local ok, decoded = pcall(vim.json.decode, stdout)
    if ok and type(decoded) == "table" then
      if decoded.status == "error" then
        return nil, decoded.error or decoded.message or "Unknown error"
      end
      return decoded
    end
  end
  
  return { status = "success" }
end

function M.request_password(callback)
  if PASSWORD then
    return callback(PASSWORD)
  end
  
  vim.ui.input({ prompt = "AuditScope Password: ", secret = true }, function(input)
    if input and input ~= "" then
      PASSWORD = input
      callback(input)
    else
      vim.notify("AuditScope: Password required for this operation.", vim.log.levels.WARN)
    end
  end)
end

function M.clear_password()
  PASSWORD = nil
end

function M.set_password(pwd)
  PASSWORD = pwd
end

-- === Subject Operations ===

function M.list_subjects()
  local result, err = run_cli({ "subject", "list" })
  if err then
    return nil, err
  end
  return result and result.data and result.data.subjects or {}
end

function M.show_subject()
  local result, err = run_cli({ "subject", "show" })
  if err then
    return nil, err
  end
  return result and result.data
end

function M.select_subject(subject_id, password)
  password = password or PASSWORD
  if not password then
    return nil, "Password required for subject selection"
  end
  
  local result, err = run_cli({ 
    "subject", "select", subject_id, 
    "--password", password 
  })
  if err then
    return nil, err
  end
  return result
end

function M.select_subject_interactive(subject_id, callback)
  M.request_password(function(password)
    local result, err = M.select_subject(subject_id, password)
    if callback then
      callback(result, err)
    end
  end)
end

function M.create_subject(title, password)
  password = password or PASSWORD
  if not password then
    return nil, "Password required for subject creation"
  end
  
  local result, err = run_cli({ 
    "subject", "new", vim.fn.shellescape(title), 
    "--password", password 
  })
  if err then
    return nil, err
  end
  return result and result.data
end

function M.create_subject_interactive(title, callback)
  M.request_password(function(password)
    local result, err = M.create_subject(title, password)
    if callback then
      callback(result, err)
    end
  end)
end

function M.delete_subject(subject_id, password)
  password = password or PASSWORD
  if not password then
    return nil, "Password required for subject deletion"
  end
  
  local result, err = run_cli({ 
    "subject", "delete", subject_id, 
    "--password", password 
  })
  if err then
    return nil, err
  end
  return result
end

function M.delete_subject_interactive(subject_id, callback)
  M.request_password(function(password)
    local result, err = M.delete_subject(subject_id, password)
    if callback then
      callback(result, err)
    end
  end)
end

-- === Node Operations ===

function M.list_nodes(opts)
  opts = opts or {}
  local args = { "node", "list" }
  if opts.type then
    table.insert(args, "--type")
    table.insert(args, opts.type)
  end
  if opts.file then
    table.insert(args, "--file")
    table.insert(args, opts.file)
  end
  
  local result, err = run_cli(args)
  if err then
    return nil, err
  end
  return result and result.data and result.data.nodes or {}
end

function M.show_node(node_id)
  local result, err = run_cli({ "node", "show", node_id })
  if err then
    return nil, err
  end
  return result and result.data and result.data.node
end

function M.create_node(node)
  local args = { 
    "node", "new", node.type,
    "--title", vim.fn.shellescape(node.title or "")
  }
  
  if node.description and node.description ~= "" then
    table.insert(args, "--description")
    table.insert(args, vim.fn.shellescape(node.description))
  end
  if node.file and node.file ~= "" then
    table.insert(args, "--file")
    table.insert(args, node.file)
  end
  if node.start_line and node.start_line > 0 then
    table.insert(args, "--start-line")
    table.insert(args, tostring(node.start_line))
  end
  if node.end_line and node.end_line > 0 then
    table.insert(args, "--end-line")
    table.insert(args, tostring(node.end_line))
  end
  
  local result, err = run_cli(args)
  if err then
    return nil, err
  end
  return result and result.data
end

function M.update_node(node_id, updates)
  local args = { "node", "update", node_id }
  
  if updates.title then
    table.insert(args, "--title")
    table.insert(args, vim.fn.shellescape(updates.title))
  end
  if updates.description then
    table.insert(args, "--description")
    table.insert(args, vim.fn.shellescape(updates.description))
  end
  if updates.file then
    table.insert(args, "--file")
    table.insert(args, updates.file)
  end
  if updates.start_line then
    table.insert(args, "--start-line")
    table.insert(args, tostring(updates.start_line))
  end
  if updates.end_line then
    table.insert(args, "--end-line")
    table.insert(args, tostring(updates.end_line))
  end
  
  local result, err = run_cli(args)
  if err then
    return nil, err
  end
  return result and result.data
end

function M.delete_node(node_id)
  local result, err = run_cli({ "node", "delete", node_id })
  if err then
    return nil, err
  end
  return result
end

function M.add_snippet(node_id, snippet)
  local args = { 
    "node", "snippet", "add", node_id,
    "--text", vim.fn.shellescape(snippet.text or "")
  }
  
  if snippet.file then
    table.insert(args, "--file")
    table.insert(args, snippet.file)
  end
  if snippet.start_line then
    table.insert(args, "--start-line")
    table.insert(args, tostring(snippet.start_line))
  end
  if snippet.end_line then
    table.insert(args, "--end-line")
    table.insert(args, tostring(snippet.end_line))
  end
  
  local result, err = run_cli(args)
  if err then
    return nil, err
  end
  return result and result.data
end

function M.delete_snippet(node_id, index)
  local result, err = run_cli({ "node", "snippet", "delete", node_id, tostring(index) })
  if err then
    return nil, err
  end
  return result
end

-- === Edge Operations ===

function M.list_edges()
  local result, err = run_cli({ "edge", "list" })
  if err then
    return nil, err
  end
  return result and result.data and result.data.edges or {}
end

function M.create_edge(from_id, to_id, relation)
  local result, err = run_cli({ 
    "edge", "link", from_id, to_id, 
    "--relation", relation 
  })
  if err then
    return nil, err
  end
  return result and result.data
end

function M.delete_edge(from_id, to_id)
  local result, err = run_cli({ "edge", "unlink", from_id, to_id })
  if err then
    return nil, err
  end
  return result
end

-- === Summary Operations ===

function M.get_summary()
  local result, err = run_cli({ "summary", "show" })
  if err then
    return nil, err
  end
  return result and result.data and result.data.summary or ""
end

function M.set_summary(summary)
  local result, err = run_cli({ "summary", "set", vim.fn.shellescape(summary) })
  if err then
    return nil, err
  end
  return result
end

function M.clear_summary()
  local result, err = run_cli({ "summary", "clear" })
  if err then
    return nil, err
  end
  return result
end

-- === Git Operations ===

function M.get_git_context()
  local result, err = run_cli({ "git", "context" })
  if err then
    return nil, err
  end
  return result and result.data
end

function M.lock_commit(commit_hash, password)
  password = password or PASSWORD
  if not password then
    return nil, "Password required for commit lock"
  end
  
  local result, err = run_cli({ 
    "git", "lock", commit_hash, 
    "--password", password 
  })
  if err then
    return nil, err
  end
  return result
end

function M.lock_commit_interactive(commit_hash, callback)
  M.request_password(function(password)
    local result, err = M.lock_commit(commit_hash, password)
    if callback then
      callback(result, err)
    end
  end)
end

function M.unlock_commit()
  local result, err = run_cli({ "git", "unlock" })
  if err then
    return nil, err
  end
  return result
end

-- === Report Operations ===

function M.generate_report()
  local result, err = run_cli({ "report", "generate" })
  if err then
    return nil, err
  end
  return result and result.data
end

-- === Auto-link Operations ===

function M.auto_link(node_id, opts)
  opts = opts or {}
  local args = { "autolink", node_id }
  
  if opts.max_links then
    table.insert(args, "--max-links")
    table.insert(args, tostring(opts.max_links))
  end
  if opts.min_confidence then
    table.insert(args, "--min-confidence")
    table.insert(args, tostring(opts.min_confidence))
  end
  
  local result, err = run_cli(args)
  if err then
    return nil, err
  end
  return result and result.data
end

return M