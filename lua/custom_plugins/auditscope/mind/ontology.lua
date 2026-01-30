local M = {}

M.levels = {
  note = 0,
  evidence = 0,
  insight = 0,
  question = 0,
  hypothesis = 0,
  fact = 0,
  assumption = 0,
  invariant = 0,
  finding = 1,
  decision = 2,
  risk = 2,
}

function M.get_level(node_type)
  if not node_type then
    return 0
  end
  return M.levels[node_type] or 0
end

function M.is_link_allowed(from_type, to_type)
  local from_level = M.get_level(from_type)
  local to_level = M.get_level(to_type)
  if from_level == to_level then
    return true
  end
  return from_level < to_level
end

function M.describe_rule(from_type, to_type)
  local from_level = M.get_level(from_type)
  local to_level = M.get_level(to_type)
  return string.format(
    "Rule: same level or upward only. From %s(L%d) to %s(L%d).",
    tostring(from_type or "unknown"),
    from_level,
    tostring(to_type or "unknown"),
    to_level
  )
end

return M
