local M = {}

local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- Start a spinner on the command line. Returns a handle to pass to stop().
function M.start(label)
  local frame = 1
  local timer = vim.uv.new_timer()
  timer:start(0, 100, vim.schedule_wrap(function()
    vim.api.nvim_echo({ { frames[frame] .. "  " .. label, "DiagnosticInfo" } }, false, {})
    frame = (frame % #frames) + 1
  end))
  return timer
end

-- Stop the spinner and clear the command line.
function M.stop(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
  vim.schedule(function()
    vim.api.nvim_echo({ { "" } }, false, {})
  end)
end

return M
