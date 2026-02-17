# Repository Instructions

This repository uses a git worktree–based workflow managed by the **Worktree Kit**.

The repository root acts as a central manager. All actual development happens in subfolders created as git worktrees.

## Skill Routing

When the user asks to create a worktree, choose the skill based on what they provide:

| User provides              | Skill                 | Example                                               |
| -------------------------- | --------------------- | ----------------------------------------------------- |
| A ticket ID                | **worktree-add**      | "Work on ABC-1234", "Start ABC-1234"                  |
| A branch name              | **worktree-checkout** | "Create a worktree from main", "Checkout feature/foo" |
| "from \<branch\>" phrasing | **worktree-checkout** | "Create my first worktree from my main branch"        |
| Urgent/hotfix/emergency    | **worktree-hotfix**   | "Quick fix for production", "Hotfix login bug"        |

**Key rule**: If the user mentions a specific branch name (`main`, `develop`, `feature/foo`, `origin/staging`), always route to **worktree-checkout** — even if they say "from \<branch\>". Only use **worktree-add** when the input is a ticket key with no branch name.

## Core Development Workflow

- **Finding/Starting Work**: When the user starts work on a ticket (e.g., "ABC-123"), use the **worktree-add** skill.
- **Dashboard**: For an overview of all worktrees, use **worktree-list** or run:
  `.skills/worktree-list/scripts/wt-list.sh` (Use `--size` to see disk usage).
- **History**: Track all worktree operations with:
  `.skills/_shared/scripts/wt-history.sh`
- **Syncing**: Refresh all reference branches and worktrees with:
  `.skills/worktree-sync/scripts/wt-sync.sh`
- **Inspection**:
  - Branch availability: `.skills/_shared/scripts/wt-branch-info.sh <branch> [--json]`
  - Change summary: `.skills/_shared/scripts/wt-diff.sh [folder] [--json]`
  - Merge status overview: `.skills/_shared/scripts/wt-merge-status.sh [--json]`
  - Worktree context info: `.skills/_shared/scripts/wt-switch.sh <folder> [--json]`
- **Cleaning**:
  - Prune build artifacts (`node_modules`, `target`, etc.): `.skills/_shared/scripts/wt-optimize.sh`
  - Clean merged branches: `.skills/_shared/scripts/wt-branch-cleanup.sh`
  - Prune orphaned git references: `.skills/_shared/scripts/wt-prune.sh`

## Professional UI Standard

All scripts follow a **Minimal Technical UI** standard:

- **ASCII-Technical Glyphs**: No emojis. We use glyphs like `✓` (success), `✎` (dirty), `↑`/`↓` (ahead/behind), `★` (default).
- **Perfect Alignment**: Columns are dynamically aligned for maximum readability.
- **Color Intelligent**: Colors help human scannability but are disabled when run by agents or in CI.

## Issue Tracker

The `issue_tracker` setting in `.worktreeconfig` → `[defaults].issue_tracker` tells agents which issue tracker to use for ticket lookups. Supported values: `linear`, `jira`, `shortcut`, `github`, `auto`.

- Read this setting before any ticket operation (fetch it via `parse-config.sh defaults.issue_tracker`).
- If set to a specific tracker: use the corresponding MCP tools or API (e.g., `linear` → Linear MCP, `jira` → Jira API, `github` → `gh` CLI).
- If unset or `auto`: auto-detect from available MCP tools, or ask the user.

## Git & Operational Rules

1. **Worktrees over Checkouts**: Always use `git worktree add` instead of `git checkout` or `git switch`.
2. **Protected Main**: Never commit directly to the default branch (usually `main`). Use worktrees for all changes.
3. **No Guessing**: Always fetch ticket status/details from the configured issue tracker before creating worktrees.
4. **Safety First**: Never delete remote branches (`origin`) unless explicitly requested with specific flags.
5. **Context**: Run all commands from the repository root.

## Troubleshooting

If the Worktree Kit seems broken or misconfigured:
`.skills/_shared/scripts/wt-diagnose.sh`
