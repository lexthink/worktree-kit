---
name: worktree-add
description: Create a git worktree for a ticket from your issue tracker (Linear, Jira, Shortcut, etc.). Folder name = ticket key (e.g. ABC-1234). If a PR already exists for the ticket, reuse its branch. Otherwise, obtain the branch name from the issue tracker and create the worktree.
metadata:
  short-description: "Issue ticket → existing PR branch or tracker branch → git worktree folder"
---

## What the user will say

- "Start a new feature for ABC-1234"
- "Create a worktree for ABC-1234"
- "Work on ABC-1234"

## Non-negotiable rules

1. Folder name MUST be the ticket key in uppercase (example: ABC-1234).
2. You MUST fetch the issue from the configured issue tracker via MCP or API (never guess).
3. You MUST detect whether a PR already exists for the ticket.
4. If a PR exists, you MUST use the PR branch.
5. If no PR exists, obtain the branch name from the issue tracker.
6. Do NOT rewrite or normalize branch names provided by the issue tracker or PRs.
7. Do NOT overwrite existing folders or worktrees.
8. **Normalization Rule**: Folder names MUST NOT contain slashes `/`. Always replace slashes with dashes `-` to keep the worktree directory flat (e.g. `merge/fix` -> `merge-fix`).
9. If the user provides an explicit branch name (e.g., `feature/foo`, `origin/staging`, `main`) or asks to add a worktree for an existing branch, do NOT use this skill. Use `worktree-checkout` instead.
10. Use this skill when the user intent is "new work from ticket": phrases like "new", "start", "create a branch", "from ticket", "new feature", or "work on ABC-1234" without any branch name.

## Intent detection (quick rules)

- If the user mentions only a ticket key (e.g., `ABC-1234`) without any branch name, use this skill.
- If the user intent is "start new work" from a ticket, use this skill.
- If the user provides a branch name (local or remote), use `worktree-checkout`.
- If the user says "from \<branch\>" (e.g., "from main", "from develop", "from my main branch"), the branch name is the target — use `worktree-checkout`, not this skill.

## Step 0 — Resolve issue tracker

Read the configured issue tracker:

```bash
.skills/_shared/scripts/parse-config.sh defaults.issue-tracker
```

Use the returned value (`linear`, `jira`, `shortcut`, `github`) to choose the correct MCP tools or API for ticket lookups. If unset or `auto`, auto-detect from available MCP tools or ask the user.

## Step 1 — Fetch issue and detect branch

After fetching the issue from the configured issue tracker, determine the branch name:

### A) Detect existing PR (highest priority)

Check for an existing PR using:

1. Git integration metadata on the issue (linked PRs — prefer open, most recent).
2. Explicit PR references in issue description/comments (GitHub PR links, `PR: <url>` patterns).

If a PR branch is found:

- `BRANCH_NAME` = PR branch name
- `BASE_BRANCH` = PR base branch

### B) Obtain branch name from issue tracker (only if no PR exists)

Priority order:

1. Explicit branch name field or tool provided by the issue tracker (use exactly as provided).
2. Branch name declared in issue content (`Branch: <name>`, `Git branch: <name>`).
3. Fallback: generate `feature/<lowercase-ticket>-<kebab-case-title>`.

Set `BASE_BRANCH` = `[worktrees].default-branch` from `.worktreeconfig`, otherwise `main`.

## Step 2 — Create the worktree

Run the helper script from the repository root:

```bash
.skills/_shared/scripts/wt-create.sh \
  --branch <BRANCH_NAME> \
  --folder <TICKET_KEY> \
  --base <BASE_BRANCH>
```

The script handles everything automatically:

- Checks for existing worktrees (reuses if found)
- Determines branch availability (local/remote/new)
- Creates the worktree with correct git commands
- Sets upstream tracking
- Copies files from `.worktreeconfig` `[copy]` rules
- Runs `[hooks].post-create` commands
- Logs the operation to `.worktree-history.log`
- Prints the `WORKTREE READY` summary

> **Tip**: If you encounter "exclusive access" or ".git/index.lock" errors, it's usually transient lock contention. Wait 1 second and retry.

## Safety constraints

- Never run destructive git commands (`reset`, `clean`, `worktree remove`) unless the user explicitly asks.
- Always fetch issue data from the configured issue tracker via MCP or API.
- Ask for approval if the execution policy requires it.
