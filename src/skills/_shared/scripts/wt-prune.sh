#!/usr/bin/env bash
# wt-prune.sh - Clean up orphaned worktree references and empty directories
# Usage: wt-prune.sh [--dry-run] [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-prune.sh - Clean up orphaned git worktree references

USAGE:
  wt-prune.sh [options]

OPTIONS:
  --dry-run   Show what would be pruned
  --repo PATH Repository root
  -h, --help  Show this help
EOF
  exit 0
}

DRY_RUN=false
REPO_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root)}" || { printf '%b\n' "$icon_fail Error: Not in a git repo" >&2; exit 1; }

print_header "PRUNING WORKTREE REFERENCES"

# 1. Git Prune
if [[ "$DRY_RUN" == "true" ]]; then
  printf '%b\n' "Checking orphaned git references (dry-run)... $icon_sync"
  git -C "$REPO_ROOT" worktree prune --dry-run -v
else
  printf '%b\n' "Cleaning orphaned git references... $icon_sync"
  git -C "$REPO_ROOT" worktree prune -v
  printf '%b\n' "  $icon_pass Git references cleaned."
fi

# 2. Directory Prune
WORKTREES_DIR=$("$SCRIPT_DIR/parse-config.sh" worktrees.directory --repo "$REPO_ROOT" 2>/dev/null || echo "")
if [[ -n "$WORKTREES_DIR" && -d "$WORKTREES_DIR" ]]; then
  printf '%b\n' "\nChecking for empty directories in ${CYAN}$WORKTREES_DIR${NC}..."
  EMPTY_DIRS=$(find "$WORKTREES_DIR" -maxdepth 1 -type d -empty ! -path "$WORKTREES_DIR")
  if [[ -n "$EMPTY_DIRS" ]]; then
    while read -r dir; do
      if [[ "$DRY_RUN" == "true" ]]; then
        printf '%b\n' "  $icon_trash [DRY-RUN] Would remove: $(basename "$dir")"
      else
        rmdir "$dir"
        printf '%b\n' "  $icon_pass Removed empty directory: $(basename "$dir")"
      fi
    done <<< "$EMPTY_DIRS"
  else
    printf '%b\n' "  $icon_pass No empty directories found."
  fi
fi

printf '%b\n' "\n${BOLD}${GREEN}Prune completed!${NC}"
