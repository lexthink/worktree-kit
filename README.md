# Worktree Kit ![CI](https://github.com/lexthink/worktree-kit/actions/workflows/ci.yaml/badge.svg) ![License: MIT](https://img.shields.io/github/license/lexthink/worktree-kit)

This kit provides a set of instructions and skills to enable workflows based on **git worktrees** and issue tracker tickets.

[**Full Usage Guide (Step-by-Step) →**](./USAGE.md)

## Features

- Fetches ticket data from your issue tracker (Linear, Jira, Shortcut, etc.).
- Automatically handles branch names from the issue tracker or existing PRs.
- Creates/reuses git worktrees named after the ticket (e.g., `ABC-1234`).
- **Emergency Hotfixes**: Specialized skill to quickly branch from `main` for urgent fixes.
- **Helper Scripts**: Automated bash scripts for worktree operations. See [USAGE.md](./USAGE.md#helper-scripts) for the full list.
- Optional file/directory copy and defaults via `.worktreeconfig`. See [USAGE.md](./USAGE.md#worktreeconfig-optional) for reference.
- **Agent-Agnostic**: Works with Claude Code, Codex, or any agent that supports skills.

## Prerequisites

- **Issue Tracker MCP/API**: Ensure you have your issue tracker (e.g., Linear, Jira) configured as an MCP server or API in your AI agent.
- **Git Bare Repository**: This kit is designed for a workflow where the main repository is cloned with `--bare` into `.git`.
- **Environment**: Optional file copying is configured via `.worktreeconfig`.

## Installation & Setup

### One-Line Install (recommended)

No need to clone the kit — just run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lexthink/worktree-kit/main/install.sh) \
  git@github.com:your-org/your-repo.git ~/dev/your-repo
```

```bash
# Choose a specific agent
bash <(curl -fsSL https://raw.githubusercontent.com/lexthink/worktree-kit/main/install.sh) \
  --agent codex git@github.com:your-org/your-repo.git ~/dev/your-repo

# Update an existing project
bash <(curl -fsSL https://raw.githubusercontent.com/lexthink/worktree-kit/main/install.sh) \
  ~/dev/your-repo
```

### Manual Install

If you prefer, you can clone the kit and run the installer directly:

```bash
git clone git@github.com:lexthink/worktree-kit.git
./worktree-kit/setup.sh git@github.com:your-org/your-repo.git ~/dev/your-repo

# Update an existing project
./worktree-kit/setup.sh ~/dev/your-repo
```

## Architecture

This kit uses a **Bare Repository** workflow to keep your workspace clean.

```text
Project Root/
├── .git/                (Bare Repo - Central storage)
├── .claude/             (Agent directory)
│   └── skills/          (Skills copied from kit)
├── .worktreeconfig      (Project settings)
├── CLAUDE.md            (Agent instructions)
├── ABC-1234/            (Active worktree/ticket)
│   └── [Your Code]
└── XYZ-5678/            (Another active worktree)
    └── [Your Code]
```

## Agent Configuration

Each agent has a `.conf` file in `src/agents/` that controls how the installer sets up that agent. Available agents are auto-detected from these files.

```ini
# src/agents/claude-code.conf
skills_dir = .claude
instructions_file = CLAUDE.md
```

| Key                 | Description                                      |
| ------------------- | ------------------------------------------------ |
| `skills_dir`        | Where skills are installed in the target project |
| `instructions_file` | Copy `AGENTS.md` with this name (omit to skip)   |

### Adding a new agent

Create a new `.conf` file in `src/agents/`:

```bash
# src/agents/myagent.conf
cp src/agents/claude-code.conf src/agents/myagent.conf
```

Edit the values for your agent, then install with:

```bash
./setup.sh --agent myagent ~/dev/your-repo
```

The installer will automatically detect the new agent from the `.conf` file.

## Troubleshooting

### 1. Agent cannot find issue tracker tools

Ensure you have your issue tracker's MCP server (e.g., Linear, Jira, Shortcut) installed and configured in your agent's settings.

### 2. "Git worktree add" fails

This usually happens if the `.git` folder is not a bare repository. Make sure you followed the `git clone --bare` step or used `install.sh` to initialize the project.

### 3. Skills are not appearing

Verify that your agent's `skills/` directory exists and contains the `worktree-*` folders (e.g., `.claude/skills/`). You may need to restart your agent/editor to refresh the skills list. Re-running `setup.sh` will re-copy the latest skills.

---

## Development & Testing

If you are contributing to this kit, you can run the test suite:

```bash
bats tests/*.bats
```
