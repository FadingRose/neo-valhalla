local M = {}

M._cache = {}
M._dir_name = ".annotations"

local function find_git_root()
  local git_dir = vim.fn.finddir(".git", vim.fn.getcwd() .. ";")
  if git_dir == "" then
    return nil
  end
  local root = vim.fn.fnamemodify(git_dir, ":p:h:h")
  return root:gsub("/+$", "")
end

local function annotations_root()
  local root = find_git_root()
  if not root then
    return nil
  end
  return root .. "/" .. M._dir_name
end

local function file_rel_path(abs_path)
  local root = find_git_root()
  if not root then
    return abs_path
  end
  return abs_path:gsub("^" .. vim.pesc(root) .. "/", "")
end

local function annotations_for_file_dir(rel_path)
  local root = annotations_root()
  if not root then
    return nil
  end
  return root .. "/" .. rel_path
end

local function parse_frontmatter(content)
  local fm_str = content:match("^%-%-%-\n(.-)\n%-%-%-\n?")
  if not fm_str then
    return nil
  end
  local meta = {}
  for line in fm_str:gmatch("[^\n]+") do
    local key, value = line:match("^([%w_]+):%s*(.+)$")
    if key and value then
      value = value:gsub('^"', ""):gsub('"$', "")
      if key == "line_start" or key == "line_end" then
        meta[key] = tonumber(value)
      else
        meta[key] = value
      end
    end
  end
  return meta
end

local function parse_body(content)
  local body = content:gsub("^%-%-%-\n.-\n%-%-%-\n?", "")
  return vim.trim(body)
end

local function parse_tag(body)
  if not body then
    return "note", body
  end
  local tags = {
    "economic", "security", "invariant", "mechanism", "gotcha",
    "note", "observation", "warning", "question", "insight",
    "step", "risk", "assumption", "finding", "decision",
  }
  for _, tag in ipairs(tags) do
    local cap = tag:sub(1, 1):upper() .. tag:sub(2)
    local bracket = "[" .. cap .. "]"
    if body:find(bracket, 1, true) then
      local clean = body:gsub("^" .. vim.pesc(bracket) .. "\n?", "")
      return tag, clean
    end
  end
  return "note", body
end

local function load_annotation_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then
    return nil
  end

  local meta = parse_frontmatter(content)
  if not meta or not meta.line_start then
    return nil
  end

  local body = parse_body(content)
  local tag, clean_body = parse_tag(body)

  local basename = vim.fn.fnamemodify(path, ":t:r")
  local id = basename:match("^(%d+)") or basename

  return {
    id = id,
    file_path = meta.file,
    line_start = meta.line_start,
    line_end = meta.line_end or meta.line_start,
    author = meta.author or "unknown",
    tag = meta.tag or tag,
    body = clean_body or body,
    raw_content = content,
    file = path,
    mtime = vim.fn.getftime(path),
  }
end

local function scan_dir_for_annotations(dir)
  local annotations = {}
  if vim.fn.isdirectory(dir) == 0 then
    return annotations
  end
  local items = vim.fn.readdir(dir)
  for _, item in ipairs(items) do
    if item:match("%.md$") then
      local ann = load_annotation_file(dir .. "/" .. item)
      if ann then
        table.insert(annotations, ann)
      end
    end
  end
  table.sort(annotations, function(a, b)
    return a.line_start < b.line_start
  end)
  return annotations
end

function M.load_for_file(buf_path)
  local rel = file_rel_path(buf_path)
  local dir = annotations_for_file_dir(rel)
  if not dir then
    return {}
  end
  local annotations = scan_dir_for_annotations(dir)
  M._cache[rel] = {
    annotations = annotations,
    mtime = vim.fn.getftime(dir),
  }
  return annotations
end

function M.get_cached(buf_path)
  local rel = file_rel_path(buf_path)
  local cached = M._cache[rel]
  if not cached then
    return M.load_for_file(buf_path)
  end
  local dir = annotations_for_file_dir(rel)
  if dir then
    local mtime = vim.fn.getftime(dir)
    if mtime ~= cached.mtime then
      return M.load_for_file(buf_path)
    end
  end
  return cached.annotations
end

function M.get_all_annotations()
  local root = annotations_root()
  if not root or vim.fn.isdirectory(root) == 0 then
    return {}
  end
  local all = {}
  local function scan(d)
    if vim.fn.isdirectory(d) == 0 then
      return
    end
    for _, item in ipairs(vim.fn.readdir(d)) do
      local full = d .. "/" .. item
      if vim.fn.isdirectory(full) == 1 then
        scan(full)
      elseif item:match("%.md$") then
        local ann = load_annotation_file(full)
        if ann then
          table.insert(all, ann)
        end
      end
    end
  end
  scan(root)
  return all
end

function M.clear_cache()
  M._cache = {}
end

function M.next_id(dir)
  if vim.fn.isdirectory(dir) == 0 then
    return "001"
  end
  local max_id = 0
  for _, item in ipairs(vim.fn.readdir(dir)) do
    local n = item:match("^(%d+)")
    if n then
      local num = tonumber(n)
      if num and num > max_id then
        max_id = num
      end
    end
  end
  return string.format("%03d", max_id + 1)
end

function M.make_annotation_path(rel_path, id, tag, line_start, line_end)
  local dir = annotations_for_file_dir(rel_path)
  if not dir then
    return nil
  end
  local range = line_start == line_end
      and string.format("L%d", line_start)
      or string.format("L%d-%d", line_start, line_end)
  return string.format("%s/%s-%s-%s.md", dir, id, tag, range)
end

function M.annotations_root()
  return annotations_root()
end

function M.git_root()
  return find_git_root()
end

function M.annotations_for_file_dir(rel_path)
  return annotations_for_file_dir(rel_path)
end

function M.file_rel_path(abs_path)
  return file_rel_path(abs_path)
end

return M
