local store = require("custom_plugins.annotation.store")
local progress = require("custom_plugins.annotation.progress")
local session = require("custom_plugins.annotation.session")

local M = {}

M.backend = "claude" -- "claude" | "opencode"
M._running = false
M._queue = {} -- { buf_path, start_line, end_line, extra_prompt, label }

local ANNOTATION_PROMPT = [[You are annotating a Solidity smart contract for human readability.

Your task: read the provided code and create annotation files that explain the economic/mechanism logic in plain language.

For each logical block, use the `write` tool to create a markdown file under `.annotations/`.

STEPS:
1. Read the source file.
2. Identify non-trivial logical blocks (economic logic, mechanism steps, invariants, gotchas).
3. For each block, create a file at:

   .annotations/<source_file_path>/<NNN>-<tag>-L<start>-<end>.md

   Where:
   - <source_file_path> is the source file path relative to git root (e.g. readonly/contracts/position/DecreaseZFPPositionUtils.sol)
   - <NNN> is a zero-padded sequential number (001, 002, 003...)
   - <tag> is one of: economic, mechanism, invariant, gotcha, security, step
   - L<start>-<end> is the line range

4. File content format (YAML frontmatter + markdown body):

```
---
tag: <tag>
file: <source_file_path>
line_start: <number>
line_end: <number>
author: {{AUTHOR}}
---

<explanation in 3-6 sentences>
```

TAG DEFINITIONS:
- [economic] - economic model, incentive, value flow, fee logic
- [mechanism] - how a mechanism works step by step
- [invariant] - what must always be true at this code point
- [gotcha] - non-obvious behavior, edge case, counter-intuitive logic
- [security] - security-relevant check or constraint
- [step] - a labeled step in a multi-step process

RULES:
1. Write in clear, concise English. Avoid restating the code.
2. Focus on WHY, not WHAT. Explain the economic reasoning.
3. Each annotation should be self-contained.
4. Do NOT annotate trivial code (getters, setters, simple assignments).
5. Keep annotations to 3-6 sentences max.
6. Create the .annotations/<source_file_path>/ directory first if it does not exist (use mkdir via bash tool).
7. Number annotations sequentially starting from 001.

Annotate the code now.]]

local function build_cmd(backend, buf_path, prompt)
  if backend == "claude" then
    local flags = session.flags()
    local cmd = { "claude", "--print", "--dangerously-skip-permissions" }
    vim.list_extend(cmd, flags)
    table.insert(cmd, prompt .. "\n\nFile to annotate: " .. buf_path)
    return cmd
  else
    return {
      "opencode", "run",
      "--file", buf_path,
      "--dangerously-skip-permissions",
      prompt,
    }
  end
end

-- Dispatch the next queued task, or clear the running flag.
local function dispatch_next()
  if #M._queue == 0 then
    M._running = false
    return
  end
  local task = table.remove(M._queue, 1)
  M._running = true
  task.fn()
end

local function execute(buf_path, start_line, end_line, extra_prompt)
  local total_lines = vim.api.nvim_buf_line_count(vim.fn.bufnr(buf_path))

  local range_hint = ""
  if start_line ~= 1 or end_line ~= total_lines then
    range_hint = string.format("\n\nFocus ONLY on lines %d to %d of the file.", start_line, end_line)
  end

  local prompt = ANNOTATION_PROMPT:gsub("{{AUTHOR}}", M.backend) .. range_hint
  if extra_prompt and extra_prompt ~= "" then
    prompt = prompt .. "\n\nAdditional instructions: " .. extra_prompt
  end

  local rel = store.file_rel_path(buf_path)
  local cmd_args = build_cmd(M.backend, buf_path, prompt)

  local queued = #M._queue
  local label = string.format("Generating annotations (%s)  %s", M.backend, rel)
  if queued > 0 then
    label = label .. string.format("  (+%d queued)", queued)
  end
  local spinner = progress.start(label)

  vim.system(cmd_args, {
    text = true,
    cwd = store.git_root() or vim.fn.getcwd(),
    timeout = 180000,
  }, function(result)
    progress.stop(spinner)
    vim.schedule(function()
      if result.code ~= 0 then
        local err_msg = result.stderr and result.stderr:sub(1, 300) or "unknown error"
        vim.notify("Annotation: Generation failed (exit " .. result.code .. "): " .. err_msg, vim.log.levels.ERROR)
        dispatch_next()
        return
      end

      store.clear_cache()
      local inline = require("custom_plugins.annotation.inline")
      inline.refresh()
      local panel = require("custom_plugins.annotation.panel")
      if panel.is_open() then
        panel.refresh()
      end

      local new_anns = store.load_for_file(buf_path)
      local remaining = #M._queue
      local done_msg = string.format("Annotation: Done. %d annotations for %s.", #new_anns, rel)
      if remaining > 0 then
        done_msg = done_msg .. string.format("  (%d still queued)", remaining)
      end
      vim.notify(done_msg, vim.log.levels.INFO)

      dispatch_next()
    end)
  end)
end

local function run_generate(buf_path, start_line, end_line, extra_prompt)
  local rel = store.file_rel_path(buf_path)
  local range_str = (start_line == end_line)
      and string.format("L%d", start_line)
      or string.format("L%d-%d", start_line, end_line)

  if M._running then
    table.insert(M._queue, {
      fn = function() execute(buf_path, start_line, end_line, extra_prompt) end,
    })
    vim.notify(
      string.format("Annotation: queued  %s %s  (position %d)", rel, range_str, #M._queue),
      vim.log.levels.INFO
    )
    return
  end

  M._running = true
  execute(buf_path, start_line, end_line, extra_prompt)
end

-- Enqueue any arbitrary task (used by compact.lua).
function M._enqueue(fn, label)
  if M._running then
    table.insert(M._queue, { fn = fn })
    vim.notify(
      string.format("Annotation: queued  %s  (position %d)", label, #M._queue),
      vim.log.levels.INFO
    )
    return false
  end
  M._running = true
  fn()
  return true
end

function M._dispatch_next()
  dispatch_next()
end

function M.set_backend(name)
  if name ~= "opencode" and name ~= "claude" then
    vim.notify("Annotation: unknown backend '" .. name .. "'", vim.log.levels.WARN)
    return
  end
  M.backend = name
  vim.notify("Annotation: backend set to " .. name, vim.log.levels.INFO)
end

function M.generate(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    vim.notify("Annotation: No file open", vim.log.levels.WARN)
    return
  end

  local start_line = opts.start_line
  local end_line = opts.end_line

  if not start_line or not end_line then
    local mode = vim.fn.mode()
    if mode:find("[vV]") then
      vim.fn.feedkeys("gv", "x")
      local s = vim.api.nvim_buf_get_mark(buf, "<")
      local e = vim.api.nvim_buf_get_mark(buf, ">")
      start_line = math.min(s[1], e[1])
      end_line = math.max(s[1], e[1])
    else
      start_line = 1
      end_line = vim.api.nvim_buf_line_count(buf)
    end
  end

  run_generate(buf_path, start_line, end_line, nil)
end

-- Generate with a custom user-supplied prompt appended to the base prompt.
function M.generate_with_prompt(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    vim.notify("Annotation: No file open", vim.log.levels.WARN)
    return
  end

  local start_line = opts.start_line
  local end_line = opts.end_line

  if not start_line or not end_line then
    local mode = vim.fn.mode()
    if mode:find("[vV]") then
      vim.fn.feedkeys("gv", "x")
      local s = vim.api.nvim_buf_get_mark(buf, "<")
      local e = vim.api.nvim_buf_get_mark(buf, ">")
      start_line = math.min(s[1], e[1])
      end_line = math.max(s[1], e[1])
    else
      start_line = 1
      end_line = vim.api.nvim_buf_line_count(buf)
    end
  end

  vim.ui.input({ prompt = "Annotation instructions: " }, function(input)
    if input == nil then return end
    run_generate(buf_path, start_line, end_line, input)
  end)
end

-- Generate annotation focused on the current cursor line.
function M.generate_at_line()
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    vim.notify("Annotation: No file open", vim.log.levels.WARN)
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  run_generate(buf_path, line, line, nil)
end

-- Generate annotation at the current cursor line with a custom prompt.
function M.generate_at_line_with_prompt()
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    vim.notify("Annotation: No file open", vim.log.levels.WARN)
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.ui.input({ prompt = "Annotation instructions (L" .. line .. "): " }, function(input)
    if input == nil then return end
    run_generate(buf_path, line, line, input)
  end)
end

return M
