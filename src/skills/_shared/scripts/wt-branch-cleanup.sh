#!/usr/bin/env bash
# wt-branch-cleanup.sh - Clean up merged and stale branches
# Usage: wt-branch-cleanup.sh [--repo PATH] [--dry-run] [--remote]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-branch-cleanup.sh - Clean up merged and stale tracking branches

USAGE:
  wt-branch-cleanup.sh [options]

OPTIONS:
  --repo PATH      Repository root
  --dry-run        Show what would be deleted
  --remote         Also clean remote tracking branches (origin)
  -h, --help       Show this help
EOF
  exit 0
}

REPO_ROOT=""
DRY_RUN=false
CLEAN_REMOTE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --remote) CLEAN_REMOTE=true; shift ;;
    -h|--help) show_help ;;
    *) shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root)}" || { printf '%b\n' "$icon_fail Error: Not in a git repo" >&2; exit 1; }
DEFAULT_BRANCH=$("$SCRIPT_DIR/parse-config.sh" worktrees.default_branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")

print_header "BRANCH CLEANUP"

# Fetch first
printf '%b\n' "Pruning remote references... $icon_sync"
git_with_timeout git -C "$REPO_ROOT" fetch --prune origin --quiet 2>/dev/null || true

DELETED_LOCAL=0
DELETED_REMOTE=0

# Clean local
printf '%b\n' "Checking local merged branches (Target: $DEFAULT_BRANCH)..."
MERGED=$(git -C "$REPO_ROOT" branch --merged "$DEFAULT_BRANCH" 2>/dev/null | grep -v "^\*" | grep -v "^[[:space:]]*$DEFAULT_BRANCH$" | sed 's/^[[:space:]]*//' || echo "")

for branch in $MERGED; do
  [[ -z "$branch" ]] && continue
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%b\n' "  $icon_trash [DRY-RUN] Would delete: $branch"
  else
    if git -C "$REPO_ROOT" branch -d "$branch" >/dev/null 2>&1; then
      printf '%b\n' "  $icon_pass Deleted local: $branch"
      ((DELETED_LOCAL++))
    fi
  fi
done

# Clean remote tracking
if [[ "$CLEAN_REMOTE" == "true" ]]; then
  printf '%b\n' "\nChecking stale remote-tracking branches..."
  STALE=$(git -C "$REPO_ROOT" branch -v 2>/dev/null | grep "\[gone\]" | awk '{print $1}' || echo "")
  for branch in $STALE; do
    [[ -z "$branch" ]] && continue
    if [[ "$DRY_RUN" == "true" ]]; then
      printf '%b\n' "  $icon_trash [DRY-RUN] Would delete tracking: origin/$branch"
    else
      if git -C "$REPO_ROOT" branch -dr "origin/$branch" >/dev/null 2>&1; then
        printf '%b\n' "  $icon_pass Deleted tracking: origin/$branch"
        ((DELETED_REMOTE++))
      fi
    fi
  done
fi

if [[ "$DRY_RUN" == "true" ]]; then
  printf '%b\n' "\n${BOLD}${CYAN}Dry run complete.${NC}"
else
  if [[ "$DELETED_LOCAL" -eq 0 ]]; then
    printf '%b\n' "  ${BOLD}Deleted 0 local branches.${NC}"
  fi
  printf '%b\n' "\n${BOLD}${GREEN}Cleanup complete!${NC} ($DELETED_LOCAL local, $DELETED_REMOTE tracking removed)"
fi
