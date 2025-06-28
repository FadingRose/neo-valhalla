-- lua/custom_plugins/blockchain-explorers/init.lua

local M = {}

-- 默认配置
M.config = {
  explorers = {
    -- 交易 (tx) 浏览器
    tx = {
      { name = "Etherscan", url = "https://etherscan.io/tx/" },
      { name = "BscScan", url = "https://bscscan.com/tx/" },
      { name = "PolygonScan", url = "https://polygonscan.com/tx/" },
      { name = "Arbiscan", url = "https://arbiscan.io/tx/" },
      { name = "Optimism", url = "https://optimistic.etherscan.io/tx/" },
      { name = "Solscan", url = "https://solscan.io/tx/" }, -- For Solana
    },
    -- 地址 (address) 浏览器
    address = {
      { name = "Etherscan", url = "https://etherscan.io/address/" },
      { name = "BscScan", url = "https://bscscan.com/address/" },
      { name = "PolygonScan", url = "https://polygonscan.com/address/" },
      { name = "Arbiscan", url = "https://arbiscan.io/address/" },
      { name = "Optimism", url = "https://optimistic.etherscan.io/address/" },
      { name = "Solscan", url = "https://solscan.io/address/" }, -- For Solana
    },
  },
}

-- 用户设置函数，允许覆盖默认配置
function M.setup(opts)
  -- 深度合并用户配置和默认配置 (简单实现)
  opts = opts or {}
  if opts.explorers then
    M.config.explorers = vim.tbl_deep_extend("force", M.config.explorers, opts.explorers)
  end
end

-- 核心函数：获取当前行光标前的文本，并检查是否匹配
function M.get_completion_items(callback)
  -- 获取当前行内容直到光标位置
  local line_to_cursor = vim.api.nvim_buf_get_lines(0, vim.fn.line(".") - 1, vim.fn.line("."), true)[1]
  line_to_cursor = line_to_cursor:sub(1, vim.fn.col(".") - 1)

  -- 使用正则表达式从行尾向前匹配
  local evm_tx_hash = line_to_cursor:match("(0x[a-fA-F0-9]{64})$")
  local evm_address = line_to_cursor:match("(0x[a-fA-F0-9]{40})$")
  -- Solana tx hash (base58, a bit more complex, simple check for now)
  local sol_tx_hash = line_to_cursor:match("([1-9A-HJ-NP-Za-km-z]{80,90})$") -- A very rough check

  local items = {}
  local matched_text = nil
  local explorers_list = nil

  if evm_tx_hash then
    matched_text = evm_tx_hash
    explorers_list = M.config.explorers.tx
  elseif evm_address then
    matched_text = evm_address
    explorers_list = M.config.explorers.address
  -- You can add more specific regex for sol_tx_hash if needed
  elseif sol_tx_hash then
    matched_text = sol_tx_hash
    -- For simplicity, we use the same tx list. Can be customized.
    explorers_list = M.config.explorers.tx
  end

  if matched_text and explorers_list then
    for _, explorer in ipairs(explorers_list) do
      table.insert(items, {
        label = explorer.name .. ": " .. explorer.url .. matched_text, -- 补全菜单中显示的完整文本
        kind = vim.lsp.protocol.CompletionItemKind.Text, -- 图标类型
        insertText = explorer.url .. matched_text, -- 实际插入的文本
        documentation = "Link to " .. explorer.name,
      })
    end
  end

  -- 调用回调函数，将补全项传递给 nvim-cmp
  callback({ items = items, isIncomplete = false })
end

function M.get_blink_completions()
  -- 获取当前行内容直到光标位置
  local line_to_cursor = vim.api.nvim_buf_get_lines(0, vim.fn.line(".") - 1, vim.fn.line("."), true)[1]
  line_to_cursor = line_to_cursor:sub(1, vim.fn.col(".") - 1)

  -- 使用正则表达式从行尾向前匹配
  local evm_tx_hash = line_to_cursor:match("(0x[a-fA-F0-9]{64})$")
  local evm_address = line_to_cursor:match("(0x[a-fA-F0-9]{40})$")
  local sol_tx_hash = line_to_cursor:match("([1-9A-HJ-NP-Za-km-z]{80,90})$") -- 粗略检查

  local matched_text = nil
  local explorers_list = nil

  if evm_tx_hash then
    matched_text = evm_tx_hash
    explorers_list = M.config.explorers.tx
  elseif evm_address then
    matched_text = evm_address
    explorers_list = M.config.explorers.address
  elseif sol_tx_hash then
    matched_text = sol_tx_hash
    explorers_list = M.config.explorers.tx
  end

  if not matched_text then
    -- 如果没有匹配项，返回 nil，blink 会忽略此源
    return nil
  end

  local completions = {}
  for _, explorer in ipairs(explorers_list) do
    -- blink 可以接受字符串或 { word = "...", ... } 格式的表
    -- 我们使用表格式来提供更丰富的显示
    table.insert(completions, {
      word = explorer.url .. matched_text, -- 实际插入的文本
      menu = "[" .. explorer.name .. "]", -- 在补全项旁边显示的菜单文本
      kind = "ﳢ", -- 使用一个图标 (Text icon)
    })
  end

  -- blink 需要一个包含 `matcher`, `sorter`, `filter`, `limit`, `items` 的表
  -- matcher, sorter, filter 可以使用 blink 的默认值
  return {
    items = completions,
    -- 我们自己处理匹配，所以告诉 blink 直接使用我们的结果
    matcher = function()
      return true
    end,
  }
end

return M
