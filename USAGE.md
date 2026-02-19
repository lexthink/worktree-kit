# How to Use Worktree Kit

This guide walks you through the setup of a project using the **Worktree Kit** workflow.

---

## 🛠 Manual Setup Step-by-Step

Instead of a traditional clone, we use a `bare` clone to keep the root directory clean and only use it as a manager.

```bash
# 1. Create a folder for your project
mkdir your-repo && cd your-repo

# 2. Clone the repository as a bare repo into a folder named '.git'
git clone --bare git@github.com:your-org/your-repo.git .git
```

## 2. Install / Update the Kit

### One-Line Install (recommended)

No need to clone the kit locally:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lexthink/worktree-kit/main/install.sh) \
  git@github.com:your-org/your-repo.git ~/dev/your-repo
```

### Manual Install

If you prefer, clone the kit first:

```bash
git clone git@github.com:lexthink/worktree-kit.git

# Default: installs for Claude Code
./worktree-kit/setup.sh ~/dev/your-repo

# Install for a different agent
./worktree-kit/setup.sh --agent codex ~/dev/your-repo
```

The script will:

1. Copy skills into the agent directory (e.g. `.claude/skills/`)
2. Copy instructions file (e.g. `CLAUDE.md`)
3. Copy default `.worktreeconfig` if missing

## 3. Daily Workflow with AI Agent

Once installed, you can interact with your agent to manage your tickets. The agent will use skills which include helper scripts for consistent, repeatable operations.

### Helper Scripts

You can also run scripts directly from the terminal:

```bash
# Create a worktree with full env setup
.claude/skills/_shared/scripts/wt-create.sh --branch feature/auth --folder ABC-1234

# Remove a worktree safely
.claude/skills/_shared/scripts/wt-remove.sh ABC-1234 --delete-branch

# List worktrees (from repo root)
.claude/skills/worktree-list/scripts/wt-list.sh

# Check specific worktree context
.claude/skills/_shared/scripts/wt-switch.sh ABC-1234

# Check branch availability (local/remote)
.claude/skills/_shared/scripts/wt-branch-info.sh feature/auth

# Summary of changes in a worktree
.claude/skills/_shared/scripts/wt-diff.sh ABC-1234

# Merge status of all branches vs main
.claude/skills/_shared/scripts/wt-merge-status.sh

# Sync branches
.claude/skills/worktree-sync/scripts/wt-sync.sh main

# Find worktrees to remove
.claude/skills/worktree-prune/scripts/wt-candidates.sh

# Generate PR link
.claude/skills/worktree-push/scripts/wt-pr-link.sh feature-branch
```

See [skills/\_shared/scripts/README.md](./skills/_shared/scripts/README.md) for full documentation.

### Step A: Start a Ticket

Ask your agent:

> _"Work on ABC-1234"_

**What happens?**

1. The agent fetches the ticket details from your issue tracker.
2. It detects the branch (from an existing PR or the issue tracker).
3. It creates a new folder named `ABC-1234/`.
4. It copies files/directories from `.worktreeconfig` (if present).

---

## .worktreeconfig (Optional)

Create a file named `.worktreeconfig` in the repository root to control what gets copied into new worktrees and define defaults.

Example:

```ini
# .worktreeconfig

[copy]
include = .env.example *.md node_modules
exclude = node_modules/.cache

[hooks]
post-create = npm install && cp .env.example .env
pre-commit = npm run lint && npm test

[defaults]
editor = cursor
issue-tracker = linear

[worktrees]
directory = .
default-branch = main
```

Notes:

- `[copy]` supports `include` and `exclude`, each accepting a space-separated list.
- `include` accepts files, directories, or file patterns. Directories are detected automatically and copied recursively; file patterns are matched via `find -name` (max depth 2).
- `exclude` accepts **exact paths** relative to the repo root (e.g. `node_modules/.cache`, `mydir/secret.json`). Only the specified path is excluded — a bare filename like `secret.json` only excludes that file at the root, not inside subdirectories.
- Keys use kebab-case (e.g. `default-branch`, `post-create`).
- Unknown keys are ignored.
- `worktrees.directory` supports absolute, `~`, or repo-relative paths.
- Defaults when `.worktreeconfig` is missing: `worktrees.directory` = `.` (repo root), `worktrees.default-branch` = `main`.
- The default branch is used by `worktree-list`, `worktree-prune`, and `worktree-sync` as the reference branch.
- `[hooks]` commands run via `eval`; chain multiple commands with `&&` (e.g. `pre-commit = npm run lint && npm test`).
- `hooks.pre-commit` runs automatically before every commit via `worktree-commit`. If it fails, the commit is aborted.
- `defaults.editor` is a preference for agents when explicitly requested; scripts do not open editors automatically.
- `defaults.issue-tracker` tells agents which tracker to use for ticket lookups (`linear`, `jira`, `shortcut`, `github`, `auto`). Defaults to `auto`.

### Step B: Development

```bash
cd ABC-1234
# Do your work here...
```

### Step C: Committing Changes

Instead of manual commits, ask the agent:

> _"Commit my changes"_

**What happens?**

- The agent analyzes your code and generates a standardized message like:
  `[ABC-1234] feat: description of changes`

### Step D: Cleanup

When your PR is merged and the branch deleted, ask the agent:

> _"Prune my worktrees"_

**What happens?**

- The agent identifies `ABC-1234` as finished and safely removes the folder and the local branch.

---

## 🛠 Manual & Special Worktrees

The kit is designed to be flexible. You don't always need a ticket to use worktrees.

### Creating a manual worktree

If you need a quick experiment or a hotfix without a ticket, you can:

- **Do it yourself**: `git worktree add my-experiment main`
- **Ask the agent**: _"Create a worktree named 'debug-auth' from the default branch"_
- **Ask the agent (Remote/Existing Branch)**: _"Add a worktree for branch 'origin/merge/abc-to-dev' as 'ABC-DEV'"_

### ⚡️ Rapid Hotfixes

When production breaks and you don't have time to browse your issue tracker, use the hotfix skill:

> _"I need a hotfix for the broken login button"_

**What happens?**

1. The agent fetches the latest `main`.
2. It creates a branch named `hotfix/login-button`.
3. It sets up a folder `hotfix-login-button/`.
4. It initializes the environment (copying `.env.example`, etc.) so you can start fixing immediately.

### Committing in manual worktrees

If you use the `worktree-commit` skill in a folder that doesn't look like a ticket (e.g., `debug-auth`), the agent will automatically:

1. Detect there is no Ticket ID.
2. Generate a standard commit message without the `[ID]` prefix.
3. Example: `feat: fix authentication race condition`

### 🔄 Context Switching

If you have multiple worktrees open, you can ask the agent to switch:

> _"Switch to ABC-123"_

**What happens?**

1. The agent changes its working directory to the target folder.
2. It gives you a summary of the state of that branch (uncommitted changes, last commit, and ticket status).
3. This is much faster than manually `cd`-ing and running `git status`.

---
