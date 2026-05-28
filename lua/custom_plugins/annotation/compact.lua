local store = require("custom_plugins.annotation.store")
local progress = require("custom_plugins.annotation.progress")
local session = require("custom_plugins.annotation.session")

local M = {}

local COMPACT_PROMPT = [[You are compacting annotation files for a smart contract codebase.

Your task: review the existing annotation files listed below and reduce redundancy by merging similar or overlapping annotations.

STEPS:
1. Read through all annotation file contents provided.
2. Identify annotations that:
   - Cover the same or overlapping code regions
   - Express the same or very similar ideas
   - Are redundant in content
3. For each group of similar annotations:
   - Merge them into a single, higher-quality annotation
   - Use the write tool to overwrite the lowest-numbered file with the merged content
   - Use the bash tool to delete the redundant files
4. Leave unrelated annotations untouched.
5. After all merges, renumber remaining files sequentially (001, 002, 003...) using write + bash.

RULES:
- Only merge annotations that genuinely overlap in meaning — do not force unrelated annotations together
- The merged annotation must preserve all important information from the originals
- Keep the original frontmatter format (tag, file, line_start, line_end, author)
- For merged line ranges, use the union (smallest line_start, largest line_end)
- Do not change annotations that have no similar counterpart

Annotation files to review:
]]

local function build_prompt(annotations)
  local prompt = COMPACT_PROMPT
  for _, ann in ipairs(annotations) do
    prompt = prompt .. "\n---\nFile path: " .. (ann.file or "?") .. "\n"
    prompt = prompt .. (ann.raw_content or "") .. "\n"
  end
  return prompt
end

local function build_cmd(backend, prompt)
  if backend == "claude" then
    local flags = session.flags()
    local cmd = { "claude", "--print", "--dangerously-skip-permissions" }
    vim.list_extend(cmd, flags)
    table.insert(cmd, prompt)
    return cmd
  else
    return {
      "opencode", "run",
      "--dangerously-skip-permissions",
      prompt,
    }
  end
end

function M.compact()
  local generate = require("custom_plugins.annotation.generate")
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  if buf_path == "" then
    vim.notify("Annotation: No file open", vim.log.levels.WARN)
    return
  end

  local annotations = store.get_cached(buf_path)
  if #annotations == 0 then
    vim.notify("Annotation: No annotations to compact", vim.log.levels.INFO)
    return
  end
  if #annotations < 2 then
    vim.notify("Annotation: Only one annotation, nothing to compact", vim.log.levels.INFO)
    return
  end

  local rel = store.file_rel_path(buf_path)
  local backend = generate.backend
  local label = string.format("compact %s (%d annotations)", rel, #annotations)

  local function do_compact()
    local spinner = progress.start(
      string.format("Compacting %d annotations (%s)  %s", #annotations, backend, rel)
    )

    local cmd_args = build_cmd(backend, build_prompt(annotations))

    vim.system(cmd_args, {
      text = true,
      cwd = store.git_root() or vim.fn.getcwd(),
      timeout = 180000,
    }, function(result)
      progress.stop(spinner)
      vim.schedule(function()
        if result.code ~= 0 then
          local err_msg = result.stderr and result.stderr:sub(1, 300) or "unknown error"
          vim.notify("Annotation: Compact failed (exit " .. result.code .. "): " .. err_msg, vim.log.levels.ERROR)
          generate._dispatch_next()
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
        local remaining = #generate._queue
        local done_msg = string.format("Annotation: Compacted %d → %d annotations for %s.", #annotations, #new_anns, rel)
        if remaining > 0 then
          done_msg = done_msg .. string.format("  (%d still queued)", remaining)
        end
        vim.notify(done_msg, vim.log.levels.INFO)

        generate._dispatch_next()
      end)
    end)
  end

  generate._enqueue(do_compact, label)
end

return M
