local M = {}
-- https://api.etherscan.io/v2/chainlist

local json_decode = vim.json and vim.json.decode or vim.fn.json_decode

local cached_chains = nil

local API_KEY = os.getenv("ETHERSCAN_API_KEY")
-- https://api.etherscan.io/v2/api?chainid=146&module=contract&action=getsourcecode&address=0xb2a43445B97cd6A179033788D763B8d0c0487E36&apikey=PAITPWREI8XJHYH5C9K7RT6XB1Q9Z38JWJ

--- Makes an HTTP request, using vim.http if available, otherwise falling back to curl.
-- @param opts table: must contain url and method.
-- @param callback function(err, response): response has `status` and `body`.
local function http_request(opts, callback)
  -- vim.http was introduced in Neovim 0.10
  if vim.http and vim.http.easy_request then
    return vim.http.easy_request(opts, callback)
  end

  -- Fallback to curl for older Neovim versions
  local stdout_parts = {}
  local stderr_parts = {}
  local cmd = { "curl", "-s", "-S", "-L", "-X", opts.method or "GET", opts.url }

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stdout_parts, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr_parts, line)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        return callback("curl exited with code " .. code .. ": " .. table.concat(stderr_parts, "\n"), nil)
      end

      local body = table.concat(stdout_parts, "\n")
      local status_code_str = 200

      callback(nil, {
        status = tonumber(status_code_str),
        body = body,
      })
    end,
  })
end

local function fetch_and_save_source_code(chain, address)
  local url = string.format(
    "https://api.etherscan.io/v2/api?chainid=%s&module=contract&action=getsourcecode&address=%s&apikey=%s",
    chain.chainid,
    address,
    API_KEY
  )

  vim.notify("Fetching contract source for " .. address)
  http_request({ url = url, method = "GET" }, function(err, response)
    if err or response.status ~= 200 then
      vim.notify("Failed to fetch contract: " .. (err or response.status), vim.log.levels.ERROR)
      return
    end

    local ok, data = pcall(json_decode, response.body)
    if not ok or type(data) ~= "table" or not data.result or data.status ~= "1" then
      local message = (data and type(data.result) == "string") and data.result or "Invalid response from API"
      if type(data) ~= "table" then
        message = "Failed to parse JSON response: " .. vim.inspect(data)
      end
      vim.notify("API Error: " .. message, vim.log.levels.ERROR)
      return
    end

    local source_info = data.result[1]
    local source_code = source_info.SourceCode
    local contract_name = source_info.ContractName

    if not source_code or source_code == "" then
      vim.notify("Contract source code is not verified or is empty.", vim.log.levels.WARN)
      return
    end

    -- Handle double-curly braces JSON-like format by stripping the outer layer
    if string.sub(source_code, 1, 2) == "{{" and string.sub(source_code, -2) == "}}" then
      source_code = string.sub(source_code, 2, -2)
    end

    local is_json, parsed_json = pcall(json_decode, source_code)

    if is_json and type(parsed_json) == "table" and parsed_json.sources then
      -- Multi-file project structure
      local base_dir = "verified_contract/" .. contract_name .. "_" .. address
      vim.notify("Multi-file contract detected. Saving to " .. vim.fn.fnameescape(base_dir))

      for file_path, file_data in pairs(parsed_json.sources) do
        if type(file_data) == "table" and file_data.content then
          local full_path = vim.fn.fnamemodify(base_dir .. "/" .. file_path, ":p")
          local dir = vim.fn.fnamemodify(full_path, ":h")
          if vim.fn.isdirectory(dir) == 0 then
            vim.fn.mkdir(dir, "p")
          end
          vim.fn.writefile(vim.split(file_data.content, "\n", nil), full_path)
        end
      end
    else
      -- Single file (either Solidity, or a simple JSON ABI)
      local dir = "verified_contract"
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end

      local final_code = source_code
      local filename = contract_name .. "_" .. address .. ".sol"
      local filetype = "solidity"

      if is_json and type(parsed_json) == "table" then
        -- It's some other JSON format, like an ABI. Prettify it.
        final_code = vim.fn.json_encode(parsed_json)
        filename = contract_name .. "_" .. address .. ".json"
        filetype = "json"
      end

      local file_path = vim.fn.fnameescape(dir .. "/" .. filename)

      vim.cmd("vsplit " .. file_path)
      vim.bo.filetype = filetype
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(final_code, "\n"))
      vim.cmd("write")
      vim.notify("Contract saved to " .. file_path)
    end
  end)
end

function M.fetch_contract()
  M.get_chains(function(err, chains)
    if err then
      vim.notify("Failed to get chains: " .. err, vim.log.levels.ERROR)
      return
    end

    local chain_names = vim.tbl_map(function(c)
      return c.chainname
    end, chains)

    vim.ui.select(chain_names, { prompt = "Select Chain:" }, function(choice, idx)
      if not choice then
        return
      end
      local selected_chain = chains[idx]

      vim.ui.input({ prompt = "Contract Address:" }, function(address)
        if not address or address == "" then
          return
        end
        fetch_and_save_source_code(selected_chain, address)
      end)
    end)
  end)
end

--- Fetches the list of available chains from the Etherscan API.
-- @param callback function(err, chains) Called with the result.
--   - err (string | nil): An error message if the request failed.
--   - chains (table | nil): A list of chain objects if successful.
function M.get_chains(callback)
  vim.validate({
    callback = { callback, "function" },
  })

  if cached_chains then
    return callback(nil, cached_chains)
  end

  local url = "https://api.etherscan.io/v2/chainlist"

  http_request({ url = url, method = "GET" }, function(err, response)
    if err then
      return callback("Request error: " .. vim.inspect(err))
    end

    if response.status ~= 200 then
      return callback("HTTP error: " .. response.status)
    end

    local ok, data = pcall(vim.fn.json_decode, response.body)

    if not ok or type(data) ~= "table" or not data.result then
      return callback("Failed to parse JSON or invalid response format")
    end

    cached_chains = data.result
    callback(nil, data.result)
  end)
end

--- @param opts table
function M.setup(opts)
  opts = opts or {}

  -- Keymap to trigger the import picker
  vim.keymap.set("n", "<leader>ct", function()
    require("custom_plugins.source-code-fetcher").fetch_contract()
  end, { desc = "EtherscanV2: Fetch verified contract" })
end

return M
