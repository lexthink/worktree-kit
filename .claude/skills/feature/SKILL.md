---
name: feature
description: Create a new branch from main. Checks out main, pulls latest, creates a descriptive branch, and pushes it.
metadata:
  short-description: "Pull latest main → create branch → push to remote"
---

## What the user will say

- "Create a branch for the sync feature"
- "/feature add-release-action"
- "/feature fix-broken-sync"
- "Start working on updating the readme"

## Non-negotiable rules

1. Always branch from the latest `main`.
2. Working tree should be clean before switching branches.
3. Branch names MUST be lowercase kebab-case.

## Step 1 — Validate state

Check for uncommitted changes:

```bash
git status --porcelain
```

If dirty, warn the user and ask whether to stash or abort.

## Step 2 — Update main

```bash
git checkout main
git pull origin main
```

## Step 3 — Determine branch name

Normalize the user's input to lowercase kebab-case:

| User input           | Result              |
| -------------------- | ------------------- |
| `add-release-action` | `add-release-action`|
| `fix broken sync`    | `fix-broken-sync`   |
| `Update README`      | `update-readme`     |
| `add Google Auth`    | `add-google-auth`   |

**Rules:** lowercase, hyphens between words, 3-5 descriptive words.

## Step 4 — Create and push

```bash
git checkout -b <branch-name>
git push -u origin <branch-name>
```

## Step 5 — Report

Tell the user:

- Branch `<branch-name>` created and pushed
- Ready to start working
