---
name: worktree-prune
description: Identify and clean up worktrees that are safe to remove (merged or stale).
---

## Helper Script

Run this script to identify candidates for removal:

```bash
.skills/worktree-prune/scripts/wt-candidates.sh
```

The script identifies:

- **Merged**: Branches already merged into the default branch.
- **Gone**: Branches that no longer exist on the remote repository.

## Workflow

1. **Find candidates**:
   Run `.skills/worktree-prune/scripts/wt-candidates.sh` to see what's safe to delete.

2. **Remove worktree**:
   Use the `worktree-remove` skill for the actual deletion.

3. **Cleanup references**:
   After removing physical folders, run `.skills/_shared/scripts/wt-prune.sh` to clean up git's internal metadata.
