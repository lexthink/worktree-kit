#!/usr/bin/env bash
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect supported agents from agents/*.conf files
SUPPORTED_AGENTS=()
for agent_conf in "$KIT_DIR"/src/agents/*.conf; do
  [ -f "$agent_conf" ] || continue
  SUPPORTED_AGENTS+=("$(basename "$agent_conf" .conf)")
done

if [ ${#SUPPORTED_AGENTS[@]} -eq 0 ]; then
  echo "✖ Error: No agents found in $KIT_DIR/src/agents/. At least one .conf file is required."
  exit 1
fi

DEFAULT_AGENT="claude-code"

# Read a key from an agent's .conf file (returns empty string if not found)
read_manifest() {
  local agent="$1" key="$2"
  local conf="$KIT_DIR/src/agents/$agent.conf"
  [ -f "$conf" ] || return 0
  grep -E "^${key}\s*=" "$conf" 2>/dev/null | sed 's/^[^=]*=\s*//; s/\s*#.*//' | xargs || true
}

show_help() {
  echo "Worktree Kit - Command Line Interface"
  echo ""
  echo "This script installs a git worktree-based workflow into a project."
  echo "It initializes a bare repository in the .git directory and configures"
  echo "the necessary agent skills for a streamlined development experience."
  echo ""
  echo "Usage:"
  echo "  $0 [options] <git_url> <target_path>    Initialize a new project"
  echo "  $0 [options] <target_path>              Update skills in an existing project"
  echo ""
  echo "Options:"
  echo "  -a, --agent <name>  Agent to configure: ${SUPPORTED_AGENTS[*]} (default: $DEFAULT_AGENT)"
  echo "  -h, --help      Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 git@github.com:your-org/your-repo.git ~/dev/your-repo"
  echo "  $0 --agent codex git@github.com:your-org/your-repo.git ~/dev/your-repo"
  echo "  $0 ~/dev/your-repo"
  exit 0
}

# Check for help flags
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
fi

# Required external dependencies
if ! command -v git >/dev/null 2>&1; then
  echo "✖ Error: 'git' is required but not installed or not in PATH."
  exit 1
fi

# Parse flags
AGENT_SELECTION="$DEFAULT_AGENT"
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--agent)
      if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
        echo "✖ Error: $1 requires a value (${SUPPORTED_AGENTS[*]})."
        exit 1
      fi
      AGENT_SELECTION="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    -*)
      echo "✖ Error: Unknown option '$1'. See '$0 --help' for usage."
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Validate agent selection
VALID=false
for a in "${SUPPORTED_AGENTS[@]}"; do
  if [[ "$a" == "$AGENT_SELECTION" ]]; then
    VALID=true
    break
  fi
done
if [[ "$VALID" != "true" ]]; then
  echo "✖ Error: Unknown agent '$AGENT_SELECTION'. Supported: ${SUPPORTED_AGENTS[*]}"
  exit 1
fi

AGENTS=("$AGENT_SELECTION")

# Detect Mode from positional args
if [ ${#POSITIONAL_ARGS[@]} -ge 2 ]; then
  MODE="init"
  REPO_URL="${POSITIONAL_ARGS[0]}"
  RAW_TARGET="${POSITIONAL_ARGS[1]}"
elif [ ${#POSITIONAL_ARGS[@]} -eq 1 ]; then
  MODE="update"
  RAW_TARGET="${POSITIONAL_ARGS[0]}"
else
  show_help
fi

# Resolve to absolute path and normalize it
if [[ "$RAW_TARGET" = /* ]]; then
  ABS_TARGET="$RAW_TARGET"
else
  ABS_TARGET="$(pwd)/$RAW_TARGET"
fi

# Normalize path (handling .. and .)
normalize_path() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    # Try realpath, fallback if it fails (e.g. non-existent path on some OS)
    realpath "$target" 2>/dev/null || echo "$target"
  else
    # Fallback to a simple bash-based path resolution
    (cd "$target" 2>/dev/null && pwd) || echo "$target"
  fi
}

FULL_TARGET=$(normalize_path "$ABS_TARGET")

# 2. Prevent installing INTO or INSIDE the KIT_DIR
if [[ "$FULL_TARGET" == "$KIT_DIR" || "$FULL_TARGET" == "$KIT_DIR"/* ]]; then
  echo "✖ Error: Target directory cannot be inside the Worktree Kit directory."
  exit 1
fi

# --- Logic: Initialize New Project (only if MODE=init) ---
if [ "$MODE" = "init" ]; then
  echo "▶ Initializing new project at: $FULL_TARGET"

  if [ -d "$FULL_TARGET" ]; then
    echo "✖ Error: Directory '$FULL_TARGET' already exists."
    exit 1
  fi

  mkdir -p "$FULL_TARGET"
  cd "$FULL_TARGET" || { echo "✖ Error: Failed to enter directory '$FULL_TARGET'" >&2; exit 1; }
  TARGET_DIR="$(pwd)"

  echo "▶ Cloning bare repository..."
  git clone --bare "$REPO_URL" .git

  # Configure the bare repo to use standard remote refspecs.
  # This prevents local branches (refs/heads/) from conflicting with
  # remote branches if they share names like 'feature' vs 'feature/something'.
  git -C .git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  # Robustness: Increase lock timeouts to handle transient lock contention
  # (common with agents running multiple commands quickly)
  git -C .git config core.filesRefLockTimeout 100
  git -C .git config core.packedRefsTimeout 100

  # Optimization: Disable auto GC/maintenance in the bare repo.
  # This avoids slow background locks during worktree creation.
  git -C .git config gc.auto 0
  git -C .git config maintenance.auto 0

  # Push: auto-create remote branch with same name on first push.
  # Avoids needing 'git push -u origin <branch>' manually.
  git -C .git config push.autoSetupRemote true

  # No initial worktrees are created by default.

elif [ "$MODE" = "update" ]; then
  if [ ! -d "$FULL_TARGET" ]; then
    echo "✖ Error: Target directory '$FULL_TARGET' does not exist."
    exit 1
  fi
  cd "$FULL_TARGET" || { echo "✖ Error: Failed to enter directory '$FULL_TARGET'" >&2; exit 1; }
  TARGET_DIR="$(pwd)"
  echo "▶ Updating Worktree Kit in: $TARGET_DIR"

  if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "✖ Error: Target directory is missing a bare '.git' repository."
    echo "   Hint: Run init mode first to set up the bare repo."
    exit 1
  fi

  if [ "$(git -C "$TARGET_DIR/.git" rev-parse --is-bare-repository 2>/dev/null)" != "true" ]; then
    echo "✖ Error: Target '.git' is not a bare repository."
    echo "   Ensure the project was initialized with 'git clone --bare' or via this install script."
    exit 1
  fi
fi

# --- Shared Logic: Install Skills (Runs for both Init and Update) ---
echo "▶ Installing Worktree Kit skills for: ${AGENTS[*]}..."

# 1. Copy default .worktreeconfig if missing
if [ ! -f "$TARGET_DIR/.worktreeconfig" ]; then
  cp -f "$KIT_DIR/src/.worktreeconfig" "$TARGET_DIR/.worktreeconfig"
fi

# 2. Setup each agent: copy skills + agent-specific files
AGENT_DIRS=()
for agent in "${AGENTS[@]}"; do
  # Read skills_dir from agent config (fallback to .$agent)
  skills_dir=$(read_manifest "$agent" "skills_dir")
  skills_dir="${skills_dir:-.${agent}}"

  mkdir -p "$TARGET_DIR/$skills_dir"

  # Copy kit skills into agent directory (per-skill replace preserves user's custom skills)
  mkdir -p "$TARGET_DIR/$skills_dir/skills"
  for skill_src in "$KIT_DIR/src/skills"/*/; do
    [ -d "$skill_src" ] || continue
    skill_name="$(basename "$skill_src")"
    rm -rf "$TARGET_DIR/$skills_dir/skills/$skill_name"
    cp -R "$skill_src" "$TARGET_DIR/$skills_dir/skills/$skill_name"
  done

  # Copy instructions file with agent-specific name if declared in config
  # Replace .skills/ paths with the agent's actual skills path
  instructions_file=$(read_manifest "$agent" "instructions_file")
  if [ -n "$instructions_file" ]; then
    sed "s|\.skills/|$skills_dir/skills/|g" "$KIT_DIR/src/AGENTS.md" > "$TARGET_DIR/$instructions_file"
  fi

  # Replace .skills/ paths in copied skill docs with the agent's actual path
  find "$TARGET_DIR/$skills_dir/skills" -name "*.md" -print0 | while IFS= read -r -d '' mdfile; do
    sed "s|\.skills/|$skills_dir/skills/|g" "$mdfile" > "$mdfile.tmp" && mv "$mdfile.tmp" "$mdfile"
  done

  # Ensure all scripts are executable
  find "$TARGET_DIR/$skills_dir/skills" -name "*.sh" -exec chmod +x {} +

  AGENT_DIRS+=("$skills_dir/skills")
done

echo ""
echo "✓ Done! Worktree Kit is ready in: $TARGET_DIR"
echo "  Agent(s):     ${AGENTS[*]}"
echo "  Skills:       ${AGENT_DIRS[*]}"

if [ "$MODE" = "init" ]; then
  echo ""
  echo "Next: cd $RAW_TARGET"
fi
