# AuditScope (Neovim plugin) – Agent Guide

This repo is a Neovim plugin + CLI tool that provides an "AuditMind" system: capture audit thoughts (nodes), link them, visualize a graph, and track "glance" attention per line. The Lua layer is fully compatible with the CLI layer, sharing the same storage format.

## Architecture

### Two Layers
- **CLI Layer** (`cli/`): Go-based CLI tool for data management. Primary data interface.
- **Lua Layer** (`mind/`): Neovim plugin providing UI/frontend. Uses CLI for write operations.

### Data Flow
- **Reads**: Lua directly reads JSON files (performance)
- **Writes**: Lua calls CLI commands (compatibility guarantee)
- **Storage**: Shared at `~/.local/share/auditscope/`

## Quick Orientation
- Entry point: `mind/init.lua` exports `setup()` and wires commands, UI, and signs.
- Data layer: `mind/db.lua` reads/writes JSON, calls CLI for writes.
- CLI bridge: `mind/cli_bridge.lua` wraps all CLI commands.
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
  cli_path = "auditscope",  -- optional: path to CLI binary
  password = nil,           -- optional: pre-set password for human-only operations
})
```

Public functions exposed after `setup()`:
- `create_mind()` → creates new audit subject (requires password)
- `new_node(type)` → creates a node for the current selection/line
- `open_dashboard()` → opens the graph view
- `add_link()` → links nodes
- `delete_node()` / `modify_node()`
- `set_commit(commit)` / `unlock_commit()` / `select_commit()`
- `pin_node()` / `unpin_node()` / `toggle_pin()`
- `increment_glance()` / `decrement_glance()`
- `clean_glance()` / `toggle_show_glance()`

## User Commands (defined in `mind/init.lua`)
- `:AuditCreateMind` / `:AuditSubjectNew` → create new audit subject (requires password)
- `:AuditSubjectSelect` → select active subject
- `:AuditSubjectDelete` → delete a subject (requires password)
- `:AuditGenerateReport` → generate markdown report
- `:AuditSummary` → set executive summary
- `:AuditNote [type]` → create a note (interactive type selection if omitted)
- `:AuditLockCommit [hash]` → lock to a commit hash
- `:AuditUnlockCommit`
- `:AuditPin` / `:AuditUnpin`
- `:AuditAddSnippet` → attach a code snippet to an existing node
- `:AuditDeleteSnippet` → delete a code snippet from a node
- `:AuditToggleTrace` → toggle auto-trace glance counting
- `:AuditCleanGlance` → reset glance counts for current file
- `:AuditToggleShowGlance` → toggle glance bars rendering
- `:AuditAutoLink [node_id]` → auto-link nodes using LLM

## Storage Model

### Storage Location
```
~/.local/share/auditscope/
├── subjects/           # Subject JSON files
├── reports/            # Generated reports
├── subjects.json       # Subject index
└── state.json          # Active subject state
```

### Data Schema

**Subject** (`subjects/<id>.json`):
```json
{
  "subject": {
    "id": "abc123",
    "title": "My Audit",
    "status": "active",
    "scope": "",
    "summary": "Executive summary...",
    "repo_root": "/path/to/repo",
    "created_at": 1234567890,
    "updated_at": 1234567890
  },
  "nodes": [...],
  "edges": [...],
  "glance": {...}
}
```

**Node**:
```json
{
  "id": "xyz789",
  "type": "question|hypothesis|finding|...",
  "title": "Node title",
  "description": "Optional detailed description",
  "file": "/path/to/file.sol",
  "start_line": 10,
  "end_line": 20,
  "code_snippet": "legacy field",
  "codesnippets": [{ "text": "...", "file": "...", "start_line": 1, "end_line": 5, ... }],
  "repo_root": "/path/to/repo",
  "repo_name": "project",
  "commit": "abc1234",
  "timestamp": 1234567890
}
```

**Edge**:
```json
{ "from": "node_id_1", "to": "node_id_2", "relation": "supports|refutes|relates" }
```

**Glance**:
```json
{ "/path/to/file": { "10": 5, "11": 3 } }
```

### Node Types (Ontology)
- **Level 0**: `note`, `evidence`, `insight`, `question`, `hypothesis`, `fact`, `assumption`, `invariant`
- **Level 1**: `finding`
- **Level 2**: `decision`, `risk`

Links must be same-level or upward only (L0 → L0/L1/L2, L1 → L1/L2, L2 → L2).

## CLI Integration

### Human-Only Operations (require password)
- `subject new` - Create new audit subject
- `subject select` - Select an active subject
- `subject delete` - Delete a subject
- `git lock` - Lock to a specific commit

Default password: `maidsamaviria` (defined in `cli/internal/db/db.go`)

### CLI Commands
```bash
# Subject management
auditscope subject new "My Audit" --password <pwd>
auditscope subject list
auditscope subject select <id>
auditscope subject show
auditscope subject delete <id> --password <pwd>

# Node management
auditscope node new question --title "Is this safe?" --file src/contract.sol --start-line 10
auditscope node list
auditscope node show <id>
auditscope node update <id> --title "New title"
auditscope node delete <id>
auditscope node snippet add <id> --text "code..."
auditscope node snippet delete <id> <index>

# Edge management
auditscope edge link <from_id> <to_id> --relation supports
auditscope edge list
auditscope edge unlink <from_id> <to_id>

# Summary
auditscope summary show
auditscope summary set "Summary text"
auditscope summary clear

# Git
auditscope git context
auditscope git lock <commit> --password <pwd>
auditscope git unlock

# Report
auditscope report generate

# Auto-link (requires OPENROUTER_API_KEY)
auditscope autolink <node_id>
```

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
- `auditscope` CLI binary (for write operations)

## File Map
- `mind/init.lua` – plugin entry, commands, autocmds, public API
- `mind/db.lua` – persistence, project/commit context, CRUD
- `mind/cli_bridge.lua` – CLI command wrappers
- `mind/ui.lua` – popup UI, graph tree, glance tracking, pin logic
- `mind/sign.lua` – extmark signs and highlight setup
- `mind/report.lua` – markdown report generation
- `mind/auto_link.lua` – LLM-based auto-linking
- `mind/ontology.lua` – node types and link rules
- `mind/subject_picker.lua` – subject selection UI
- `cli/` – Go-based CLI tool

## Migration from Old Format

If you have data with `node.text` field, it will be automatically migrated to `node.title` on load. The migration happens in `db.load()`.

## Known Issues
- Human-only operations require interactive password input in Neovim.
- CLI must be in PATH or configured via `cli_path` option.