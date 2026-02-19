#!/usr/bin/env bash
# wt-optimize.sh - Optimize storage used by worktrees
# Usage: wt-optimize.sh [--dry-run] [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-optimize.sh - Clean up build artifacts in secondary worktrees

USAGE:
  wt-optimize.sh [options]

OPTIONS:
  --dry-run   Show what would be deleted without actually deleting
  --repo PATH Repository root
  -h, --help  Show this help

ARTIFACTS DETECTED:
  node_modules, target, vendor, build, dist, .next, .cache
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

REPO_ROOT="${REPO_ROOT:-$(find_repo_root)}" || { printf '%b\n' "$icon_fail Error: Not a git repository" >&2; exit 1; }

print_header "SEARCHING FOR HEAVY ARTIFACTS"

WORKTREE_LIST=$(list_worktrees)

if [[ -z "$WORKTREE_LIST" ]]; then
  echo "No active secondary worktrees found."
  exit 0
fi

candidates=("node_modules" "target" "vendor" "build" "dist" ".next" ".cache")
declare -a OPTIMIZATIONS=()

while IFS='|' read -r wt_path name _branch; do
  [[ -z "$wt_path" ]] && continue
  for folder in "${candidates[@]}"; do
    if [[ -d "$wt_path/$folder" ]]; then
      size=$(du -sh "$wt_path/$folder" | awk '{print $1}')
      status="Found"
      if [[ "$DRY_RUN" == "false" ]]; then
        rm -rf "${wt_path:?}/${folder:?}"
        status="Cleaned"
      else
        status="Would Clean (dry-run)"
      fi
      OPTIMIZATIONS+=("$name|$folder|$size|$status")
    fi
  done
done <<< "$WORKTREE_LIST"

if [[ ${#OPTIMIZATIONS[@]} -eq 0 ]]; then
  echo "No heavy folders found to optimize."
  exit 0
fi

printf "${BOLD}%-20s %-15s %-10s %s${NC}\n" "WORKTREE" "FOLDER" "SIZE" "STATUS"
echo "--------------------------------------------------------------------------------"
for e in "${OPTIMIZATIONS[@]}"; do
  IFS='|' read -r w f s st <<< "$e"
  printf "%-20s %-15s %-10s %s\n" "$w" "$f" "$s" "$st"
done

printf '%b\n' "\n${BOLD}${GREEN}Optimization completed!${NC}"
[[ "$DRY_RUN" == "true" ]] && printf '%b\n' "${YELLOW}(Dry-run: No files were actually deleted)${NC}"
