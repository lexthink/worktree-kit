---
name: worktree-hotfix
description: Create a rapid git worktree for urgent fixes. Automatically branches from the default branch (usually main) and sets up a dedicated folder.
metadata:
  short-description: "Emergency fix → new branch from main → git worktree folder"
---

## What the user will say

- "I need a hotfix for the login bug"
- "Create an emergency worktree for ABC-1234"
- "Quick fix for production"

## Non-negotiable rules

1. The BASE_BRANCH MUST be the default branch (resolved from `.worktreeconfig` → `[worktrees].default-branch`, fallback to `main`).
2. You MUST fetch the latest changes from origin for the BASE_BRANCH before branching.
3. Folder name should be descriptive (e.g., `hotfix-login-bug` or `ABC-1234-fix`).
4. If a ticket ID is provided, use it in the branch name and folder name.

## Step 1 — Identification

1. **Identify the Issue**:
   - If the user provides a ticket ID (e.g., ABC-1234), fetch the ticket from the configured issue tracker (`.worktreeconfig` → `[defaults].issue-tracker`) via MCP or API to get the title.
   - If no ticket is provided, ask for a short description if the user hasn't given one (e.g., "login-bug").

2. **Resolve Names**:
   - DESCRIPTION = A kebab-case version of the ticket title or user description.

## Step 2 — Create the hotfix worktree

Run the helper script from the repository root:

```bash
.skills/_shared/scripts/wt-hotfix.sh <DESCRIPTION> [--base <BRANCH>]
```

The script handles everything automatically:

- Resolves the default branch from `.worktreeconfig`
- Fetches latest from remote
- Creates folder `hotfix-<DESCRIPTION>` with branch `hotfix/<DESCRIPTION>`
- Delegates to `wt-create.sh` for worktree creation, upstream tracking, file copying, hooks, and logging
- Prints the `WORKTREE READY` summary

## Required output

The script prints a `WORKTREE READY` block automatically. If it fails, report the error to the user.

## Safety constraints

- Ensure the folder does not already exist.
- If the branch already exists locally, ask the user if they want to reuse it or use a different name.
- Always fetch latest to avoid stale base branches.
