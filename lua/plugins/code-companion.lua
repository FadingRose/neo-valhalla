return {
  "olimorris/codecompanion.nvim",
  config = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },

  opts = {

    display = {
      chat = {
        -- Change the default icons
        icons = {
          pinned_buffer = " ",
          watched_buffer = "👀 ",
        },

        -- Alter the sizing of the debug window
        debug_window = {
          ---@return number|fun(): number
          width = vim.o.columns - 5,
          ---@return number|fun(): number
          height = vim.o.lines - 2,
        },

        -- Options to customize the UI of the chat buffer
        window = {
          layout = "vertical", -- float|vertical|horizontal|buffer
          position = nil, -- left|right|top|bottom (nil will default depending on vim.opt.plitright|vim.opt.splitbelow)
          border = "single",
          height = 0.8,
          width = 0.45,
          relative = "editor",
          opts = {
            breakindent = true,
            cursorcolumn = false,
            cursorline = false,
            foldcolumn = "0",
            linebreak = true,
            list = false,
            numberwidth = 1,
            signcolumn = "no",
            spell = false,
            wrap = true,
          },
        },

        ---Customize how tokens are displayed
        ---@param tokens number
        ---@param adapter CodeCompanion.Adapter
        ---@return string
        token_count = function(tokens, adapter)
          return " (" .. tokens .. " tokens)"
        end,
      },
    },

    -- 放到setup函数中
    prompt_library = {
      ["DeepSeek Explain In Chinese"] = {
        strategy = "chat",
        description = "中文解释代码",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "explain in chinese",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "siliconflow_r1",
            model = "Pro/deepseek-ai/DeepSeek-R1",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[当被要求解释代码时，请遵循以下步骤：

  1. 识别编程语言。
  2. 描述代码的目的，并引用该编程语言的核心概念。
  3. 解释每个函数或重要的代码块，包括参数和返回值。
  4. 突出说明使用的任何特定函数或方法及其作用。
  5. 如果适用，提供该代码如何融入更大应用程序的上下文。]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[请解释 buffer %d 中的这段代码:

  ```%s
  %s
  ```
  ]],
                context.bufnr,
                context.filetype,
                input
              )
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
    },

    strategies = {
      chat = { adapter = "qwen_coder" },
      inline = { adapter = "siliconflow" },
      agent = { adapter = "siliconflow" },
    },
    adapters = {
      -- copilot_claude = function()
      --   return require("codecompanion.adapters").extend("copilot", {
      --     name = "copilot_claude",
      --     schema = {
      --       model = {
      --         default = "claude-3.5-sonnet",
      --       },
      --     },
      --   })
      -- end,
      qwen_coder = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          opts = {
            languages = "Chinese",
          },
          env = {
            url = "https://api.siliconflow.cn",
            api_key = function()
              local key = vim.fn.getenv("SILICONFLOW_API_KEY")
              -- local key = os.getenv("SILICONFLOW_API_KEY")
              return key
            end,
            chat_url = "/v1/chat/completions",
          },
          schema = {
            model = {
              default = "Qwen/Qwen2.5-Coder-32B-Instruct",
            },
          },
        })
      end,
      siliconflow_r1 = function()
        return require("codecompanion.adapters").extend("deepseek", {
          opts = {
            languages = "Chinese",
          },
          name = "siliconflow_r1",
          url = "https://api.siliconflow.cn/v1/chat/completions",
          env = {
            api_key = function()
              local key = vim.fn.getenv("SILICONFLOW_API_KEY")
              return key
            end,
            -- chat_url = "/v1/chat/completions",
          },
          schema = {
            model = {
              default = "Pro/deepseek-ai/DeepSeek-R1",
              choices = {
                ["Pro/deepseek-ai/DeepSeek-R1"] = { opts = { can_reason = true } },
                "Pro/deepseek-ai/DeepSeek-V3",
              },
            },
            temperature = {
              default = 0.3,
            },
          },
        })
      end,
    },
  },
}
