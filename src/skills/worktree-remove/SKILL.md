---
name: worktree-remove
description: Remove a specific git worktree folder and optionally its local branch.
metadata:
  short-description: "Specify folder → Safety check (uncommitted changes) → Remove worktree → (Optional) Delete branch"
---

## What the user will say

- "Remove worktree ABC-1234"
- "Delete the worktree I'm working on"
- "Stop working on ABC-1234 and delete the folder"

## Non-negotiable rules

1. This skill is LOCAL-ONLY.
2. NEVER run `git push --delete`.
3. You MUST check for uncommitted changes before removing.
4. If there are uncommitted changes, you MUST ask for confirmation (explicitly mentioning they will be lost).
5. Protection Rule: DO NOT allow removing the default-branch worktree unless specifically forced by the user.

## Step 1 — Identify the worktree

1. Identify the target folder name from the user's request.
2. If the user says "this worktree", determine the current directory name.

## Step 2 — Check for uncommitted changes

Run the helper script in check mode (without `--force`):

```bash
.skills/_shared/scripts/wt-remove.sh <FOLDER>
```

- If the script exits with code **2**, it means there are uncommitted changes.
  - Warn the user: "There are uncommitted changes in [FOLDER]. Deleting it will lose these changes."
  - Ask: "Are you sure you want to remove it?"
  - If the user says no, STOP.
  - If the user confirms, re-run with `--force`.

## Step 3 — Remove the worktree

Once confirmed (or if no uncommitted changes), run:

```bash
.skills/_shared/scripts/wt-remove.sh <FOLDER> [--force] [--delete-branch]
```

- Add `--force` if the user confirmed despite uncommitted changes, or explicitly asked to "force delete".
- Add `--delete-branch` if the user also wants to delete the local branch.
- If the user didn't mention the branch, ask: "Do you also want to delete the local branch?"

The script handles:

- Safety checks (uncommitted changes, default branch protection)
- `git worktree remove` (with `--force` if needed)
- Optional `git branch -d` (or `-D` with `--force`)
- Logging to `.worktree-history.log`
- Printing the `WORKTREE REMOVED` summary

## Required output

The script prints a `WORKTREE REMOVED` block automatically. If it fails, report the error to the user.
