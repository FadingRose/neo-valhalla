-- Manages a persistent Claude session per project (git root).
-- First call uses --session-id <uuid> to create the session.
-- All subsequent calls use --resume <uuid> to continue it.
-- State is stored in .annotations/.session_id as "<uuid>:<state>"
-- where state is "new" (not yet created) or "active" (already exists).

local store = require("custom_plugins.annotation.store")

local M = {}

local function session_file()
  local root = store.annotations_root()
  if not root then return nil end
  return root .. "/.session_id"
end

local function read_state()
  local path = session_file()
  if not path then return nil, nil end
  local f = io.open(path, "r")
  if not f then return nil, nil end
  local line = vim.trim(f:read("*a"))
  f:close()
  if line == "" then return nil, nil end
  local id, state = line:match("^([^:]+):([^:]+)$")
  if id and state then
    return id, state
  end
  -- legacy: just an id with no state marker
  return line, "active"
end

local function write_state(id, state)
  local path = session_file()
  if not path then return end
  local root = store.annotations_root()
  if root and vim.fn.isdirectory(root) == 0 then
    vim.fn.mkdir(root, "p")
  end
  local f = io.open(path, "w")
  if f then
    f:write(id .. ":" .. state)
    f:close()
  end
end

local function new_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return template:gsub("[xy]", function(c)
    local v = c == "x" and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end)
end

-- Returns the CLI flags to use for the next invocation.
-- { "--session-id", uuid } on the very first call (creates session).
-- { "--resume", uuid }     on all subsequent calls (continues session).
-- Also marks the session as active after the first use.
function M.flags()
  local id, state = read_state()
  if not id then
    id = new_uuid()
    write_state(id, "new")
    state = "new"
  end

  if state == "new" then
    write_state(id, "active")
    return { "--session-id", id }
  else
    return { "--resume", id }
  end
end

-- Force a brand-new session on the next call.
function M.reset()
  local id = new_uuid()
  write_state(id, "new")
  vim.notify("Annotation: session reset (" .. id:sub(1, 8) .. "...)", vim.log.levels.INFO)
  return id
end

-- Read the current session ID without mutating state.
function M.current()
  local id = read_state()
  return id
end

return M
