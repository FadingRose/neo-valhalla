local M = {}

M.config = {
  remappings = {
    ["@openzeppelin/contracts"] = "npm i @openzeppelin/contracts",
    ["@pythnetwork/entropy-sdk-solidity"] = "npm i @pythnetwork/entropy-sdk-solidity",
    ["abdk-libraries-solidity"] = "npm i abdk-libraries-solidity",
  },
}

--- Executes a shell command in a floating terminal window.
--- @param cmd string The command to execute.
local function run_in_terminal(cmd)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.fn.termopen(cmd, {
    on_exit = function(_, code, _)
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if code == 0 then
          vim.notify("Dependencies installed successfully.", vim.log.levels.INFO)
        else
          vim.notify("Installation failed.", vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

--- Scans the current .sol buffer for imports and installs dependencies.
function M.pick_imports()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if not string.match(filename, "%.sol$") then
    vim.notify("Not a Solidity file.", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local commands_to_run = {}
  local prefixes_found = {} -- Avoid duplicate install commands

  for _, line in ipairs(lines) do
    if string.match(line, "^%s*import") then
      local import_path = string.match(line, "[\"'](.-)[\"']")
      if import_path then
        for prefix, cmd in pairs(M.config.remappings) do
          if string.find(import_path, prefix, 1, true) == 1 then
            if not prefixes_found[prefix] then
              prefixes_found[prefix] = true
              table.insert(commands_to_run, cmd)
            end
            break -- Move to the next line once a match is found
          end
        end
      end
    end
  end

  if #commands_to_run > 0 then
    local final_cmd = table.concat(commands_to_run, " && ")
    vim.notify("Installing dependencies...", vim.log.levels.INFO)
    run_in_terminal(final_cmd)
  else
    vim.notify("No new dependencies to install.", vim.log.levels.INFO)
  end
end

--- @param opts table
function M.setup(opts)
  opts = opts or {}

  if opts.remappings then
    M.config.remappings = opts.remappings
  end

  -- Keymap to trigger the import picker
  vim.keymap.set("n", "<leader>si", function()
    require("custom_plugins.sol-import").pick_imports()
    vim.cmd("LspRestart")
  end, { desc = "Install Solidity dependencies" })
end

return M
