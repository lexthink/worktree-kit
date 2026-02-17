---
name: worktree-stash
description: Manage git stashes per worktree with automatic tagging and filtering.
metadata:
  short-description: "Save, list, apply, and manage stashes specific to each worktree"
---

## What the user will say

- "Stash my changes"
- "Save my work in progress"
- "Show me stashes for ABC-1234"
- "Apply the stash for this ticket"

## Non-negotiable rules

1. All stashes MUST be tagged with the worktree name: `[worktree:NAME]`
2. Always identify the current worktree from the directory name.
3. Support filtering stashes by worktree.
4. Preserve git stash functionality while adding worktree context.

## Recommended Approach

Use the helper script `scripts/wt-stash.sh` for worktree-aware stash management:

```bash
# Save changes for current worktree
scripts/wt-stash.sh save ABC-123 "WIP: authentication work"

# List all stashes
scripts/wt-stash.sh list

# List stashes for specific worktree
scripts/wt-stash.sh list ABC-123

# Pop latest stash for worktree
scripts/wt-stash.sh pop ABC-123

# Apply specific stash (by index)
scripts/wt-stash.sh apply ABC-123 0

# Show stash contents
scripts/wt-stash.sh show ABC-123

# Drop/delete a stash
scripts/wt-stash.sh drop ABC-123 0

# JSON output
scripts/wt-stash.sh list --json
```

## Manual Implementation (if script unavailable)

### Step 1 — Identify Context

1. Get current directory name to determine worktree name.
2. Verify it's a valid worktree: `git worktree list | grep $(pwd)`

### Step 2 — Commands

#### Save Stash

```bash
# Format: [worktree:NAME] user message
WORKTREE="ABC-123"
MESSAGE="WIP: authentication"
git stash push -m "[worktree:$WORKTREE] $MESSAGE"
```

#### List Stashes

```bash
# All stashes
git stash list

# Filter by worktree
git stash list | grep "\[worktree:ABC-123\]"
```

#### Pop Stash (latest for worktree)

```bash
# Find latest stash for worktree
STASH_INDEX=$(git stash list | grep -n "\[worktree:ABC-123\]" | head -1 | cut -d: -f1)
STASH_INDEX=$((STASH_INDEX - 1))  # Convert to 0-based
git stash pop stash@{$STASH_INDEX}
```

#### Apply Stash (specific index)

```bash
# Apply but keep in stash list
git stash apply stash@{0}
```

#### Show Stash Contents

```bash
# Show latest for worktree
STASH_INDEX=$(git stash list | grep -n "\[worktree:ABC-123\]" | head -1 | cut -d: -f1)
STASH_INDEX=$((STASH_INDEX - 1))
git stash show -p stash@{$STASH_INDEX}
```

#### Drop Stash

```bash
git stash drop stash@{0}
```

### Step 3 — Display Format

**List output:**

```text
Stashes for ABC-123:
  stash@{0}: [worktree:ABC-123] WIP: authentication
  stash@{2}: [worktree:ABC-123] Temporary changes
```

**JSON output:**

```json
[
  {
    "index": 0,
    "worktree": "ABC-123",
    "message": "WIP: authentication",
    "branch": "feature/auth",
    "timestamp": "2026-01-30 10:30"
  }
]
```

## Required output

For each operation, confirm:

- **Save**: "Stashed changes for ABC-123"
- **Pop**: "Applied and removed stash@{N} for ABC-123"
- **Apply**: "Applied stash@{N} for ABC-123 (kept in list)"
- **Drop**: "Deleted stash@{N} for ABC-123"
- **List**: Show count and formatted list

## Safety constraints

- Always confirm before dropping stashes.
- Warn if applying a stash would cause conflicts.
- Never mix stashes from different worktrees without user knowledge.
