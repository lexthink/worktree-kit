---
name: worktree-status
description: Detailed inspection of a specific worktree without switching to it.
---

## Helper Script

Run this script for a deep-dive on a specific worktree:

```bash
.skills/worktree-status/scripts/wt-inspect.sh <folder_name|path>
```

## Features

- **Git Status**: Detailed staged, unstaged, and untracked report.
- **Sync State**: Accurate ahead/behind counts against remote.
- **Audit**: Last commit date and author.
- **History**: Most recent 5 commits.

## Workflow

1. Identify the worktree: `.skills/worktree-list/scripts/wt-list.sh`
2. Inspect it: `.skills/worktree-status/scripts/wt-inspect.sh MER-6857`
