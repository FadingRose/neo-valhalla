return {
  "nvim-lualine/lualine.nvim",
  config = function()
    require("lualine").setup({
      options = {
        theme = "auto",
        component_separators = "",
        section_separators = { left = "::", right = "::" },
        disabled_filetypes = { "snacks_picker_list", "dashboard" },
      },
      sections = {
        lualine_a = { { "mode", separator = { left = "::" }, right_padding = 2 } },
        lualine_b = { "filename", "branch" },
        lualine_c = {
          "%=", --[[ add your center compoentnts here in place of this comment ]]
          {
            function()
              return "// [理性協議棧] :: 正在墮入深海..."
            end,
            -- color = { fg = "#ff79c6", gui = "bold" }, -- Pink color for the glitchy text
          },
        },
        lualine_x = {},
        lualine_y = { "filetype", "progress" },
        lualine_z = {
          { "location", separator = { right = "::" }, left_padding = 2 },
        },
      },
      inactive_sections = {
        lualine_a = { "filename" },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
      },
      tabline = {},
      extensions = {},
    })
  end,
}
