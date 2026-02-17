---
name: worktree-list
description: Display a professional status dashboard of all active worktrees.
---

## Helper Script

Run this script to see the dashboard:

```bash
.skills/worktree-list/scripts/wt-list.sh [options]
```

## Options

- `--size`: Show disk usage (slower).
- `--short`: Show names only.
- `--json`: For machine processing.

## Status Indicators

- `✓ clean`: No uncommitted changes.
- `✎ dirty`: Contains modified or untracked files.
- `↑ ahead`: Local commits not yet pushed.
- `↓ behind`: Remote changes not yet pulled.
- `★`: Default branch (main).

## Insights

- If a worktree is **dirty** (✎), remind the user to commit or stash.
- If a worktree is **merged** but still exists, suggest pruning.
