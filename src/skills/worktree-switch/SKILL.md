---
name: worktree-switch
description: Fast context switching between worktrees. Changes the working directory and provides a status summary of the target worktree.
metadata:
  short-description: "Identify target worktree → Change directory → Report status & pending work"
---

## What the user will say

- "Switch to ABC-123"
- "Go back to the main branch"
- "Switch context to the login feature"

## Step 1 — Identify Target

1. Parse the target worktree name from the user's request (e.g., "ABC-123").
2. If multiple matches exist or the target is ambiguous, ask the user for clarification.
3. If the target worktree doesn't exist, suggest using `worktree-add`.

## Step 2 — Switch Directory

Change your current working directory to the target worktree's path.

## Step 3 — Report Context

Run the helper script to get a full context summary:

```bash
.skills/_shared/scripts/wt-switch.sh <FOLDER>
```

The script reports:

- Folder and path
- Branch name
- Git status (clean/dirty with change count)
- Sync status (ahead/behind remote)
- Last commit (hash, message, date)

If this is a ticket worktree (folder matches ticket pattern like `ABC-1234`), also fetch the ticket title and status from the configured issue tracker (`.worktreeconfig` → `[defaults].issue_tracker`) via MCP or API.

## Required output

The script prints a `CONTEXT SWITCHED` block automatically. If a ticket is detected, append:

```text
Ticket: [STATUS] - [TITLE]
```
