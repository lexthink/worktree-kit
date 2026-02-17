#!/usr/bin/env bash
# wt-fetch-all.sh - Fetch latest changes in all worktrees in parallel
# Usage: wt-fetch-all.sh [--repo PATH] [--prune]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-fetch-all.sh - Fetch in all worktrees efficiently (parallel)

USAGE:
  wt-fetch-all.sh [options]

OPTIONS:
  --repo PATH      Repository root
  --prune          Prune deleted remote branches
  -h, --help       Show this help
EOF
  exit 0
}

REPO_ROOT=""
PRUNE_FLAG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --prune) PRUNE_FLAG="--prune"; shift ;;
    -h|--help) show_help ;;
    *) shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root)}" || { printf '%b\n' "$icon_fail Error: Not in a git repository" >&2; exit 1; }
WORKTREE_LIST=$(list_worktrees)

print_header "FETCHING GLOBAL UPDATES"

if [[ -z "$WORKTREE_LIST" ]]; then
  echo "No worktrees found."
  exit 0
fi

COUNT=$(echo "$WORKTREE_LIST" | wc -l)
printf '%b\n' "Starting parallel fetch for $COUNT worktrees... $icon_sync"

PIDS=()
while IFS='|' read -r wt_path _name _branch; do
  [[ -z "$wt_path" ]] && continue
  (
    if git -C "$wt_path" remote get-url origin >/dev/null 2>&1; then
      git_with_timeout git -C "$wt_path" fetch origin $PRUNE_FLAG --quiet 2>/dev/null
    fi
  ) &
  PIDS+=($!)
done <<< "$WORKTREE_LIST"

FAILED=0
for pid in "${PIDS[@]}"; do
  if ! wait "$pid" 2>/dev/null; then ((FAILED++)); fi
done

if [[ $FAILED -eq 0 ]]; then
  printf '%b\n' "  $icon_pass Fetched updates in all $COUNT worktrees."
else
  printf '%b\n' "  $icon_warn Completed with issues: $((COUNT - FAILED))/$COUNT succeeded."
fi
