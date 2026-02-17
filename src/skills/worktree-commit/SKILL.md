---
name: worktree-commit
description: Generate and execute a git commit with a standardized message that includes the ticket ID.
metadata:
  short-description: "Identify ticket ID → analyze changes → generate commit message → execute"
---

## What the user will say

- "Commit my changes"
- "Make a commit for this ticket"
- "Save my changes"

## Step 1 — Identify the Context

1. **Identify Ticket Key**:
   - Check if the current directory name matches a ticket pattern (e.g., ABC-1234).
   - If it matches, use it as `TICKET_KEY`.
   - If it DOES NOT match, mark `TICKET_KEY` as `null`.

2. **Verify Changes**: Check if there are staged changes.
   - Run: `git diff --cached --stat`
   - If no changes are staged, ask the user to stage them.

## Step 2 — Generate the Message

Analyze the staged changes and generate a message.

**Format**:

- If `TICKET_KEY` exists: `[TICKET_KEY] type: description`
- If no `TICKET_KEY`: `type: description`

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `chore`: Updating build tasks, package manager configs, etc.
- `docs`: Documentation only changes

**Example**:
`[ABC-1234] feat: implement user authentication flow`

## Step 3 — Pre-Commit Hooks (Validation)

Before executing the commit, check for custom validation hooks:

1. **Check Config**: Look for `[hooks]` -> `pre_commit` in the `.worktreeconfig` file (located in the repository root).
2. **Execute Hooks**:
   - If a `pre_commit` command is defined, execute it inside the current worktree folder.
   - Example: `npm test` or `flake8 .`
3. **Evaluate Result**:
   - If the command **fails** (non-zero exit code):
     - STOP the commit process.
     - Show the error output to the user.
     - Explain that the validation failed and the commit was cancelled.
   - If the command **succeeds**:
     - Proceed to Step 4.

## Step 4 — Summary & Execution

1. Show the proposed commit message to the user:
   "Proposed commit: [ABC-1234] feat: ..."
2. Upon confirmation (or if the execution policy allows), run:
   `git commit -m "[TICKET_KEY] type: description"`
3. **Log the operation**: Run `.skills/_shared/scripts/wt-log.sh commit <TICKET_KEY> "<type>: <description>"`

## Step 5 — Handle Git Hook Failures

If the commit command fails due to pre-commit hooks (e.g., linting errors):

1. **Analyze the output**: Check if the hooks modified files (e.g., auto-formatting).
2. **Auto-Correction**:
   - If files were modified by the hooks, run `git add .` to stage the fixes.
   - Retry the commit **one time** automatically.
3. **Manual Intervention**:
   - If the hooks failed without modifying files (e.g., syntax errors), stop.
   - Report the specific error to the user so they can fix it.

## Safety Rules

- NEVER commit without staged changes.
- NEVER include sensitive information from the `.env` file.
- Keep the first line of the commit message under 72 characters.
