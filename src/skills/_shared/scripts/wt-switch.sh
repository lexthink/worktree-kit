#!/usr/bin/env bash
# wt-switch.sh - Show context information for a worktree
# Usage: wt-switch.sh <FOLDER> [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-switch.sh - Display context information for a worktree

USAGE:
  wt-switch.sh <FOLDER> [options]

ARGUMENTS:
  FOLDER              Worktree folder name

OPTIONS:
  --repo PATH         Repository root (auto-detected if omitted)
  --json              Output result in JSON format
  -h, --help          Show this help

EXAMPLES:
  wt-switch.sh ABC-1234
  wt-switch.sh main --json
EOF
  exit 0
}

# --- Argument parsing ---
FOLDER=""
REPO_ROOT=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    -h|--help) show_help ;;
    -*) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
    *)  [[ -z "$FOLDER" ]] && FOLDER="$1"; shift ;;
  esac
done

if [[ -z "$FOLDER" ]]; then
  echo "Error: folder name is required" >&2
  exit 1
fi

# --- Resolve repo root ---
if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi

# --- Find the worktree ---
wt_path=""
wt_branch=""

if wt_info=$(find_worktree --folder "$FOLDER"); then
  IFS='|' read -r wt_path _ wt_branch <<< "$wt_info"
fi

if [[ -z "$wt_path" ]]; then
  [[ "$OUTPUT_JSON" == "true" ]] && json_error "Worktree not found: $FOLDER"
  printf '%b\n' "$icon_fail Worktree not found: $FOLDER" >&2
  exit 1
fi

# --- Gather context ---
status=$(get_wt_status "$wt_path")
changed_files=0
if [[ "$status" == "dirty" ]]; then
  changed_files=$(git -C "$wt_path" status --short 2>/dev/null | wc -l | tr -d ' ')
fi

last_hash=$(git -C "$wt_path" log -1 --format="%h" 2>/dev/null || echo "none")
last_msg=$(git -C "$wt_path" log -1 --format="%s" 2>/dev/null || echo "")
last_date=$(git -C "$wt_path" log -1 --format="%ar" 2>/dev/null || echo "unknown")

ahead=0
behind=0
if [[ "$wt_branch" != "detached" ]] && git -C "$wt_path" rev-parse --verify "${wt_branch}@{u}" >/dev/null 2>&1; then
  counts=$(git -C "$wt_path" rev-list --left-right --count "${wt_branch}...${wt_branch}@{u}" 2>/dev/null || echo "0 0")
  ahead=$(echo "$counts" | awk '{print $1}')
  behind=$(echo "$counts" | awk '{print $2}')
fi

# --- Output ---
if [[ "$OUTPUT_JSON" == "true" ]]; then
  json_open_obj
  printf '  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n' \
    "$(json_str folder "$FOLDER")" "$(json_str path "$wt_path")" \
    "$(json_str branch "$wt_branch")" "$(json_str status "$status")" \
    "$(json_raw changed_files "$changed_files")" "$(json_raw ahead "$ahead")" \
    "$(json_raw behind "$behind")"
  printf '  "last_commit": {%s, %s, %s}' \
    "$(json_str hash "$last_hash")" "$(json_str message "$last_msg")" "$(json_str date "$last_date")"
  json_close_obj
else
  printf '%b\n' "\n${BOLD}${BLUE}CONTEXT SWITCHED${NC}"
  printf '%b\n' "Folder:      ${CYAN}$FOLDER${NC}"
  printf '%b\n' "Path:        $wt_path"
  printf '%b\n' "Branch:      ${MAGENTA}$wt_branch${NC}"

  if [[ "$status" == "clean" ]]; then
    printf '%b\n' "Git Status:  $icon_clean"
  else
    printf '%b\n' "Git Status:  $icon_dirty ($changed_files change(s))"
  fi

  sync_info=""
  [[ "$ahead" -gt 0 ]] && sync_info="${GREEN}↑$ahead${NC}"
  [[ "$behind" -gt 0 ]] && sync_info="$sync_info ${RED}↓$behind${NC}"
  [[ -n "$sync_info" ]] && printf '%b\n' "Sync:        $sync_info"

  printf '%b\n' "Last Commit: ${YELLOW}$last_hash${NC} $last_msg (${BLUE}$last_date${NC})"
fi
