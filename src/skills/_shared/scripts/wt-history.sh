#!/usr/bin/env bash
# wt-history.sh - View worktree operation history

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-history.sh - View history of worktree operations

USAGE:
  wt-history.sh [options]

OPTIONS:
  -n NUMBER   Number of entries to show (default: 20)
  --worktree NAME Filter by worktree name
  --json      Output entries as JSON
  --repo PATH Repository root
  -h, --help  Show this help
EOF
  exit 0
}

REPO_ROOT=""
COUNT=20
FILTER_WORKTREE=""
OUTPUT_FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -n) COUNT="$2"; shift 2 ;;
    --worktree) FILTER_WORKTREE="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    -h|--help) show_help ;;
    *) shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"
LOG_FILE="$REPO_ROOT/.worktree-history.log"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No history log found."
  exit 0
fi

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  printf "[\n"
  first=true
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^\[([^\]]+)\]\ \[([^\]]+)\]\ ([a-z-]+)(.*) ]]; then
      ts="${BASH_REMATCH[1]}"; user="${BASH_REMATCH[2]}"; op="${BASH_REMATCH[3]}"; rest="${BASH_REMATCH[4]}"
      wt=""; [[ "$rest" =~ worktree=([^ ]+) ]] && wt="${BASH_REMATCH[1]}"
      [[ -n "$FILTER_WORKTREE" && "$wt" != "$FILTER_WORKTREE" ]] && continue
      branch=""; [[ "$rest" =~ branch=([^ ]+) ]] && branch="${BASH_REMATCH[1]}"
      details=""; [[ "$rest" =~ details=\"(.*)\"$ ]] && details="${BASH_REMATCH[1]}"
      [[ "$first" == "true" ]] && first=false || printf ",\n"
      printf '  {"timestamp": "%s", "user": "%s", "operation": "%s", "worktree": "%s", "branch": "%s", "details": "%s"}' \
        "$(json_escape "$ts")" "$(json_escape "$user")" "$(json_escape "$op")" "$(json_escape "$wt")" "$(json_escape "$branch")" "$(json_escape "$details")"
    fi
  done < <(tail -n "$COUNT" "$LOG_FILE")
  printf "\n]\n"
  exit 0
fi

print_header "OPERATION HISTORY"
printf '%b\n' "${BOLD}TIMESTAMP           OPERATION  WORKTREE     DETAILS${NC}"
echo "------------------------------------------------------------"

tail -n "$COUNT" "$LOG_FILE" | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^\[([^\]]+)\]\ \[([^\]]+)\]\ ([a-z-]+)(.*) ]]; then
    ts="${BASH_REMATCH[1]}"; op="${BASH_REMATCH[3]}"; rest="${BASH_REMATCH[4]}"
    wt="-"; [[ "$rest" =~ worktree=([^ ]+) ]] && wt="${BASH_REMATCH[1]}"
    [[ -n "$FILTER_WORKTREE" && "$wt" != "$FILTER_WORKTREE" ]] && continue
    printf "%-19s %-10s %-12s %s\n" "${ts:0:19}" "$op" "$wt" "${rest#*details=}"
  fi
done
