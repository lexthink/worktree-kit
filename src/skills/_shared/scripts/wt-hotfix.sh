#!/usr/bin/env bash
# wt-hotfix.sh - Create and manage rapid hotfix worktrees
# Delegates to wt-create.sh for the actual worktree creation.
# Usage: wt-hotfix.sh <hotfix_name> [--base BRANCH] [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-hotfix.sh - Rapidly create an isolated worktree for a hotfix

USAGE:
  wt-hotfix.sh <hotfix_name> [options]

ARGUMENTS:
  hotfix_name       Unique ID for the hotfix (e.g. security-patch)

OPTIONS:
  --base BRANCH     Base branch to fork from (default: main)
  --repo PATH       Repository root
  --json            Output result in JSON format
  -h, --help        Show this help
EOF
  exit 0
}

REPO_ROOT=""
BASE_BRANCH=""
HOTFIX_NAME=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --base) BASE_BRANCH="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    -h|--help) show_help ;;
    *) [[ -z "$HOTFIX_NAME" ]] && HOTFIX_NAME="$1"; shift ;;
  esac
done

if [[ -z "$HOTFIX_NAME" ]]; then
  echo "Error: hotfix_name is required" >&2
  exit 1
fi

if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi
[[ -d "$REPO_ROOT/.git" ]] || { printf '%b\n' "$icon_fail Error: Not in a git repository" >&2; exit 1; }

# Config & Branching
DEFAULT_BRANCH=$("$SCRIPT_DIR/parse-config.sh" worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")
BASE_BRANCH="${BASE_BRANCH:-$DEFAULT_BRANCH}"
HOTFIX_FOLDER="hotfix-$HOTFIX_NAME"
HOTFIX_BRANCH="hotfix/$HOTFIX_NAME"

# Validations
[[ -d "$REPO_ROOT/$HOTFIX_FOLDER" ]] && { printf '%b\n' "$icon_fail Folder $HOTFIX_FOLDER already exists" >&2; exit 1; }
git -C "$REPO_ROOT" rev-parse --verify "$HOTFIX_BRANCH" >/dev/null 2>&1 && { printf '%b\n' "$icon_fail Branch $HOTFIX_BRANCH already exists" >&2; exit 1; }

# Fetch latest base branch
printf '%b\n' "Fetching base branch: ${BOLD}$BASE_BRANCH${NC}... $icon_sync"
git_with_timeout git -C "$REPO_ROOT" fetch origin "$BASE_BRANCH" --quiet 2>/dev/null || true

# Delegate to wt-create.sh
CREATE_ARGS=(--branch "$HOTFIX_BRANCH" --folder "$HOTFIX_FOLDER" --base "$BASE_BRANCH" --repo "$REPO_ROOT")
[[ "$OUTPUT_JSON" == "true" ]] && CREATE_ARGS+=(--json)

exec "$SCRIPT_DIR/wt-create.sh" "${CREATE_ARGS[@]}"
