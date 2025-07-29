return {
  "nvimdev/dashboard-nvim",
  lazy = false, -- As https://github.com/nvimdev/dashboard-nvim/pull/450, dashboard-nvim shouldn't be lazy-loaded to properly handle stdin.
  opts = function()
    local logo = [[
    ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠀⠀⠠⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⡀⠀⠙⢶⣄⠀⠀⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢠⣶⣦⣤⣀⣀⣤⣤⣄⣀⠀⢀⣀⣴⠂⠀⠀⠀⠀⠀⠀⠀⠐⠉⠉⣉⣉⣽⣿⣿⣷⣾⣿⣷⣄⡸⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠿⠿⢿⣿⣿⣿⣭⣭⣿⣿⣿⣿⣟⣁⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠶⠤⠀⠀⢠⡾⢿⣿⣿⣿⣿⡿⠉⠀⠀⠀⠈⠙⢻⣿⣿⣿⡛⢻⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠋⠀⠀⠀⠉⠻⣿⣿⣿⣿⣦⡀⠀⠁⠀⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣦⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣿⣿⣿⣯⡙⢦⠀⠀⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠀⠀⠀⠙⠻⠿⠿⣿⣿⣿⣿⣶⣄⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⡄⠀⠀⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀⠀⠰⣄⠀⠀⠀⠀⠈⠛⢿⣿⡏⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⡝⡇⠀⠀⠹⡇⠙⢿⣿⣿⣿⣿⣿⣶⣦⣄⣀⣈⣳⣶⣤⣤⣄⣀⠈⠋⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⡇⠁⠀⠀⠀⠙⣠⠤⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡛⠻⣷⣄⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠈⢲⡄⠀⢀⡠⠔⠂⠀⠀⠀⠀⣸⣿⣿⣿⡿⢹⠇⠀⠀⠀⠀⠈⢀⣤⣶⣾⣿⣿⣿⣿⣿⣿⣿⡟⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣾⣧⣾⣿⣶⣶⣶⣤⣀⠀⠀⣿⣿⣿⣿⠇⠋⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⠟⠛⢿⣿⣿⣿⣿⡄⠀⠻⣿⡿⠿⠛⠛⠛⠛⠿⡿⠀⠀⠀⠀
⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿⣿⣿⣷⣮⡁⠀⣿⣿⣿⣿⠀⠀⠀⠀⠀⢠⠞⣻⣿⣿⣿⡿⠁⠀⠀⠈⣿⣿⣿⣿⣧⠀⠀⠀⢀⡀⠀⠀⠀⣴⠀⠀⠀⠀⠀⠀
⠀⠀⢠⡿⢹⣿⣿⡋⠀⠈⢻⣿⣿⣿⡟⠆⢻⣿⣿⣿⡇⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⡇⠀⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⣀⣭⣽⣶⣬⣿⡄⠀⠀⠀⠀⠀
⠀⠀⣰⣷⣿⣿⠿⠃⠀⠀⢸⣿⣿⣿⣿⡄⠘⣿⣿⣿⣿⣄⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀⣾⣿⣿⣿⣿⠀⠴⣻⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀
⠀⣴⣿⡿⠋⠀⠀⠀⠀⠀⣼⣿⣿⣿⢿⡇⠀⠘⣿⣿⣿⣿⣦⡀⠀⠀⢸⡟⢿⣿⣿⣿⣿⣧⡀⣰⣿⣿⣿⣿⡏⠀⣼⣿⣿⣿⠋⠀⠉⣿⣿⣌⣷⠀⠀⠀
⠀⠈⠛⠁⠀⠀⠀⠀⠀⢸⣿⣿⣿⡏⠘⠀⠀⠀⠈⢻⣿⣿⣿⣿⣷⣤⡀⠳⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠈⣿⣿⣿⣿⠀⠀⠈⠛⠻⢿⣿⣷⡄⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠉⠻⣿⣿⣿⣿⣿⣷⣶⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⣿⢿⣿⣿⣧⡀⠀⠀⠀⠀⠈⠿⠇⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣦⣀⠀⠀⠀⠀⠀⠀⠈⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⠀⠘⠌⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣶⣶⣤⣤⣤⣄⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⢀⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣟⣀⣤⣤⣴⣾⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⡀⠀⠀⢤⣬⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⡁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠠⠾⣿⣿⣿⣶⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣠⣶⣦⣄⡀⠀⠀⣶⢒⠲⣄
⣾⣥⣤⣼⣿⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣾⣵⣾⡿
    ]]

    logo = string.rep("\n", 8) .. logo .. "\n\n"

    local opts = {
      theme = "doom",
      hide = {
        -- this is taken care of by lualine
        -- enabling this messes up the actual laststatus setting after loading a file
        statusline = false,
      },

      config = {
        -- header = vim.split(logo, "\n"),
        header = (function()
          return vim.split(logo, "\n")
        end)(),
        -- stylua: ignore
        center = {
          -- { action = 'lua LazyVim.pick()()',                           desc = " Find File",       icon = " ", key = "f" },
          -- { action = "ene | startinsert",                              desc = " New File",        icon = " ", key = "n" },
           -- {
           -- action = function ()
           -- end,
           -- desc = " 深潛進度黑匣 (神經探針協議)",
           -- icon = " ",  -- 使用 DNA 螺旋圖示
           -- key = "p"
           --  },
          { action = 'lua LazyVim.pick("oldfiles")()',                 desc = " 調閱歷史污染數據██（30日內）",    icon = " ", key = "r" },
          { action = 'lua require("persistence").select()',              desc = " 載入██廢墟數據（.session檔案）", icon = " ", key = "s" },
          { action = 'lua LazyVim.pick.config_files()()',              desc = " CONFIGURATION",          icon = " ", key = "c" },
          {
            action = function()
                require("noice").notify(
                  "// [SYNC協議] :: 神經檔案同步中...","info")
                vim.fn.jobstart({"sh", "-c", "~/.config/nvim/auto_commit.sh"}, {
                  on_exit = function(_, code)
                    if code ~= 0 then
                      require("noice").notify("// [SYNC協議] :: 神經檔案同步失敗", "error")
                    end
                    if code == 0 then
                      vim.schedule(function()
                        require("noice").notify("// [SYNC協議] :: 神經檔案同步完成", "info")
                      end)
                    end
                  end,
                })
            end,
            desc = " SYNC",
            icon = "󱋖 ",  -- Removed trailing space in code (keep icon's internal space if needed)
            key = "y"
          },
          {
            action = function()
              local original_dir = vim.fn.getcwd() -- Store original directory
              vim.fn.chdir(vim.fn.expand("~/audits/"))

              local function select_and_open(current_path)
                vim.ui.select(
                  vim.fn.split(vim.fn.system("ls -1F " .. vim.fn.escape(current_path, " ") .. " | grep '/' | sed 's/\\///'"), "\n"), -- Only show directories
                  {
                    prompt = "Select an audit folder:",
                    format_item = function(item)
                      return item
                    end,
                  },
                  function(choice)
                    if choice then
                      local new_path = current_path .. "/" .. choice
                      vim.fn.chdir(new_path)
                      -- Check if it's a git repository
                      if vim.fn.system("git -C " .. vim.fn.escape(new_path, " ") .. " rev-parse --is-inside-work-tree 2>/dev/null") == "true\n" then
                        require("telescope.builtin").find_files({
                            cwd = new_path,
                            find_command = { "git", "ls-files", "--", "*.sol" }
                        })
                      else
                        -- If not a git repo, recursively select from subdirectories
                        select_and_open(new_path)
                      end
                    else
                      -- If no choice, go back to original directory or previous level
                      vim.fn.chdir(original_dir) -- Or navigate up one level if implementing back
                    end
                  end
                )
              end

              select_and_open(vim.fn.getcwd()) -- Start the selection process from the current directory
            end,
            desc = " AUDIT",
            icon = " ",
            key = "a"
          },
          {
            action = function()
              require("telescope.builtin").colorscheme({
                enable_preview = true,  -- 启用即时预览
                previewer_width = 0.75  -- 预览窗口宽度占比
              })
            end,
            desc = " COLORSCHEME PREVIEW",
            icon = " ",               -- Nerd Font 的调色盘图标
            key = "t"
          },
          -- { action = "LazyExtras",                                     desc = " Lazy Extras",     icon = " ", key = "x" },
          -- { action = "Lazy",                                           desc = " Lazy",            icon = "󰒲 ", key = "l" },
        },

        footer = function()
          local messages = {
            "// [理性協議棧] :: 正在墮入深海...",
            "// [系統提示] :: 同步協議初始化中...",
            "// [臨界監測] :: 認知頻寬██▓▒░ 60%",
            "// [幽靈代碼] :: 正在讀取遺失的記憶模組",
            "// [斷言協議] :: 否定海床下的██訊號",
            "// [警告] :: 深度臨界值突破，執行熔斷程序",
            "// [冗餘備份] :: 正在固化████時間錨點",
            "// [熵過濾器] :: 正在溶解非必要情感記憶",
            "// [遞歸鏡像] :: 自指校驗失敗，第247次",
            "// [緩衝層] :: 接收█████████殘響...",
            "// [密文協議] :: 啟動二階段量子加密",
            "// [逆向工程] :: 嘗試重新解析███暗流",
            "// [最後防線] :: 心之壩體腐蝕率 89.7%",
          }
          return { messages[math.random(1, #messages)] }
        end,
      },
    }

    for _, button in ipairs(opts.config.center) do
      -- if button.desc then
      --   -- 使用 20% 的擾碼強度，保留主要可讀性
      --   button.desc = neural_scramble(button.desc, 0.2)
      --
      --   -- 故障概率追加系統錯誤碼(10% 機率)
      --   -- if math.random() < 0.1 then
      --   --   button.desc = button.desc .. " ERR:" .. tostring(math.random(0x9000, 0x9FFF))
      --   -- end
      -- end
      button.key_format = "      [%s]"
    end

    if vim.o.filetype == "lazy" then
      vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(vim.api.nvim_get_current_win()),
        once = true,
        callback = function()
          vim.schedule(function()
            vim.api.nvim_exec_autocmds("UIEnter", { group = "dashboard" })
          end)
        end,
      })
    end

    return opts
  end,
}
