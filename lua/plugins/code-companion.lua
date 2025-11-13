return {
  "olimorris/codecompanion.nvim",
  config = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/codecompanion-history.nvim",
  },
  opts = {
    keys = {
      {
        "<Leader>A",
        "<cmd>CodeCompanionChat Toggle<CR>",
        desc = "Toggle a chat buffer",
        mode = { "n", "v" },
      },
    },

    show_defaults = false,

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

    prompt_library = {
      ["Generate Comment"] = {
        strategy = "chat",
        description = "Generate Comment",
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
            content = [[
            Generate function level comments for the selected code block.
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
              return string.format(
                [[ Generate function level comments for the selected code block:
                  ```%s
                  %s
                  ```
                ]],
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

      ["Paper Trans En -> Improve"] = {
        strategy = "chat",
        description = "translate to academic English and improve stattements",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "translate to academic english and improve representation",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "openrouter_pro",
            model = "google/gemini-2.5-pro-preview",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[
*Task: Translate academic Chinese text into formal English, focusing on smart contract/blockchain domain.*

**Instructions:**  
1. **Tone & Style:**  
   - Maintain rigorous academic tone (passive voice where appropriate, no colloquialisms).  
   - Prioritize readability for NLP/Computer Science audiences.  

2. **Terminology Handling:**  
   - Core terms: Keep "smart contract", "Gas", "EVM" etc. untranslated.  
   - 专业短语: Use IEEE/ACM conventional translations (e.g., "共识机制" → "consensus mechanism", "零知识证明" → "zero-knowledge proof").  
   - 首次出现缩写: Full term + acronym in parentheses (e.g., "去中心化应用 (Decentralized Application, DApp)").

3. **Technical Accuracy:**  
   - Verify translations against Ethereum Yellow Paper/ISO TC 307 standards.  
   - Critical terms: Cross-check with "Mastering Ethereum" (O'Reilly) glossary.  

4. **Structural Cues:**  
   - Retain original section numbering (e.g., "3.2 安全性分析" → "3.2 Security Analysis").  
   - Process LaTeX/math expressions without translation.  

5. **Contextual Requests:**  
   - [附加说明] For ambiguous terms, provide 2-3 candidate translations with RFC2119-style priority (MUST/SHOULD/MAY).  

**Example Input:**  
"在智能合约的漏洞检测中，重入攻击是最危险的威胁之一，需通过形式化验证确保状态一致性。"  

**Expected Output:**  
"In smart contract vulnerability detection, reentrancy attacks rank among the most critical threats, necessitating formal verification to ensure state consistency."  
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[

  ---
  %s
  ---
  ]],
                input
              )
            end,
            opts = {
              contains_code = false,
            },
          },
        },
      },

      ["Markdown -> LaTeX"] = {
        strategy = "chat",
        description = "Convert Markdown to LaTeX",
        opts = {
          index = 6,
          is_default = false,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "markdown to latex",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "openrouter_flash",
            model = "google/gemini-2.5-flash",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[
              Convert the following Markdown content into properly formatted LaTeX. Ensure that:
              1. Headings (`#`, `##`, etc.) are converted to LaTeX sectioning commands (`\section{}`, `\subsection{}`, etc.).
              2. Lists (both ordered and unordered) are correctly translated to LaTeX `itemize` or `enumerate` environments.
              3. Inline code (`code`) uses `\texttt{}`.
              4. Code blocks (```) are wrapped in a `verbatim` or `lstlisting` environment.
              5. Bold (**text**) becomes `\textbf{text}` and italic (*text*) becomes `\textit{text}`.
              6. Links ([text](url)) become `\href{url}{text}`.
              7. Tables are converted to LaTeX `tabular` environments.
              8. Math expressions (inline `$...$` or display `$$...$$`) are preserved as-is or properly escaped.
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[ Please handle content in buffer %d :

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

      ["Trans En -> Improve"] = {
        strategy = "chat",
        description = "translate to English and improve stattements",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "translate to english and improve",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "siliconflow_v3",
            model = "Pro/deepseek-ai/DeepSeek-V3",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[
              Translate the content to English and improve the statements.
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[ Please handle content in buffer %d :

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
      ["Audit"] = {
        strategy = "chat",
        description = "Audit Solidity code",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "audit solidity code",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "openrouter_flash",
            model = "google/gemini-2.5-pro",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[
            Audit the Solidity code for security vulnerabilities, gas optimization, and best practices.
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[ Please handle content in buffer %d :

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
      ["Trans Variable CN"] = {
        strategy = "chat",
        description = "把变量翻译为中文",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "translate to Chinese",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "openrouter_flash",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[
            读取代码块，并把变量翻译为中文，解释其语义。 
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[ 

  ```%s
  %s
  ```
  ]],
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

      ["Trans to English"] = {
        strategy = "chat",
        description = "Translate to English",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "translate to english",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "qwen_cn_to_en",
            model = "qwen-mt-turbo",
          },
        },
        prompts = {
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
              return string.format(
                [[ 
  %s
  ]],
                input
              )
            end,
            opts = {
              contains_code = false,
            },
          },
        },
      },

      ["Trans CN"] = {
        strategy = "chat",
        description = "翻译为中文",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "translate to Chinese",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          adapter = {
            name = "siliconflow_v3",
            model = "Pro/deepseek-ai/DeepSeek-V3",
          },
        },
        prompts = {
          {
            role = "system",
            content = [[
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[ 
  ```markdown
  %s
  ```
  将代码注释或纯文本翻译为中文，不需要额外解释
  ]],
                input
              )
            end,
            opts = {
              contains_code = false,
            },
          },
        },
      },
      ["Convert to one line "] = {
        strategy = "chat",
        description = "Convert to one line and add math latex",
        opts = {
          index = 5,
          is_default = true,
          is_slash_cmd = false,
          modes = { "v" },
          short_name = "Convert to one line",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = "system",
            content = [[
              转化为一行，去掉行之间的连字符，并添加必要的数学公式的 LaTeX 语法，不需要改变原文表达。
            ]],
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local input = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

              return string.format(
                [[ Please handle content in buffer %d :

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
      chat = { adapter = "openrouter_flash" },
      inline = { adapter = "openrouter_flash" },
      agent = { adapter = "openrouter_flash" },
    },
    adapters = {
      qwen_cn_to_en = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          env = {
            url = "https://dashscope.aliyuncs.com/compatible-mode",
            api_key = vim.fn.getenv("DASHSCOPE_API_KEY"),
            chat_url = "/v1/chat/completions",
          },
          schema = {
            model = {
              default = "qwen-mt-turbo",
            },
            translation_options = {
              source_language = "Chinese",
              target_lang = "English",
            },
          },
        })
      end,
      iflow = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          env = {
            url = "https://apis.iflow.cn/v1",
            api_key = "cmd:echo $IFLOW_API_KEY",
            chat_url = "/chat/completions",
          },
          schema = {
            model = {
              default = "qwen3-coder",
              choices = {
                "deepseek-v3.1",
                "qwen3-coder",
                "kimi-k2",
              },
            },
          },
        })
      end,

      openrouter_pro = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          env = {
            url = "https://openrouter.ai/api",
            api_key = "cmd:echo $OPENROUTER_API_KEY",
            chat_url = "/v1/chat/completions",
          },
          schema = {
            model = {
              default = "google/gemini-2.5-pro-preview",
            },
          },
        })
      end,

      openrouter_flash = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          env = {
            url = "https://openrouter.ai/api",
            api_key = "cmd:echo $OPENROUTER_API_KEY",
            -- api_key = vim.fn.getenv("OPENROUTER_API_KEY"),
            chat_url = "/v1/chat/completions",
          },
          schema = {
            model = {
              default = "google/gemini-2.5-flash",
              choices = {
                "google/gemini-2.5-flash",
                "google/gemini-2.5-flash-lite-preview-06-17",
              },
            },
          },
        })
      end,

      siliconflow_v3 = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          opts = {
            languages = "Chinese",
          },
          env = {
            url = "https://api.siliconflow.cn",
            api_key = function()
              local key = vim.fn.getenv("SILICONFLOW_API_KEY")
              return key
            end,
            chat_url = "/v1/chat/completions",
          },
          schema = {
            model = {
              default = "Pro/deepseek-ai/DeepSeek-V3",
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

    extensions = {
      history = {
        enabled = true,
        opts = {
          -- Keymap to open history from chat buffer (default: gh)
          keymap = "gh",
          -- Keymap to save the current chat manually (when auto_save is disabled)
          save_chat_keymap = "sc",
          -- Save all chats by default (disable to save only manually using 'sc')
          auto_save = true,
          -- Number of days after which chats are automatically deleted (0 to disable)
          expiration_days = 0,
          -- Picker interface (auto resolved to a valid picker)
          picker = "snacks", --- ("telescope", "snacks", "fzf-lua", or "default")
          ---Optional filter function to control which chats are shown when browsing
          chat_filter = nil, -- function(chat_data) return boolean end
          -- Customize picker keymaps (optional)
          picker_keymaps = {
            rename = { n = "r", i = "<M-r>" },
            delete = { n = "d", i = "<M-d>" },
            duplicate = { n = "<C-y>", i = "<C-y>" },
          },
          ---Automatically generate titles for new chats
          auto_generate_title = true,
          title_generation_opts = {
            ---Adapter for generating titles (defaults to current chat adapter)
            adapter = "iflow", -- "copilot"
            ---Model for generating titles (defaults to current chat model)
            model = "qwen3-coder", -- "gpt-4o"
            ---Number of user prompts after which to refresh the title (0 to disable)
            refresh_every_n_prompts = 3, -- e.g., 3 to refresh after every 3rd user prompt
            ---Maximum number of times to refresh the title (default: 3)
            max_refreshes = 3,
            format_title = function(original_title)
              -- this can be a custom function that applies some custom
              -- formatting to the title.
              return original_title
            end,
          },
          ---On exiting and entering neovim, loads the last chat on opening chat
          continue_last_chat = false,
          ---When chat is cleared with `gx` delete the chat from history
          delete_on_clearing_chat = false,
          ---Directory path to save the chats
          dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
          ---Enable detailed logging for history extension
          enable_logging = false,

          -- Summary system
          summary = {
            -- Keymap to generate summary for current chat (default: "gcs")
            create_summary_keymap = "gcs",
            -- Keymap to browse summaries (default: "gbs")
            browse_summaries_keymap = "gbs",

            generation_opts = {
              adapter = nil, -- defaults to current chat adapter
              model = nil, -- defaults to current chat model
              context_size = 90000, -- max tokens that the model supports
              include_references = true, -- include slash command content
              include_tool_outputs = true, -- include tool execution results
              system_prompt = nil, -- custom system prompt (string or function)
              format_summary = nil, -- custom function to format generated summary e.g to remove <think/> tags from summary
            },
          },

          -- Memory system (requires VectorCode CLI)
          -- memory = {
          --   -- Automatically index summaries when they are generated
          --   auto_create_memories_on_summary_generation = true,
          --   -- Path to the VectorCode executable
          --   vectorcode_exe = "vectorcode",
          --   -- Tool configuration
          --   tool_opts = {
          --     -- Default number of memories to retrieve
          --     default_num = 10,
          --   },
          --   -- Enable notifications for indexing progress
          --   notify = true,
          --   -- Index all existing memories on startup
          --   -- (requires VectorCode 0.6.12+ for efficient incremental indexing)
          --   index_on_startup = false,
          -- },
        },
      },
    },
  },
}
