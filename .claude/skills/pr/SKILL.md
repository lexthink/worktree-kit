---
name: pr
description: Create a GitHub pull request from the current branch. Auto-generates title and description from commits and changed files. Supports draft PRs.
metadata:
  short-description: "Gather commits → generate title/body → gh pr create"
---

## What the user will say

- "Create a PR"
- "/pr"
- "/pr --draft"
- "Open a pull request for this branch"

## Non-negotiable rules

1. Never create PRs from `main`.
2. All changes MUST be committed before creating a PR.
3. Branch MUST be pushed to remote.
4. Always show the title and description to the user before creating.
5. Target branch is always `main`.
6. Requires `gh` CLI to be installed and authenticated.

## Step 1 — Validate state

```bash
# Not on main
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# All changes committed
git status --porcelain
# Branch is pushed
git push
```

If on `main`, STOP. If uncommitted changes, warn. If not pushed, push first.

## Step 2 — Gather context

```bash
# Commits on this branch
git log main..HEAD --oneline

# Files changed
git diff main...HEAD --stat
```

## Step 3 — Generate PR content

**Title** — Short and descriptive (becomes the squash commit message on main):

- `Add release workflow`
- `Fix sync on bare repos`
- `Update installation guide`
- Keep under 70 characters

**Body** — Use this template:

```markdown
## Summary

Brief explanation of what this PR does and why.

## Test plan

How the changes were tested.
```

Fill in based on the commits and changed files.

## Step 4 — Confirm and create

Show the user the title and body. Upon confirmation:

```bash
gh pr create --title "<title>" --body "<body>" [--draft]
```

Use `--draft` if the user requested it.

## Step 5 — Report

Tell the user:

- PR URL
- PR number
- Whether it's a draft or ready for review
