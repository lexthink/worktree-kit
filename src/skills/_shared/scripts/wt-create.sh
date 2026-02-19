#!/usr/bin/env bash
# wt-create.sh - Create a git worktree with full environment setup
# Unifies the creation logic used by worktree-add and worktree-checkout skills.
# Usage: wt-create.sh --branch <BRANCH> --folder <FOLDER> [--base <BASE>] [--dry-run] [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-create.sh - Create a git worktree with environment setup

USAGE:
  wt-create.sh --branch <BRANCH> --folder <FOLDER> [options]

REQUIRED:
  --branch BRANCH   Branch name for the worktree
  --folder FOLDER   Folder name for the worktree (e.g. ABC-1234)

OPTIONS:
  --base BRANCH     Base branch for new branches (default: from config or main)
  --repo PATH       Repository root (auto-detected if omitted)
  --json            Output result in JSON format
  --dry-run         Show what would be created without doing it
  --no-hooks        Skip post-create hooks
  --no-copy         Skip file copying from .worktreeconfig
  -h, --help        Show this help

EXIT CODES:
  0   Worktree created or reused successfully
  1   Error (missing args, git failure, etc.)

EXAMPLES:
  wt-create.sh --branch feature/auth --folder ABC-1234
  wt-create.sh --branch feature/auth --folder ABC-1234 --base develop
  wt-create.sh --branch main --folder main-test --json
EOF
  exit 0
}

# --- Argument parsing ---
BRANCH=""
FOLDER=""
BASE_BRANCH=""
REPO_ROOT=""
OUTPUT_JSON=false
DRY_RUN=false
RUN_HOOKS=true
RUN_COPY=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)  BRANCH="$2"; shift 2 ;;
    --folder)  FOLDER="$2"; shift 2 ;;
    --base)    BASE_BRANCH="$2"; shift 2 ;;
    --repo)    REPO_ROOT="$2"; shift 2 ;;
    --json)    OUTPUT_JSON=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --no-hooks) RUN_HOOKS=false; shift ;;
    --no-copy)  RUN_COPY=false; shift ;;
    -h|--help) show_help ;;
    *) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
  esac
done

# --- Validation ---
if [[ -z "$BRANCH" ]]; then
  echo "Error: --branch is required" >&2
  exit 1
fi
if [[ -z "$FOLDER" ]]; then
  echo "Error: --folder is required" >&2
  exit 1
fi

# --- Resolve repo root ---
if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi
[[ -d "$REPO_ROOT/.git" ]] || { printf '%b\n' "$icon_fail Error: Not a bare git repository (missing .git dir)" >&2; exit 1; }

# --- Resolve worktrees directory ---
WORKTREES_DIR="$REPO_ROOT"
if configured_dir=$("$SCRIPT_DIR/parse-config.sh" worktrees.directory --repo "$REPO_ROOT" 2>/dev/null); then
  case "$configured_dir" in
    /*) WORKTREES_DIR="$configured_dir" ;;
    ~*) WORKTREES_DIR="${configured_dir/#\~/$HOME}" ;;
    *)  WORKTREES_DIR="$REPO_ROOT/$configured_dir" ;;
  esac
  mkdir -p "$WORKTREES_DIR"
fi

# --- Resolve base branch ---
if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH=$("$SCRIPT_DIR/parse-config.sh" worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")
fi

FULL_PATH="$WORKTREES_DIR/$FOLDER"
ACTION="created"
HAS_UPSTREAM=false

# --- Step 1: Check for existing worktree ---

# Check if folder already exists as a worktree
if wt_info=$(find_worktree --folder "$FOLDER"); then
  IFS='|' read -r FULL_PATH _ _ <<< "$wt_info"
  ACTION="reused"
fi

# Check if branch is already checked out in a different worktree
if [[ "$ACTION" != "reused" ]]; then
  if wt_info=$(find_worktree --branch "$BRANCH"); then
    IFS='|' read -r FULL_PATH FOLDER _ <<< "$wt_info"
    ACTION="reused"
  fi
fi

# --- Dry run ---
if [[ "$DRY_RUN" == "true" ]]; then
  has_local=false; has_remote=false
  git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null && has_local=true
  git_with_timeout git -C "$REPO_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1 && has_remote=true

  if [[ "$OUTPUT_JSON" == "true" ]]; then
    cat <<ENDJSON
{
  "dry_run": true,
  "folder": "$(json_escape "$FOLDER")",
  "path": "$(json_escape "$FULL_PATH")",
  "branch": "$(json_escape "$BRANCH")",
  "base": "$(json_escape "$BASE_BRANCH")",
  "action": "$ACTION",
  "has_local": $has_local,
  "has_remote": $has_remote
}
ENDJSON
  else
    printf '%b\n' "\n${BOLD}${CYAN}DRY RUN — nothing will be created${NC}"
    printf '%b\n' "Folder: ${CYAN}$FOLDER${NC}"
    printf '%b\n' "Path:   $FULL_PATH"
    printf '%b\n' "Branch: ${MAGENTA}$BRANCH${NC}"
    printf '%b\n' "Base:   $BASE_BRANCH"
    printf '%b\n' "Action: $ACTION"
    [[ "$has_local" == "true" ]] && printf '%b\n' "Local:  $icon_pass exists"
    [[ "$has_remote" == "true" ]] && printf '%b\n' "Remote: $icon_pass exists"
  fi
  exit 0
fi

# --- Step 2: Create worktree (only if not reused) ---
if [[ "$ACTION" != "reused" ]]; then
  # Determine branch availability
  has_local=false
  has_remote=false

  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
    has_local=true
  fi
  if git_with_timeout git -C "$REPO_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    has_remote=true
  fi

  if [[ "$has_local" == "true" ]]; then
    # Branch exists locally — fetch remote ref so tracking info is up to date
    if [[ "$has_remote" == "true" ]]; then
      git_with_timeout git -C "$REPO_ROOT" fetch origin "$BRANCH" --quiet 2>/dev/null || true
    fi
    git -C "$REPO_ROOT" worktree add "$FULL_PATH" "$BRANCH"
  elif [[ "$has_remote" == "true" ]]; then
    # Branch exists on remote only
    git_with_timeout git -C "$REPO_ROOT" fetch origin "$BRANCH"
    git -C "$REPO_ROOT" worktree add "$FULL_PATH" -b "$BRANCH" "origin/$BRANCH"
  else
    # New branch from base
    if git_with_timeout git -C "$REPO_ROOT" ls-remote --exit-code --heads origin "$BASE_BRANCH" >/dev/null 2>&1; then
      git_with_timeout git -C "$REPO_ROOT" fetch origin "$BASE_BRANCH" --quiet 2>/dev/null || true
      git -C "$REPO_ROOT" worktree add "$FULL_PATH" -b "$BRANCH" --no-track "origin/$BASE_BRANCH"
    else
      git -C "$REPO_ROOT" worktree add "$FULL_PATH" -b "$BRANCH" --no-track "$BASE_BRANCH"
    fi
  fi
fi

# --- Step 3: Upstream tracking ---
UPSTREAM_MSG=""
if git -C "$FULL_PATH" rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  HAS_UPSTREAM=true
elif git -C "$REPO_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git -C "$FULL_PATH" branch --set-upstream-to="origin/$BRANCH" "$BRANCH" 2>/dev/null || true
  HAS_UPSTREAM=true
else
  UPSTREAM_MSG="git push -u origin $BRANCH"
fi

# --- Step 4: Environment setup (only for newly created) ---
if [[ "$ACTION" == "created" ]]; then
  # Copy files
  if [[ "$RUN_COPY" == "true" ]]; then
    "$SCRIPT_DIR/copy-files.sh" "$FULL_PATH" --repo "$REPO_ROOT" || printf '%b\n' "  $icon_warn copy-files failed (non-fatal)" >&2
  fi

  # Run post-create hooks
  if [[ "$RUN_HOOKS" == "true" ]]; then
    "$SCRIPT_DIR/wt-run-hooks.sh" post-create "$FULL_PATH" --repo "$REPO_ROOT" 2>/dev/null || true
  fi

  # Log operation
  "$SCRIPT_DIR/wt-log.sh" worktree-create "$FOLDER" "Branch: $BRANCH Base: $BASE_BRANCH" --repo "$REPO_ROOT" 2>/dev/null || true
fi

# --- Output ---
if [[ "$OUTPUT_JSON" == "true" ]]; then
  cat <<ENDJSON
{
  "folder": "$(json_escape "$FOLDER")",
  "path": "$(json_escape "$FULL_PATH")",
  "branch": "$(json_escape "$BRANCH")",
  "base": "$(json_escape "$BASE_BRANCH")",
  "action": "$ACTION",
  "has_upstream": $HAS_UPSTREAM,
  "upstream_cmd": "$(json_escape "$UPSTREAM_MSG")"
}
ENDJSON
else
  printf '%b\n' "\n${BOLD}${GREEN}WORKTREE READY${NC}"
  printf '%b\n' "Folder: ${CYAN}$FOLDER${NC}"
  printf '%b\n' "Branch: ${MAGENTA}$BRANCH${NC}"
  printf '%b\n' "Base:   $BASE_BRANCH"
  printf '%b\n' "Action: $ACTION"
  printf '%b\n' "Next:   ${BOLD}cd $FOLDER${NC}"
  if [[ -n "$UPSTREAM_MSG" ]]; then
    printf '%b\n' "Upstream: run ${YELLOW}$UPSTREAM_MSG${NC}"
  fi
fi
