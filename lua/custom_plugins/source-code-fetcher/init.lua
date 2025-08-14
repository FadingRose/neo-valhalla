local M = {}
-- https://api.etherscan.io/v2/chainlist

local API_KEY = "PAITPWREI8XJHYH5C9K7RT6XB1Q9Z38JWJ"
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
  local cmd = { "curl", "-s", "-S", "-L", "-w", "\n%{http_code}", "-X", opts.method or "GET", opts.url }

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        table.insert(stdout_parts, table.concat(data))
      end
    end,
    on_stderr = function(_, data)
      if data then
        table.insert(stderr_parts, table.concat(data))
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        return callback("curl exited with code " .. code .. ": " .. table.concat(stderr_parts), nil)
      end

      local stdout = table.concat(stdout_parts)
      -- Use a non-greedy match to handle newlines in the body
      local body, status_code_str = stdout:match("^(.-)\n(%d+)$")

      if not status_code_str then
        -- Handle cases where body is empty and only status code is in stdout
        if stdout:match("^%d+$") then
          body = ""
          status_code_str = stdout
        else
          return callback("Could not parse status code from curl output.", nil)
        end
      end

      callback(nil, {
        status = tonumber(status_code_str),
        body = body,
      })
    end,
  })
end

local function fetch_and_display_source_code(chain, address)
  local url = string.format(
    "https://api.etherscan.io/v2/api?chainid=%s&module=contract&action=getsourcecode&address=%s&apikey=%s",
    chain.chainid,
    address,
    API_KEY
  )

  vim.notify("Fetching contract source for " .. address)
  vim.http.easy_request({ url = url, method = "GET" }, function(err, response)
    if err or response.status ~= 200 then
      vim.notify("Failed to fetch contract: " .. (err or response.status), vim.log.levels.ERROR)
      return
    end

    local ok, data = pcall(vim.fn.json_decode, response.body)
    if not ok or type(data) ~= "table" or not data.result or data.status ~= "1" then
      local message = (data and type(data.result) == "string") and data.result or "Invalid response from API"
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

    -- Create a new buffer and open it in a vertical split
    vim.cmd("vsplit")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_name(buf, contract_name .. ".sol")

    -- The source code might be a single string or a JSON object for multi-file sources
    local final_code = source_code
    local is_json, parsed_json = pcall(vim.fn.json_decode, source_code)
    if is_json and type(parsed_json) == "table" then
      -- For simplicity, we just pretty-print the JSON.
      -- A more advanced implementation would handle the file structure.
      final_code = vim.fn.json_encode(parsed_json)
      vim.bo[buf].filetype = "json"
    else
      vim.bo[buf].filetype = "solidity"
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(final_code, "\n"))
    vim.notify("Contract loaded successfully!")
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
        fetch_and_display_source_code(selected_chain, address)
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
