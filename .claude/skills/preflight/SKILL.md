---
name: preflight
description: Run a full pre-PR checklist — branch validation, clean tree, linting, tests, push status. Reports a pass/fail summary and suggests next action.
metadata:
  short-description: "Branch + clean tree + shellcheck + BATS + push status → checklist"
---

## What the user will say

- "Run preflight checks"
- "/preflight"
- "Am I ready for a PR?"
- "Check everything before PR"

## Non-negotiable rules

1. Run ALL checks — never stop on first failure.
2. Report a clear pass/fail checklist at the end.
3. Suggest next action: `/pr` if all pass, or what to fix if not.

## Checks

Run each check and collect results:

### 1. Branch check

Not on `main`:

```bash
git rev-parse --abbrev-ref HEAD
```

### 2. Clean tree

No uncommitted changes:

```bash
git status --porcelain
```

### 3. Shellcheck

Lint all scripts:

```bash
shellcheck setup.sh install.sh
find src/skills -name "*.sh" -type f -exec shellcheck {} \;
```

### 4. Tests

Run full BATS suite:

```bash
bats tests/*.bats
```

### 5. Push status

Branch is pushed and up to date with remote:

```bash
git status -sb
```

### 6. Commits ahead

Has commits ahead of main:

```bash
git log main..HEAD --oneline
```

## Output format

Show a checklist:

```text
Preflight Check
  [pass] Not on main (on add-release-action)
  [pass] Working tree clean
  [pass] Shellcheck passed (25 scripts)
  [pass] Tests passed (130 tests)
  [pass] Branch pushed to remote
  [pass] 3 commits ahead of main

Ready for PR! Run /pr to create it.
```

Or if something fails:

```text
Preflight Check
  [pass] Not on main (on fix-broken-sync)
  [FAIL] Working tree has 2 uncommitted files
  [pass] Shellcheck passed (25 scripts)
  [FAIL] Tests: 2 failures
  [pass] Branch pushed to remote
  [pass] 3 commits ahead of main

Not ready — fix the issues above first.
```
