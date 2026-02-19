# Shared Scripts

Helper scripts used by multiple skills in the Worktree Kit.

## Scripts

### parse-config.sh

Parses `.worktreeconfig` files and returns configuration values.

```bash
# Get a single value
./parse-config.sh worktrees.directory
./parse-config.sh worktrees.default-branch
./parse-config.sh defaults.editor

# Specify repo root
./parse-config.sh worktrees.directory --repo /path/to/repo
```

---

### copy-files.sh

Copies files and directories into a new worktree based on `.worktreeconfig` rules.

```bash
# Copy files to a target worktree
./copy-files.sh /path/to/worktree

# Preview what would be copied (no actual copy)
./copy-files.sh /path/to/worktree --dry-run

# Verbose output
./copy-files.sh /path/to/worktree --verbose

# Specify repo root
./copy-files.sh /path/to/worktree --repo /path/to/repo
```

**Configuration example (`.worktreeconfig`):**

```ini
[copy]
include = .env.example *.md .vscode
exclude = .vscode/settings.json
```

- `include` accepts a space-separated list of files, directories, or patterns. Directories are detected automatically and copied recursively. File patterns are matched via `find -name` with a max depth of 2 from the repo root.
- `exclude` accepts **exact paths** relative to the repo root (e.g. `mydir/file2.txt`). Only the specified path is excluded.

---

### wt-diagnose.sh

Diagnoses the health and configuration of the worktree-kit setup.

```bash
# Run diagnostic checks
./wt-diagnose.sh

# Verbose output with all details
./wt-diagnose.sh --verbose

# Specify repo root
./wt-diagnose.sh --repo /path/to/repo
```

**Checks performed:**

- ✓ Repository structure (is it bare?)
- ✓ `.worktreeconfig` validity
- ✓ Required dependencies (git)
- ✓ Skills installation
- ✓ File permissions and access
- ✓ Git configuration and remotes
- ✓ Active worktrees status

---

### wt-run-hooks.sh

Executes hooks defined in `.worktreeconfig` (post-create, pre-commit).

```bash
# Run post-create hooks for a worktree
./wt-run-hooks.sh post-create /path/to/worktree

# Run pre-commit hooks (e.g., tests, linting)
./wt-run-hooks.sh pre-commit

# Dry-run to see what would be executed
./wt-run-hooks.sh post-create /path/to/worktree --dry-run
```

**Configuration example:**

```ini
[hooks]
post-create = npm install && npm run build
pre-commit = npm run lint && npm test
```

---

## Supported Configuration Keys

| Key                        | Default   | Description                                                                       |
| -------------------------- | --------- | --------------------------------------------------------------------------------- |
| `worktrees.directory`      | repo root | Directory where worktrees are created                                             |
| `worktrees.default-branch` | `main`    | Default branch name                                                               |
| `defaults.editor`          | (none)    | Editor preference for agents when explicitly requested (not automatic)            |
| `defaults.issue-tracker`   | `auto`    | Issue tracker for ticket lookups (`linear`, `jira`, `shortcut`, `github`, `auto`) |
| `hooks.post-create`        | (none)    | Commands to run after creating a worktree (supports `&&` chaining)                |
| `hooks.pre-commit`         | (none)    | Commands to run before commits (supports `&&` chaining)                           |
| `copy.include`             | (none)    | Space-separated files, directories, or patterns to copy                           |
| `copy.exclude`             | (none)    | Space-separated exact paths to exclude (relative to repo root)                    |

---

## Usage from Skills

Skills can use these scripts by referencing them relative to their location:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_SCRIPTS="$SCRIPT_DIR/../../_shared/scripts"

# Use wt-create.sh (create worktree with full setup)
"$SHARED_SCRIPTS/wt-create.sh" --branch feature/auth --folder ABC-1234 --base main

# Use wt-remove.sh (safe removal)
"$SHARED_SCRIPTS/wt-remove.sh" ABC-1234 --delete-branch

# Use wt-switch.sh (context info)
"$SHARED_SCRIPTS/wt-switch.sh" ABC-1234

# Use wt-branch-info.sh (branch availability)
"$SHARED_SCRIPTS/wt-branch-info.sh" feature/auth --json

# Use wt-diff.sh (change summary)
"$SHARED_SCRIPTS/wt-diff.sh" ABC-1234

# Use wt-merge-status.sh (merge status overview)
"$SHARED_SCRIPTS/wt-merge-status.sh" --json

# Use parse-config.sh
DEFAULT_BRANCH=$("$SHARED_SCRIPTS/parse-config.sh" worktrees.default-branch)

# Use copy-files.sh
"$SHARED_SCRIPTS/copy-files.sh" "$NEW_WORKTREE_PATH" --verbose

# Use wt-run-hooks.sh
"$SHARED_SCRIPTS/wt-run-hooks.sh" post-create "$WORKTREE_PATH"

# Use wt-diagnose.sh
"$SHARED_SCRIPTS/wt-diagnose.sh" --verbose

# Use wt-log.sh (log operations)
"$SHARED_SCRIPTS/wt-log.sh" worktree-add ABC-123 "Created from ticket"

# Use wt-history.sh (view history)
"$SHARED_SCRIPTS/wt-history.sh" -n 20
"$SHARED_SCRIPTS/wt-history.sh" --worktree ABC-123

# Use wt-stash.sh (manage stashes)
"$SHARED_SCRIPTS/wt-stash.sh" save ABC-123 "WIP authentication"
"$SHARED_SCRIPTS/wt-stash.sh" list ABC-123
"$SHARED_SCRIPTS/wt-stash.sh" pop ABC-123
```

---

### wt-log.sh

Logs worktree operations to `.worktree-history.log` for audit trail.

```bash
# Log an operation
./wt-log.sh worktree-add ABC-123 "Created from ticket"
./wt-log.sh worktree-remove XYZ-456 "Merged and cleaned up"
./wt-log.sh commit ABC-123 "feat: add authentication"

# Operations are automatically timestamped with user info
```

---

### wt-history.sh

View logged worktree operations history.

```bash
# View last 20 operations
./wt-history.sh

# View last 100 operations
./wt-history.sh -n 100

# Filter by worktree
./wt-history.sh --worktree ABC-123

# JSON output
./wt-history.sh --json
```

---

### wt-stash.sh

Manage git stashes per worktree with automatic tagging.

```bash
# List all stashes
./wt-stash.sh list

# List stashes for specific worktree
./wt-stash.sh list ABC-123

# Save current changes
./wt-stash.sh save ABC-123 "WIP: authentication work"

# Pop latest stash for worktree
./wt-stash.sh pop ABC-123

# Apply specific stash
./wt-stash.sh apply ABC-123 0

# Show stash content
./wt-stash.sh show ABC-123

# Drop stash
./wt-stash.sh drop ABC-123 0

# JSON output
./wt-stash.sh list --json
```

---

### wt-hotfix.sh

Create rapid hotfix worktrees from the default branch.

```bash
# Create hotfix from default branch
./wt-hotfix.sh critical-bug

# Create hotfix from specific base branch
./wt-hotfix.sh security-patch --base stable

# Specify repo location
./wt-hotfix.sh urgent-fix --repo /path/to/repo
```

---

### wt-create.sh

Create a git worktree with full environment setup. Unifies the creation logic used by `worktree-add` and `worktree-checkout` skills.

```bash
# Create worktree for a branch
./wt-create.sh --branch feature/auth --folder ABC-1234

# Create from a specific base branch
./wt-create.sh --branch feature/auth --folder ABC-1234 --base develop

# JSON output
./wt-create.sh --branch main --folder main-test --json

# Skip hooks and file copying
./wt-create.sh --branch feature/auth --folder ABC-1234 --no-hooks --no-copy
```

Handles: existing worktree reuse, branch detection (local/remote/new), upstream tracking, file copying, post-create hooks, and operation logging.

---

### wt-remove.sh

Safely remove a git worktree and optionally its local branch.

```bash
# Remove worktree (fails with exit code 2 if uncommitted changes)
./wt-remove.sh ABC-1234

# Force removal despite uncommitted changes
./wt-remove.sh ABC-1234 --force

# Also delete the local branch
./wt-remove.sh ABC-1234 --delete-branch

# Force remove + delete branch + JSON output
./wt-remove.sh ABC-1234 --force --delete-branch --json
```

Exit codes: 0 = success, 1 = error, 2 = uncommitted changes (needs `--force`).

---

### wt-switch.sh

Display context information for a worktree (status, branch, last commit, sync state).

```bash
# Show context for a worktree
./wt-switch.sh ABC-1234

# JSON output
./wt-switch.sh main --json
```

---

### wt-branch-info.sh

Check if a branch exists locally/remotely and show details.

```bash
# Check branch availability
./wt-branch-info.sh feature/auth

# JSON output
./wt-branch-info.sh main --json

# With explicit repo
./wt-branch-info.sh origin/develop --repo /path/to/repo
```

---

### wt-diff.sh

Show a summary of changes in a worktree (files changed, lines added/removed).

```bash
# Diff summary for a worktree
./wt-diff.sh ABC-1234

# Diff for current directory
./wt-diff.sh

# Staged changes only
./wt-diff.sh --staged

# JSON output
./wt-diff.sh ABC-1234 --json
```

---

### wt-merge-status.sh

Show merge status of all worktree branches against the default branch.

```bash
# Show merge status
./wt-merge-status.sh

# JSON output
./wt-merge-status.sh --json
```

---

### wt-fetch-all.sh

Fetch latest changes in all worktrees efficiently (in parallel).

```bash
# Fetch in all worktrees
./wt-fetch-all.sh

# Fetch with pruning
./wt-fetch-all.sh --prune

```

---

### wt-status-all.sh

Show concise status of all worktrees.

```bash
# Show status overview
./wt-status-all.sh

# JSON output
./wt-status-all.sh --json
```

---

### wt-branch-cleanup.sh

Clean up merged and stale branches.

```bash
# Preview what would be cleaned
./wt-branch-cleanup.sh --dry-run

# Clean local merged branches
./wt-branch-cleanup.sh

# Clean local + remote branches
./wt-branch-cleanup.sh --remote

```

---

## Testing

Tests for these scripts are in `tests/scripts.bats`. Run them with:

```bash
bats tests/scripts.bats
```

Or run all tests:

```bash
bats tests/*.bats
```
