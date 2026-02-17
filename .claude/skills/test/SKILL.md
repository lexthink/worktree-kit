---
name: test
description: Run the project's test suite locally (shellcheck linting + BATS tests), matching what CI does. Supports running everything, a single test file, or only linting.
metadata:
  short-description: "Shellcheck all scripts → BATS test suite → report results"
---

## What the user will say

- "Run the tests"
- "/test"
- "/test scripts.bats"
- "/test shellcheck"

## Non-negotiable rules

1. Always run from the repository root.
2. Report failures clearly with file and line numbers.
3. If any check fails, report non-zero exit status.
4. Match CI behavior exactly (same commands as `.github/workflows/ci.yaml`).

## Full run (default: `/test`)

### Shellcheck

```bash
shellcheck setup.sh install.sh
find src/skills -name "*.sh" -type f -exec shellcheck {} \;
```

### BATS

```bash
bats tests/*.bats
```

Report: total tests, passed, failed, and any failure details.

## Single file: `/test <filename>`

```bash
bats tests/<filename>
```

If the filename doesn't end in `.bats`, append it.

## Shellcheck only: `/test shellcheck`

```bash
shellcheck setup.sh install.sh
find src/skills -name "*.sh" -type f -exec shellcheck {} \;
```

Report: number of scripts checked and any warnings/errors.

## Output format

```text
Test Results
  Shellcheck:  25 scripts checked, 0 warnings
  BATS:        130 tests, 130 passed, 0 failed

All checks passed.
```

Or on failure:

```text
Test Results
  Shellcheck:  25 scripts checked, 2 warnings
    src/skills/_shared/scripts/wt-create.sh:42: SC2086
  BATS:        130 tests, 128 passed, 2 failed
    FAIL: wt-list.sh lists worktrees in table format (scripts.bats:114)

Some checks failed.
```
