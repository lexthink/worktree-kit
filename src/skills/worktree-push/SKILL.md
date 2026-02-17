---
name: worktree-push
description: Safely push changes and generate Pull Request links.
---

## Helper Script

Run this script to generate a PR creation link for your browser:

```bash
.skills/worktree-push/scripts/wt-pr-link.sh [branch_name]
```

## Features

- **Provider Support**: GitHub, GitLab, Bitbucket, Azure DevOps.
- **Auto-Base**: Correctly targets the default branch as the PR recipient.
- **Safety**: Validates that you aren't pushing directly to the protected main branch.

## Workflow

1. Commit your changes.
2. Push to remote: `git push -u origin HEAD`
3. Generate the PR link: `.skills/worktree-push/scripts/wt-pr-link.sh`
4. Review and open in your browser.
