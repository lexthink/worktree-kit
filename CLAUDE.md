# Worktree Kit — Development Guide

You are working on the **Worktree Kit** source repository.

## Project Structure

```text
src/                  # The product (installed into user projects)
  agents/             # Agent configs (claude-code.conf, codex.conf)
  skills/             # Worktree skills (worktree-add, worktree-list, etc.)
  AGENTS.md           # Product instructions (copied to user projects)
  .worktreeconfig     # Default config template

.claude/skills/       # Dev skills (for developing this kit)
tests/                # Test suite (bats + integration)
setup.sh              # Installer entry point
install.sh            # One-line remote installer
```

**Important**: The skills in `src/skills/` are the **product** — they get installed into user projects. Do NOT use them for development tasks. Use `.claude/skills/` for dev workflows.

## Workflow — GitHub Flow

This project follows [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow).

```text
main ─────●─────●─────●─────●──── (always deployable, always latest)
           \   /       \   /
          add-auth    fix-sync
```

### Fundamental rules

1. `main` is always in a deployable state.
2. **Every change** goes through a branch + Pull Request. Never commit directly to `main`.
3. Each merge to `main` is immediately available — no tags or releases.

### Code Changes (always via PR)

1. `/feature <name>` — Create a branch from main
2. Make changes and commit
3. `/test` — Run shellcheck + bats locally
4. `/preflight` — Full pre-PR checklist
5. `/pr` — Create a pull request
6. CI runs automatically on the PR
7. Review, address feedback, squash merge on GitHub

## Conventions

### Branches

Descriptive kebab-case names: `add-google-auth`, `fix-sync-bug`, `update-readme`.

**Rules:** lowercase, hyphens between words, 3-5 descriptive words.

### Commits

Clear, imperative messages: `fix sync on bare repos`, `add shellcheck to CI`.

**Rules:** imperative mood, max 72 characters, no trailing period.

### Pull Requests

- **Title**: short and descriptive (becomes the squash commit message on main)
- **Merge strategy**: Always **Squash and Merge**

### Code

- **Scripts**: Bash, shellcheck-compliant, POSIX-friendly
- **Tests**: BATS (Bash Automated Testing System)

## Testing

All scripts in `src/skills/` must pass:

- `shellcheck` linting (no warnings)
- BATS test suite (`tests/scripts.bats`, `tests/worktree_setup.bats`)

## Architecture Notes

- `setup.sh` reads agent configs from `src/agents/<name>.conf`
- Each config declares: `skills_dir`, `instructions_file`
- Skills are copied per-skill (preserving user's custom skills on update)
- `AGENTS.md` path placeholders (`.skills/`) are replaced with agent-specific paths during install
