local M = {}

M.config = {
  remappings = {
    ["@openzeppelin/contracts"] = "npm i @openzeppelin/contracts",
    ["@pythnetwork/entropy-sdk-solidity"] = "npm i @pythnetwork/entropy-sdk-solidity",
    ["abdk-libraries-solidity"] = "npm i abdk-libraries-solidity",
  },
}

--- @param opts table
function M.setup(opts)
  opts = opts or {}

  if opts.remappings then
    M.config.remappings = opts.remappings
  end

  local group = vim.api.nvim_create_augroup("MyImportPicker", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = { "*.sol" }, -- Add filetypes you need
    desc = "Pick imports on entering a buffer",
    callback = function(event_args)
      -- The 'event_args' table contains event data, including the file path
      if event_args.file and event_args.file ~= "" then
        M.pick_imports(event_args.file)
      end
    end,
  })
end

function M.pick_imports(path)
  local imported_prefixes = {}
  local file = io.open(path, "r")

  if not file then
    vim.notify("Could not open file: " .. path, vim.log.levels.ERROR)
  end

  for line in file:lines() do
    if string.match(line, "^%s*import") then
      local import_path = string.match(line, "[\"'](.-)[\"']")

      if import_path then
        for prefix, cmd in pairs(M.config.remappings) do
          if string.find(import_path, prefix, 1, true) == 1 then
            if not imported_prefixes[prefix] then
              imported_prefixes[prefix] = true
              vim.notify("Found matching import: " .. cmd, vim.log.levels.INFO)
            end
            break -- Move to the next line once a match is found
          end
        end
      end
      table.insert(imported_prefixes, line)
    end
  end

  file:close()
  -- return imports
end

return M
