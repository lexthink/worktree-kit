---
name: worktree-sync
description: Update reference worktrees with the latest changes from the remote repository.
---

## Helper Script

Run this script to sync branches (defaults to main):

```bash
.skills/worktree-sync/scripts/wt-sync.sh [branch1 folder2 ...]
```

## Features

- **Fetch**: Updates all remote references first.
- **Auto-Detect**: Accepts both branch names and folder names.
- **Safety**: Skips worktrees with uncommitted changes.
- **Clean**: Uses `--ff-only` to ensure no merge commits are created.

## Workflow

1. Run the script for desired targets: `.skills/worktree-sync/scripts/wt-sync.sh MER-6857`
2. Review the results (Success ✓, Warning ⚠, Fail ✖).
