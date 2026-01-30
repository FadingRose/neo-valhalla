# AuditScope (Neovim plugin) – Agent Guide

This repo is a small Neovim plugin that provides an "AuditMind" system: capture audit thoughts (nodes), link them, visualize a graph, and track "glance" attention per line. Everything is stored per git project + commit.

## Quick Orientation
- Entry point: `mind/init.lua` exports `setup()` and wires commands, UI, and signs.
- Data layer: `mind/db.lua` reads/writes JSON files under the git root.
- UI layer: `mind/ui.lua` handles popups, linking, dashboard tree, pin, and glance tracking.
- Sign layer: `mind/sign.lua` paints per-line virtual text signs for nodes.

## Setup + Public API
Module path is `custom_plugins.auditscope.mind`.

Example:
```lua
require("custom_plugins.auditscope.mind").setup({
  icons = { hypothesis = "?", insight = "!", fact = "*", question = "?" },
  auto_trace = false,
  show_glance = false,
})
```

Public functions exposed after `setup()`:
- `create_mind()` → initializes storage for current project/commit
- `new_node(type)` → creates a node for the current selection/line
- `open_dashboard()` → opens the graph view
- `add_link()` → links nodes
- `delete_node()` / `modify_node()`
- `set_commit(commit)` / `unlock_commit()` / `select_commit()`
- `pin_node()` / `unpin_node()` / `toggle_pin()`
- `increment_glance()` / `decrement_glance()`
- `clean_glance()` / `toggle_show_glance()`

## User Commands (defined in `mind/init.lua`)
- `:AuditCreateMind` → create/init session for current git commit
- `:AuditLockCommit [hash]` → lock to a commit hash (shortened to current short length)
- `:AuditUnlockCommit`
- `:AuditPin` / `:AuditUnpin`
- `:AuditToggleTrace` → toggle auto-trace glance counting
- `:AuditCleanGlance` → reset glance counts for current file
- `:AuditToggleShowGlance` → toggle glance bars rendering

## Storage Model
- Storage directory (note typo): `<git_root>/.auiditscope.mind/`
- Filename: `<ProjectName>_<CommitHash>.json`
- Schema:
  - `nodes`: `{ id, type, text, file, start_line, end_line, code_snippet, timestamp }`
  - `edges`: `{ from, to, relation }`
  - `glance`: `{ [file]: { [line_string]: count } }`

Commit selection:
- Default commit comes from `git rev-parse --short HEAD`.
- `locked_commit` overrides the current commit until unlocked.

## UI Behavior
- `create_node(type)` opens a popup and then asks to link.
- `link_node()` uses `vim.ui.select` for node + relation.
- Input popup keymaps:
  - `<C-s>` submit
  - `<Esc>` cancel
  - With node context: `<C-l>` link, `<C-d>` unlink
- Dashboard:
  - Popup with tree from `nui.tree`
  - Root nodes: `hypothesis` or `question`
  - `<Tab>` or `o` toggles expand/collapse
  - `<CR>` jumps to file/line

## Signs / Highlights
- Signs are extmarks with `virt_text` at end of line.
- Highlight groups: `AuditHypothesis`, `AuditInsight`, `AuditFact`, `AuditQuestion`
  - Derived by dimming Diagnostic highlight groups.
- Only active for nodes in the current file.

## Glance Tracking
- Auto-trace uses a 200ms debounce on `CursorMoved`.
- Glance bars are rendered as `virt_text` aligned to the right.
- Restored on buffer enter for `.sol` and `.rs` files.

## Dependencies
- `nvim-lua/plenary.nvim` (for `plenary.path`)
- `nui.nvim` (layout, popup, tree)

## Known Quirks / Footguns
- Storage directory name uses `.auiditscope.mind` (typo). Changing it needs migration.
- `M.config.file_path` exists but is not used in `db.lua`.
- `mind/db.lua` tries to `require("auditscope.mind.signs")` / `ui` (module path mismatch).
- Pin feature uses `pin_win`/`pinned_node` without proper module-level locals, so pin UI is likely broken.
- Several globals (`AUTO_TRACE_ENABLED`, `TRACE_TIMER`, `LAST_TRACE_POS`) are implicit in `ui.lua`.

## File Map
- `mind/init.lua` – plugin entry, commands, autocmds, public API
- `mind/db.lua` – persistence, project/commit context, CRUD
- `mind/ui.lua` – popup UI, graph tree, glance tracking, pin logic
- `mind/sign.lua` – extmark signs and highlight setup
