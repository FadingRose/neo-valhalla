local M = {}

local defaults = {
  enabled = false,
  commit_range = nil,
  line_ranges = nil,
  bar_char = "▎",
  palette = {
    "#e06c75",
    "#e5c07b",
    "#98c379",
    "#56b6c2",
    "#61afef",
    "#c678dd",
    "#d19a66",
    "#7fbbb3",
  },
  sign_priority = 20,
  use_cached_commit_set = true,
}

local state = {
  config = nil,
  augroup = nil,
  commit_set_cache = {},
  buffer_cache = {},
}

local function notify(msg, level)
  vim.notify("[blaming] " .. msg, level or vim.log.levels.INFO)
end

local function trim(s)
  if type(s) ~= "string" then
    return nil
  end
  local out = vim.trim(s)
  if out == "" then
    return nil
  end
  return out
end

local function parse_line_ranges(spec)
  spec = trim(spec)
  if not spec then
    return nil
  end

  local ranges = {}
  for part in spec:gmatch("[^,]+") do
    local p = vim.trim(part)
    local a, b = p:match("^(%d+)%s*%-%s*(%d+)$")
    if a and b then
      local start_l = tonumber(a)
      local end_l = tonumber(b)
      if start_l > end_l then
        start_l, end_l = end_l, start_l
      end
      table.insert(ranges, { start_l, end_l })
    else
      local single = p:match("^(%d+)$")
      if single then
        local n = tonumber(single)
        table.insert(ranges, { n, n })
      else
        return nil, "Invalid line range segment: " .. p
      end
    end
  end

  table.sort(ranges, function(x, y)
    return x[1] < y[1]
  end)

  return ranges
end

local function line_in_ranges(lnum, ranges)
  if not ranges then
    return true
  end
  for _, r in ipairs(ranges) do
    if lnum >= r[1] and lnum <= r[2] then
      return true
    end
    if lnum < r[1] then
      return false
    end
  end
  return false
end

local function system_text(cmd, cwd)
  if vim.system then
    local res = vim.system(cmd, { cwd = cwd, text = true }):wait()
    if res.code ~= 0 then
      local err = trim(res.stderr) or trim(res.stdout) or "command failed"
      return nil, err
    end
    return res.stdout or ""
  end

  local escaped = {}
  for _, token in ipairs(cmd) do
    table.insert(escaped, vim.fn.shellescape(token))
  end
  local full_cmd = table.concat(escaped, " ")
  if cwd then
    full_cmd = "cd " .. vim.fn.shellescape(cwd) .. " && " .. full_cmd
  end

  local out = vim.fn.systemlist(full_cmd)
  if vim.v.shell_error ~= 0 then
    return nil, table.concat(out, "\n")
  end
  return table.concat(out, "\n")
end

local function get_git_root(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  local out, err = system_text({ "git", "rev-parse", "--show-toplevel" }, dir)
  if not out then
    return nil, err
  end
  return trim(out)
end

local function relpath(root, path)
  if vim.fs and vim.fs.relpath then
    local rel = vim.fs.relpath(root, path)
    if rel then
      return rel
    end
  end
  return path
end

local function build_commit_set(root, commit_range)
  if not commit_range then
    return nil
  end

  if state.config.use_cached_commit_set and state.commit_set_cache[root] and state.commit_set_cache[root][commit_range] then
    return state.commit_set_cache[root][commit_range]
  end

  local out, err = system_text({ "git", "rev-list", commit_range }, root)
  if not out then
    return nil, err
  end

  local set = {}
  for sha in out:gmatch("([0-9a-fA-F]+)") do
    set[sha:lower()] = true
  end

  state.commit_set_cache[root] = state.commit_set_cache[root] or {}
  state.commit_set_cache[root][commit_range] = set

  return set
end

local function parse_blame_porcelain(text)
  local result = {}
  for line in text:gmatch("[^\n]+") do
    local sha, final_start, count = line:match("^([0-9a-f]+)%s+%d+%s+(%d+)%s*(%d*)")
    if sha and final_start then
      local first = tonumber(final_start)
      local span = tonumber(count)
      if not span or span < 1 then
        span = 1
      end
      for i = first, first + span - 1 do
        result[i] = sha
      end
    end
  end
  return result
end

local function clear_buffer_signs(bufnr)
  vim.fn.sign_unplace("BlamingBar", { buffer = bufnr })
end

local function hash_sha(sha)
  local v = tonumber(sha:sub(1, 8), 16)
  if not v then
    return 1
  end
  return v
end

local function sign_name_for_sha(sha)
  local n = #state.config.palette
  local idx = (hash_sha(sha) % n) + 1
  return "BlamingBarSign" .. idx
end

local function ensure_highlights_and_signs()
  for i, color in ipairs(state.config.palette) do
    local hl = "BlamingBarColor" .. i
    local sign = "BlamingBarSign" .. i
    vim.api.nvim_set_hl(0, hl, { fg = color })
    vim.fn.sign_define(sign, {
      text = state.config.bar_char,
      texthl = hl,
      numhl = "",
      linehl = "",
      culhl = "",
    })
  end
end

local function should_skip_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return true
  end
  if vim.bo[bufnr].buftype ~= "" then
    return true
  end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return true
  end
  return false
end

local function cache_key(bufnr)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local range = state.config.commit_range or ""
  local lines = state.config.line_ranges or ""
  local path = vim.api.nvim_buf_get_name(bufnr)
  return table.concat({ path, tostring(tick), range, lines }, "::")
end

local function place_signs(bufnr, line_to_sha, commit_set, ranges)
  clear_buffer_signs(bufnr)

  local sign_id = 100000
  for lnum, sha in pairs(line_to_sha) do
    if line_in_ranges(lnum, ranges) and (not commit_set or commit_set[sha:lower()]) then
      local sign_name = sign_name_for_sha(sha)
      vim.fn.sign_place(sign_id, "BlamingBar", sign_name, bufnr, {
        lnum = lnum,
        priority = state.config.sign_priority,
      })
      sign_id = sign_id + 1
    end
  end
end

local function compute_and_render(bufnr)
  if should_skip_buffer(bufnr) then
    return
  end

  local key = cache_key(bufnr)
  local cached = state.buffer_cache[bufnr]
  if cached and cached.key == key then
    place_signs(bufnr, cached.line_to_sha, cached.commit_set, cached.ranges)
    return
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local root, root_err = get_git_root(path)
  if not root then
    clear_buffer_signs(bufnr)
    if root_err and root_err ~= "" then
      notify("Not a git file: " .. path, vim.log.levels.DEBUG)
    end
    return
  end

  local target = relpath(root, path)
  local blame_out, blame_err = system_text({ "git", "blame", "--line-porcelain", "--", target }, root)
  if not blame_out then
    clear_buffer_signs(bufnr)
    notify("Failed to blame " .. target .. ": " .. (blame_err or "unknown error"), vim.log.levels.WARN)
    return
  end

  local commit_set = nil
  if state.config.commit_range then
    local set, set_err = build_commit_set(root, state.config.commit_range)
    if not set then
      clear_buffer_signs(bufnr)
      notify("Invalid commit range '" .. state.config.commit_range .. "': " .. (set_err or "unknown error"), vim.log.levels.ERROR)
      return
    end
    commit_set = set
  end

  local ranges, range_err = parse_line_ranges(state.config.line_ranges)
  if range_err then
    clear_buffer_signs(bufnr)
    notify(range_err, vim.log.levels.ERROR)
    return
  end

  local line_to_sha = parse_blame_porcelain(blame_out)

  state.buffer_cache[bufnr] = {
    key = key,
    line_to_sha = line_to_sha,
    commit_set = commit_set,
    ranges = ranges,
  }

  place_signs(bufnr, line_to_sha, commit_set, ranges)
end

local function refresh_current()
  compute_and_render(vim.api.nvim_get_current_buf())
end

local function clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    clear_buffer_signs(bufnr)
  end
end

local function clear_buffer_cache()
  state.buffer_cache = {}
end

local function enable_autocmds()
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
  end

  state.augroup = vim.api.nvim_create_augroup("CustomBlaming", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = state.augroup,
    callback = function(args)
      if not state.config.enabled then
        return
      end
      compute_and_render(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = state.augroup,
    callback = function()
      ensure_highlights_and_signs()
      if state.config.enabled then
        refresh_current()
      end
    end,
  })
end

local function set_commit_range(value)
  state.config.commit_range = trim(value)
  clear_buffer_cache()
end

local function set_line_ranges(value)
  if value == nil then
    state.config.line_ranges = nil
    clear_buffer_cache()
    return true
  end
  local spec = trim(value)
  if not spec then
    state.config.line_ranges = nil
    clear_buffer_cache()
    return true
  end
  local _, err = parse_line_ranges(spec)
  if err then
    return false, err
  end
  state.config.line_ranges = spec
  clear_buffer_cache()
  return true
end

local function enable(commit_range, line_ranges)
  set_commit_range(commit_range)
  if not state.config.commit_range then
    notify("Usage: :BlamingEnable <commit-range> [line-ranges]", vim.log.levels.ERROR)
    return
  end

  local ok, err = set_line_ranges(line_ranges)
  if not ok then
    notify(err, vim.log.levels.ERROR)
    return
  end

  state.config.enabled = true
  refresh_current()
  notify("Enabled. range=" .. state.config.commit_range .. (state.config.line_ranges and (" lines=" .. state.config.line_ranges) or ""))
end

local function disable()
  state.config.enabled = false
  clear_all()
  notify("Disabled")
end

local function setup_commands()
  vim.api.nvim_create_user_command("BlamingEnable", function(opts)
    local args = opts.fargs
    enable(args[1], args[2])
  end, {
    nargs = "+",
    desc = "Enable blame bar: :BlamingEnable <commit-range> [line-ranges]",
  })

  vim.api.nvim_create_user_command("BlamingDisable", function()
    disable()
  end, {
    desc = "Disable blame bar and clear signs",
  })

  vim.api.nvim_create_user_command("BlamingSetRange", function(opts)
    local range = trim(opts.args)
    if not range then
      notify("Usage: :BlamingSetRange <commit-range>", vim.log.levels.ERROR)
      return
    end
    set_commit_range(range)
    if state.config.enabled then
      refresh_current()
    end
    notify("Commit range set: " .. range)
  end, {
    nargs = 1,
    desc = "Set commit range",
  })

  vim.api.nvim_create_user_command("BlamingSetLines", function(opts)
    local ok, err = set_line_ranges(opts.args)
    if not ok then
      notify(err, vim.log.levels.ERROR)
      return
    end
    if state.config.enabled then
      refresh_current()
    end
    notify("Line ranges set" .. (trim(opts.args) and (": " .. trim(opts.args)) or ": <all>"))
  end, {
    nargs = "?",
    desc = "Set line ranges, e.g. 1-50,80-100",
  })

  vim.api.nvim_create_user_command("BlamingRefresh", function()
    clear_buffer_cache()
    if state.config.enabled then
      refresh_current()
    end
  end, {
    desc = "Refresh blame cache/signs for current buffer",
  })
end

function M.setup(opts)
  state.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  ensure_highlights_and_signs()
  enable_autocmds()
  setup_commands()

  if state.config.enabled then
    refresh_current()
  end
end

return M
