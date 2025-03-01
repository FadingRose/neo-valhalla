-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.opt.linespace = 4

-- vim.o.guifont = "Intel One Mono:h14"
-- vim.o.guifont = "Intel One Mono,LXGW WenKai Mono:h9:h14"
vim.o.guifont = "Maple Mono NF CN:h13"
-- Neovide-specific settings
if vim.g.neovide then
  -- Enable smooth scrolling
  vim.g.neovide_scroll_animation_length = 0.05 -- Animation time in seconds
  vim.g.neovide_scroll_animation_far_lines = 1
  vim.g.neovide_cursor_animation_length = 0.1 -- Cursor animation time in seconds

  -- Smooth scrolling sensitivity
  vim.g.neovide_scroll_sensitivity = 3.0 -- Increase or decrease scrolling speed

  -- Cursor settings
  vim.g.neovide_cursor_vfx_mode = "pixiedust" -- Cursor effect (options: "railgun", "torpedo", "pixiedust", "sonicboom", "ripple", "wireframe")
  vim.g.neovide_cursor_vfx_opacity = 200.0 -- Cursor effect opacity
  vim.g.neovide_cursor_vfx_particle_density = 10.0 -- Particle density for cursor effect
  vim.g.neovide_cursor_vfx_particle_lifetime = 1.2 -- Particle lifetime for cursor effect
  vim.g.neovide_cursor_animate_in_insert_mode = true

  -- Performance settings
  vim.g.neovide_refresh_rate = 150 -- Refresh rate (higher values for smoother animation)

  vim.g.neovide_hide_mouse_when_typing = true -- Hide mouse cursor when typing
end

vim.o.autochdir = true

vim.o.background = "dark"
-- vim.cmd.colorscheme("oxocarbon")
vim.cmd.colorscheme("duskfox")
