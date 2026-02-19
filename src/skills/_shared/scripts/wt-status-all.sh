#!/usr/bin/env bash
# wt-status-all.sh - Show concise status of all worktrees
# Usage: wt-status-all.sh [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-status-all.sh - Summary status of all worktrees

USAGE:
  wt-status-all.sh [options]

OPTIONS:
  --json      Output results in JSON format
  --repo PATH Repository root
  -h, --help  Show this help
EOF
  exit 0
}

REPO_ROOT=""
OUTPUT_FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    -h|--help) show_help ;;
    *) shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root)}" || { printf '%b\n' "$icon_fail Error: Not a git repository" >&2; exit 1; }

WORKTREE_LIST=$(list_worktrees)

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  json_open_arr
  while IFS='|' read -r worktree_path name _branch; do
    [[ -z "$worktree_path" ]] && continue
    status_code=$(get_wt_status "$worktree_path")
    dirty="false"; [[ "$status_code" == "dirty" ]] && dirty="true"
    json_comma
    printf '  {%s, %s, %s, %s}' \
      "$(json_str folder "$name")" "$(json_str path "$worktree_path")" \
      "$(json_str status "$status_code")" "$(json_raw dirty "$dirty")"
  done <<< "$WORKTREE_LIST"
  json_close_arr
  exit 0
fi

print_header "WORKTREE STATUS OVERVIEW"
printf '%b\n' "${BOLD}WORKTREE              STATUS${NC}"
echo "-----------------------------------"

while IFS='|' read -r worktree_path name _branch; do
  [[ -z "$worktree_path" ]] && continue

  # Use unified status and icon
  status_code=$(get_wt_status "$worktree_path")
  status_icon=$(get_wt_icon "$status_code")

  printf "%-20s  %b\n" "$name" "$status_icon"
done <<< "$WORKTREE_LIST"
