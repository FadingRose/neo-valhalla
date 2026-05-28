local uv = vim.uv or vim.loop

local M = {}

local GLANCE_ROOT = vim.fs.joinpath(vim.fn.expand("~"), ".local", "share", "auditscope", "glance")

local function ensure_dir()
  uv.fs_mkdir(GLANCE_ROOT, 493)
end

local function path_hash(abs_path)
  return vim.fn.sha256(abs_path):sub(1, 16)
end

local function file_path(abs_path)
  ensure_dir()
  return vim.fs.joinpath(GLANCE_ROOT, path_hash(abs_path) .. ".jsonl")
end

local function index_path()
  ensure_dir()
  return vim.fs.joinpath(GLANCE_ROOT, "_index.json")
end

local function load_index()
  local path = index_path()
  local fd = io.open(path, "r")
  if not fd then
    return {}
  end
  local content = fd:read("*a")
  fd:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    return decoded
  end
  return {}
end

local function save_index(index)
  local path = index_path()
  local fd = io.open(path, "w")
  if not fd then
    return
  end
  fd:write(vim.json.encode(index))
  fd:close()
end

local index_cache = nil

local function touch_index(abs_path)
  if not index_cache then
    index_cache = load_index()
  end
  local hash = path_hash(abs_path)
  if not index_cache[hash] then
    index_cache[hash] = abs_path
    save_index(index_cache)
  end
end

function M.append(abs_path, records)
  if not records or #records == 0 then
    return
  end
  touch_index(abs_path)

  local path = file_path(abs_path)
  local fd = io.open(path, "a")
  if not fd then
    return
  end
  for _, rec in ipairs(records) do
    fd:write(vim.json.encode(rec) .. "\n")
  end
  fd:close()
end

function M.load(abs_path)
  local path = file_path(abs_path)
  local fd = io.open(path, "r")
  if not fd then
    return {}
  end

  local aggregated = {}
  for line in fd:lines() do
    local ok, rec = pcall(vim.json.decode, line)
    if ok and type(rec) == "table" and rec.line then
      local key = tostring(rec.line)
      aggregated[key] = (aggregated[key] or 0) + (rec.seconds or 0)
    end
  end
  fd:close()
  return aggregated
end

function M.load_all_under_git(git_root)
  if not index_cache then
    index_cache = load_index()
  end

  local normalized_root = vim.fs.normalize(git_root)
  local prefix = normalized_root .. "/"

  local result = {}
  for hash, abs_path in pairs(index_cache) do
    local norm_path = vim.fs.normalize(abs_path)
    if norm_path == normalized_root or vim.startswith(norm_path, prefix) then
      result[abs_path] = M.load(abs_path)
    end
  end
  return result
end

function M.compact(abs_path)
  local data = M.load(abs_path)
  if not next(data) then
    return
  end

  local path = file_path(abs_path)
  local fd = io.open(path, "w")
  if not fd then
    return
  end
  for line_key, seconds in pairs(data) do
    if seconds > 0 then
      fd:write(vim.json.encode({
        line = tonumber(line_key),
        seconds = seconds,
        ts = os.time(),
      }) .. "\n")
    end
  end
  fd:close()
end

function M.clear(abs_path)
  local path = file_path(abs_path)
  local fd = io.open(path, "w")
  if fd then
    fd:close()
  end
end

function M.get_index()
  if not index_cache then
    index_cache = load_index()
  end
  return index_cache
end

return M
