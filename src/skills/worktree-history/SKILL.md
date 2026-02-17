---
name: worktree-history
description: View and filter the operation history log for worktree actions.
metadata:
  short-description: "View audit log of worktree operations (create, remove, commit, etc.)"
---

## What the user will say

- "Show me the history"
- "What operations have been done?"
- "Show me operations for ABC-1234"
- "What did I do today?"

## Non-negotiable rules

1. The history is read from `.worktree-history.log` in the repository root.
2. If the log file doesn't exist, report "No history log found."
3. Support filtering by worktree name.
4. Default to showing the last 20 entries unless specified otherwise.

## Recommended Approach

Use the helper script `scripts/wt-history.sh` for consistent history viewing:

```bash
# View last 50 operations
scripts/wt-history.sh

# View last 100 operations
scripts/wt-history.sh -n 100

# Filter by specific worktree
scripts/wt-history.sh --worktree ABC-1234

# JSON output
scripts/wt-history.sh --json
```

## Manual Implementation (if script unavailable)

### Step 1 — Locate the Log File

1. Find the repository root: Run `git rev-parse --show-toplevel`
2. Check if `.worktree-history.log` exists in the root.
3. If missing, report: "No history available."

### Step 2 — Parse Options

Support these filters:

- `-n N`: Show last N entries (default: 20)
- `--worktree NAME`: Filter by worktree name
- `--json`: Output as JSON array

### Step 3 — Read and Filter

1. Read the log file from the end (tail).
2. Each line format: `[TIMESTAMP] [USER] OPERATION worktree=NAME branch=BRANCH details="..."`
3. Apply filters:
   - If `--worktree` specified: only show lines with `worktree=NAME`
4. Limit to `-n` count.

### Step 4 — Display

**Table format** (default):

```text
TIMESTAMP          USER     OPERATION       WORKTREE  BRANCH           DETAILS
2026-01-30 10:30  alex     worktree-add    ABC-123   feature/auth     Created from ticket
2026-01-30 11:15  alex     commit          ABC-123   feature/auth     feat: add login
```

**JSON format** (with `--json`):

```json
[
  {
    "timestamp": "2026-01-30 10:30:15",
    "user": "alex",
    "operation": "worktree-add",
    "worktree": "ABC-123",
    "branch": "feature/auth",
    "details": "Created from ticket"
  }
]
```

## Required output

Always show:

- The formatted results

## Safety constraints

- Read-only operation, no modifications to any files.
- Handle missing or corrupted log entries gracefully.
