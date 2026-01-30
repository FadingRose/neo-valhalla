local db = require("custom_plugins.auditscope.mind.db")

local M = {}

local function format_subject(item)
  local stats = item.stats or {}
  local nodes = stats.nodes or 0
  local edges = stats.edges or 0
  local updated_at = item.updated_at or stats.updated_at
  local updated = updated_at and os.date("%Y-%m-%d", updated_at) or "unknown"
  local status = item.status or "active"
  local summary_flag = stats.summary and "S" or "-"
  local report_flag = stats.report and "R" or "-"
  return string.format("%s [%s]  n:%d e:%d  %s%s  %s", item.title or "Untitled", status, nodes, edges, summary_flag, report_flag, updated)
end

local function telescope_pick(opts)
  opts = opts or {}
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_conf, conf = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_action_state, action_state = pcall(require, "telescope.actions.state")

  if not (ok_pickers and ok_finders and ok_conf and ok_actions and ok_action_state) then
    return false
  end

  local subjects = db.hydrate_subjects_with_stats()
  if #subjects == 0 then
    vim.notify("AuditScope: No subjects found. Use :AuditSubjectNew first.", vim.log.levels.INFO)
    return true
  end

  local function entry_maker(item)
    return {
      value = item,
      display = format_subject(item),
      ordinal = table.concat({
        item.title or "",
        item.status or "",
        tostring(item.updated_at or ""),
      }, " "),
    }
  end

  local prompt_title = opts.mode == "delete" and "Delete Audit Subject" or "Audit Subjects"

  pickers
    .new({}, {
      prompt_title = prompt_title,
      finder = finders.new_table({
        results = subjects,
        entry_maker = entry_maker,
      }),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        local function select_current()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value and selection.value.id then
            db.set_active_subject(selection.value.id)
            vim.notify(
              string.format("AuditScope: Active subject set to %s", selection.value.title or selection.value.id),
              vim.log.levels.INFO
            )
          end
        end

        local function delete_current()
          local selection = action_state.get_selected_entry()
          if not (selection and selection.value and selection.value.id) then
            return
          end
          actions.close(prompt_bufnr)
          local title = selection.value.title or selection.value.id
          vim.ui.input({
            prompt = string.format("Type DELETE to remove subject '%s': ", title),
          }, function(confirm)
            if confirm ~= "DELETE" then
              return
            end
            if db.delete_subject_confirmed(selection.value.id) then
              vim.notify("AuditScope: Subject deleted.", vim.log.levels.INFO)
            end
          end)
        end

        if opts.mode == "delete" then
          actions.select_default:replace(delete_current)
          map("i", "<CR>", delete_current)
          map("n", "<CR>", delete_current)
          map("i", "<C-s>", select_current)
          map("n", "s", select_current)
        else
          actions.select_default:replace(select_current)
          map("i", "<CR>", select_current)
          map("n", "<CR>", select_current)
        end
        map("i", "<C-d>", delete_current)
        map("n", "dd", delete_current)

        return true
      end,
    })
    :find()

  return true
end

function M.select_subject()
  local ok = telescope_pick({ mode = "select" })
  if not ok then
    db.select_subject()
  end
end

function M.delete_subject()
  local ok = telescope_pick({ mode = "delete" })
  if not ok then
    db.delete_subject()
  end
end

return M
