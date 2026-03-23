# AuditScope CLI

A command-line tool for managing audit thoughts, notes, and findings. Designed for AI agents with self-describing JSON output.

## Installation

```bash
cd cli
go build -o auditscope .
```

## Usage

### Subject Management

```bash
# Create a new subject (Human-only, requires password)
auditscope subject new "My Audit Project" --password audit2024

# List all subjects
auditscope subject list

# Select an active subject
auditscope subject select <subject-id>

# Show active subject details
auditscope subject show

# Delete a subject (Human-only)
auditscope subject delete <subject-id> --password audit2024
```

### Node Management

```bash
# Create a new node
auditscope node new question --text "Is this function safe?" --file src/contract.sol --start-line 10 --end-line 20

# List nodes
auditscope node list
auditscope node list --type question
auditscope node list --file src/contract.sol

# Show node details
auditscope node show <node-id>

# Update a node
auditscope node update <node-id> --text "Updated text"

# Delete a node
auditscope node delete <node-id>

# Add code snippet to a node
auditscope node snippet add <node-id> --text "code snippet" --file src/contract.sol --start-line 10 --end-line 15

# Delete snippet from a node
auditscope node snippet delete <node-id> 1
```

### Edge/Link Management

```bash
# Create a link between nodes
auditscope edge link <from-id> <to-id> --relation supports

# List all edges
auditscope edge list

# Delete a link
auditscope edge unlink <from-id> <to-id>
```

### Summary Management

```bash
# Show executive summary
auditscope summary show

# Set executive summary
auditscope summary set "This is the summary text"

# Clear summary
auditscope summary clear
```

### Git Integration

```bash
# Show git context
auditscope git context

# Lock to a specific commit (Human-only)
auditscope git lock <commit-hash> --password audit2024

# Unlock commit
auditscope git unlock
```

### Report Generation

```bash
# Generate markdown report
auditscope report generate
```

### Auto-link (LLM)

```bash
# Auto-link nodes using LLM
auditscope autolink <node-id>
auditscope autolink --max-links 5 --min-confidence 0.5
```

Requires `OPENROUTER_API_KEY` environment variable.

## Output Format

All commands output JSON with the following structure:

```json
{
  "status": "success|error",
  "operation": "operation_name",
  "message": "Human-readable message",
  "data": { ... },
  "error": "Error message if failed",
  "hint": "Suggestion for next steps"
}
```

## Human-only Operations

The following operations require password authentication:

- `subject new` - Create new audit subject
- `subject delete` - Delete a subject
- `git lock` - Lock to a specific commit

Use `--password audit2024` to authenticate.

## Node Types

- Level 0: `note`, `evidence`, `insight`, `question`, `hypothesis`, `fact`, `assumption`, `invariant`
- Level 1: `finding`
- Level 2: `decision`, `risk`

## Relations

- `supports` - Source supports target
- `refutes` - Source refutes target
- `relates` - Source relates to target

## Ontology Rules

Links must be same-level or upward only:
- L0 → L0, L1, L2 ✓
- L1 → L1, L2 ✓
- L2 → L2 ✓
- L1 → L0 ✗

## Storage

Data is stored in `~/.local/share/auditscope/`:

```
auditscope/
├── subjects/          # Subject JSON files
├── reports/           # Generated reports
├── subjects.json      # Subject index
└── state.json         # Active subject state
```

## Integration with Neovim Plugin

The CLI shares the same storage format as the Neovim plugin. The Neovim plugin can be modified to read-only mode, displaying data created/modified by the CLI.

## Environment Variables

- `OPENROUTER_API_KEY` - API key for auto-link LLM feature