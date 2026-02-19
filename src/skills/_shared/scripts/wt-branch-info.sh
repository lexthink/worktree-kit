#!/usr/bin/env bash
# wt-branch-info.sh - Show branch availability and details
# Usage: wt-branch-info.sh <BRANCH> [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-branch-info.sh - Check if a branch exists locally/remotely and show details

USAGE:
  wt-branch-info.sh <BRANCH> [options]

ARGUMENTS:
  BRANCH              Branch name to check

OPTIONS:
  --repo PATH         Repository root (auto-detected if omitted)
  --json              Output result in JSON format
  -h, --help          Show this help

EXAMPLES:
  wt-branch-info.sh feature/auth
  wt-branch-info.sh main --json
  wt-branch-info.sh origin/develop --repo /path/to/repo
EOF
  exit 0
}

# --- Argument parsing ---
BRANCH=""
REPO_ROOT=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    -h|--help) show_help ;;
    -*) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
    *)  [[ -z "$BRANCH" ]] && BRANCH="$1"; shift ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  echo "Error: branch name is required" >&2
  exit 1
fi

# --- Resolve repo root ---
if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi

# Strip origin/ prefix for checking
CLEAN_BRANCH="${BRANCH#origin/}"

# --- Check availability ---
has_local=false
has_remote=false
checked_out_in=""
last_commit_hash=""
last_commit_msg=""
last_commit_date=""
ahead=0
behind=0

if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$CLEAN_BRANCH" 2>/dev/null; then
  has_local=true
  last_commit_hash=$(git -C "$REPO_ROOT" log -1 --format="%h" "$CLEAN_BRANCH" 2>/dev/null || echo "")
  last_commit_msg=$(git -C "$REPO_ROOT" log -1 --format="%s" "$CLEAN_BRANCH" 2>/dev/null || echo "")
  last_commit_date=$(git -C "$REPO_ROOT" log -1 --format="%ar" "$CLEAN_BRANCH" 2>/dev/null || echo "")
fi

if git_with_timeout git -C "$REPO_ROOT" ls-remote --exit-code --heads origin "$CLEAN_BRANCH" >/dev/null 2>&1; then
  has_remote=true
fi

# Check if checked out in any worktree
if wt_info=$(find_worktree --branch "$CLEAN_BRANCH"); then
  IFS='|' read -r _ checked_out_in _ <<< "$wt_info"
fi

# Ahead/behind (only if both local and remote exist)
if [[ "$has_local" == "true" && "$has_remote" == "true" ]]; then
  counts=$(git -C "$REPO_ROOT" rev-list --left-right --count "$CLEAN_BRANCH...origin/$CLEAN_BRANCH" 2>/dev/null || echo "0 0")
  ahead=$(echo "$counts" | awk '{print $1}')
  behind=$(echo "$counts" | awk '{print $2}')
fi

# --- Output ---
if [[ "$OUTPUT_JSON" == "true" ]]; then
  json_open_obj
  printf '  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n' \
    "$(json_str branch "$CLEAN_BRANCH")" "$(json_raw exists_local "$has_local")" \
    "$(json_raw exists_remote "$has_remote")" "$(json_str checked_out_in "$checked_out_in")" \
    "$(json_raw ahead "$ahead")" "$(json_raw behind "$behind")"
  printf '  "last_commit": {%s, %s, %s}' \
    "$(json_str hash "$last_commit_hash")" "$(json_str message "$last_commit_msg")" \
    "$(json_str date "$last_commit_date")"
  json_close_obj
else
  print_header "BRANCH INFO: $CLEAN_BRANCH"

  # Availability
  if [[ "$has_local" == "true" ]]; then
    printf '%b\n' "  Local:      $icon_pass exists"
  else
    printf '%b\n' "  Local:      $icon_fail not found"
  fi

  if [[ "$has_remote" == "true" ]]; then
    printf '%b\n' "  Remote:     $icon_pass origin/$CLEAN_BRANCH"
  else
    printf '%b\n' "  Remote:     $icon_fail not found"
  fi

  # Checked out?
  if [[ -n "$checked_out_in" ]]; then
    printf '%b\n' "  Worktree:   ${CYAN}$checked_out_in${NC}"
  else
    printf '%b\n' "  Worktree:   (not checked out)"
  fi

  # Sync status
  if [[ "$has_local" == "true" && "$has_remote" == "true" ]]; then
    sync=""
    [[ "$ahead" -gt 0 ]] && sync="${GREEN}↑$ahead${NC} "
    [[ "$behind" -gt 0 ]] && sync="$sync${RED}↓$behind${NC}"
    [[ -z "$sync" ]] && sync="$icon_pass in sync"
    printf '%b\n' "  Sync:       $sync"
  fi

  # Last commit
  if [[ -n "$last_commit_hash" ]]; then
    printf '%b\n' "  Last Commit: ${YELLOW}$last_commit_hash${NC} $last_commit_msg (${BLUE}$last_commit_date${NC})"
  fi
fi
