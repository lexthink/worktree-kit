---
name: worktree-checkout
description: Checkout an existing branch (local or remote) into a new git worktree folder.
---

## What the user will say

- "Checkout branch 'BRANCH_NAME' as 'FOLDER_NAME'"
- "Add worktree for remote branch 'REMOTE_BRANCH'"
- "Download branch 'develop' to a worktree"
- "Create a worktree for the existing branch 'testing-fix'"
- "Work on the remote branch 'origin/staging'"
- "Checkout 'main' into a new worktree to test something"
- "Use the branch that already exists in remote: origin/feature/foo"
- "The branch already exists locally: feature/bar"
- "Add a worktree for the existing branch feature/baz"
- "Create a worktree from main"
- "Create my first worktree from my main branch"
- "I want a worktree from develop"

## Applicability guardrails

- Use this skill when the user provides a branch name (local or remote).
- If the user provides only a ticket key (e.g., `ABC-1234`) or asks to start work on a ticket, use `worktree-add` instead.

## Intent detection (quick rules)

- If the user mentions a specific branch name (e.g., `feature/foo`, `origin/staging`, `main`), use this skill.
- If the user says "from \<branch\>" (e.g., "from main", "from develop"), the branch name is the target — use this skill.
- If the user says the branch already exists (local or remote), use this skill.
- If the user only mentions a ticket key without a branch, use `worktree-add`.

## Step 1 — Resolve Branch and Folder Name

- Identify the target branch name (e.g., `origin/feature/abc-123`).
- Identify the desired folder name (e.g., `ABC-123`).
- **Normalization Rule**: If the branch name contains slashes `/`, replace them with dashes `-` for the folder name (e.g., `feature/abc-123` -> `feature-abc-123`) to avoid creating nested directories.
- If the user does not specify a folder name, use the normalized branch name as the folder name.
- If the branch starts with `origin/`, strip it for the local tracking branch name unless a specific local name is given.

## Step 2 — Create the worktree

Run the helper script from the repository root:

```bash
.skills/_shared/scripts/wt-create.sh \
  --branch <LOCAL_BRANCH> \
  --folder <FOLDER_NAME>
```

> **Important**: Do NOT pass `--base` when checking out an existing branch. The `--base` flag is only for creating new branches (used by `worktree-add`). The script automatically detects whether the branch exists locally or on remote and handles it correctly.

The script handles everything automatically:

- Checks for existing worktrees (reuses if found)
- Fetches from remote if branch only exists on origin
- Creates the worktree with correct git commands
- Sets upstream tracking
- Copies files from `.worktreeconfig` `[copy]` rules
- Runs `[hooks].post_create` commands
- Logs the operation to `.worktree-history.log`
- Prints the `WORKTREE READY` summary

> **Tip**: If you encounter "exclusive access" or ".git/index.lock" errors, it's usually transient lock contention. Wait 1 second and retry.

## Required output

The script prints a `WORKTREE READY` block automatically. If it fails, report the error to the user.
