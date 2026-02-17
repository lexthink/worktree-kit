#!/usr/bin/env bash
# wt-inspect.sh - Detailed inspection of a specific worktree
# Usage: wt-inspect.sh <folder_name|path> [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../_shared/scripts/ui-utils.sh"
source "$SCRIPT_DIR/../../_shared/scripts/wt-parse.sh"

show_help() {
  cat <<EOF
wt-inspect.sh - Detailed report of a specific worktree

USAGE:
  wt-inspect.sh <folder_name|path> [options]

OPTIONS:
  --json      Output report in JSON format
  --repo PATH Repository root
  -h, --help  Show this help
EOF
  exit 0
}

OUTPUT_FORMAT="text"
TARGET=""
REPO_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_FORMAT="json"; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) [[ -z "$TARGET" ]] && TARGET="$1"; shift ;;
  esac
done

[[ -z "$TARGET" ]] && show_help
REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"

WORKTREE_INFO=$(find_worktree "$TARGET") || { echo "Error: Worktree '$TARGET' not found." >&2; exit 1; }
IFS='|' read -r WT_PATH _ WT_BRANCH <<< "$WORKTREE_INFO"
WT_FOLDER="$(basename "$WT_PATH")"

# Unified fast status check
STATUS_CODE=$(get_wt_status "$WT_PATH")
GIT_STATUS_SHORT=$(git -C "$WT_PATH" status --short 2>/dev/null || echo "")

STAGED=$(git -C "$WT_PATH" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
UNSTAGED=$(git -C "$WT_PATH" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
UNTRACKED=$(git -C "$WT_PATH" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

RECENT_COMMITS=$(git -C "$WT_PATH" log -5 --oneline --decorate 2>/dev/null || echo "(no commits)")
AHEAD=0; BEHIND=0; UPSTREAM=""; HAS_UPSTREAM="false"
if UPSTREAM=$(git -C "$WT_PATH" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  HAS_UPSTREAM="true"
  COUNTS=$(git -C "$WT_PATH" rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")
  AHEAD=$(echo "$COUNTS" | awk '{print $1}'); BEHIND=$(echo "$COUNTS" | awk '{print $2}')
fi
LAST_COMMIT_DATE=$(git -C "$WT_PATH" log -1 --format="%ci" HEAD 2>/dev/null || echo "unknown")
LAST_COMMIT_REL=$(git -C "$WT_PATH" log -1 --format="%cr" HEAD 2>/dev/null || echo "unknown")
LAST_COMMIT_AUTHOR=$(git -C "$WT_PATH" log -1 --format="%an" HEAD 2>/dev/null || echo "unknown")

output_json() {
  local status_clean="true"; [[ "$STATUS_CODE" == "dirty" ]] && status_clean="false"
  cat <<ENDJSON
{
  "folder": "$(json_escape "$WT_FOLDER")", "path": "$(json_escape "$WT_PATH")", "branch": "$(json_escape "$WT_BRANCH")",
  "status": {"clean": $status_clean, "code": "$(json_escape "$STATUS_CODE")", "staged": $STAGED, "unstaged": $UNSTAGED, "untracked": $UNTRACKED},
  "sync": {"has_upstream": $HAS_UPSTREAM, "upstream": "$(json_escape "$UPSTREAM")", "ahead": $AHEAD, "behind": $BEHIND},
  "last_commit": {"date": "$(json_escape "$LAST_COMMIT_DATE")", "relative": "$(json_escape "$LAST_COMMIT_REL")", "author": "$(json_escape "$LAST_COMMIT_AUTHOR")"}
}
ENDJSON
}

output_text() {
  echo "Worktree Status: $WT_FOLDER"
  print_header "INSPECTING: $WT_FOLDER"
  printf '%b\n' "Location: ${CYAN}$WT_PATH${NC}"
  printf '%b\n' "Branch:   ${MAGENTA}$WT_BRANCH${NC}"

  printf '%b\n' "\n${BOLD}Uncommitted Changes:${NC}"
  if [[ "$STATUS_CODE" == "clean" ]]; then
    printf '%b\n' "  $icon_clean Working tree clean"
  else
    echo "$GIT_STATUS_SHORT" | sed 's/^/  /'
    printf '%b\n' "  Summary: $STAGED staged, $UNSTAGED unstaged, $UNTRACKED untracked"
  fi

  printf '%b\n' "\n${BOLD}Sync Status:${NC}"
  if [[ "$HAS_UPSTREAM" == "true" ]]; then
    if [[ "$AHEAD" -eq 0 && "$BEHIND" -eq 0 ]]; then printf '%b\n' "  $icon_clean Up to date with $UPSTREAM";
    else printf '%b\n' "  Ahead:  $AHEAD"; printf '%b\n' "  Behind: $BEHIND"; printf '%b\n' "  Remote: $UPSTREAM"; fi
  else printf '%b\n' "  ${YELLOW}⚠ No upstream configured${NC}"; fi

  printf '%b\n' "\n${BOLD}Recent History:${NC}"
  echo "$RECENT_COMMITS" | sed 's/^/  /'

  printf '%b\n' "\n${BOLD}Last Activity:${NC}"
  printf '%b\n' "  When:   $LAST_COMMIT_REL ($LAST_COMMIT_DATE)"
  printf '%b\n' "  Author: $LAST_COMMIT_AUTHOR"
}

case "$OUTPUT_FORMAT" in
  json) output_json ;;
  text) output_text ;;
esac
