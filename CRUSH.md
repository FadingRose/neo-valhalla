# Crush Guide for nvim-config

This file provides guidelines for working with this Neovim configuration.

## Commands

- **Format code:** `stylua .`

## Code Style

- **Formatting:** Indent with 2 spaces. Keep lines under 120 characters.
- **Naming:** Use `snake_case` for filenames and variables.
- **Keymaps:** Custom keymaps are defined in `lua/config/keymaps.lua`.
- **Plugins:** Plugins are managed by `lazy.nvim`. Configurations are in `lua/plugins/`.
- **LSP:** LSP settings are in `lua/config/lsp.lua`.

## Project Structure

- `init.lua`: Main entry point.
- `lua/`: All Lua configuration files.
- `lua/config/`: Core Neovim settings.
- `lua/plugins/`: Plugin configurations.
- `lua/custom_plugins/`: Custom plugins.
