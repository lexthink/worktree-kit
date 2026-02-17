#!/usr/bin/env bash
# wt-log.sh - Log worktree operations for history tracking
# Usage: wt-log.sh <operation> <worktree_name> [details...] [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

# This script is mostly internal, but we add help for completeness
show_help() {
  cat <<EOF
wt-log.sh - Internal logger for Worktree Kit

USAGE:
  wt-log.sh <operation> <worktree_name> [details...] [--repo PATH]

ARGUMENTS:
  operation     Type of operation (e.g. create, hotfix, stash)
  worktree_name Name of the worktree
  details       Optional additional information
EOF
  exit 0
}

REPO_ROOT=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

set -- "${ARGS[@]}"
[[ -z "$REPO_ROOT" ]] && REPO_ROOT=$(find_repo_root "$PWD" pwd)
LOG_FILE="$REPO_ROOT/.worktree-history.log"

# Ensure log file exists
touch "$LOG_FILE"

# Get metadata
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OPERATION="${1:-unknown}"
WORKTREE_NAME="${2:-}"
DETAILS="${*:3}"
USER="${USER:-$(whoami)}"

CURRENT_BRANCH=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi

# Format log entry
LOG_ENTRY="[$TIMESTAMP] [$USER] $OPERATION"
[[ -n "$WORKTREE_NAME" ]] && LOG_ENTRY="$LOG_ENTRY worktree=$WORKTREE_NAME"
[[ -n "$CURRENT_BRANCH" ]] && LOG_ENTRY="$LOG_ENTRY branch=$CURRENT_BRANCH"
[[ -n "$DETAILS" ]] && LOG_ENTRY="$LOG_ENTRY details=\"$DETAILS\""

# Append to log
echo "$LOG_ENTRY" >> "$LOG_FILE"

# Log rotation (keep last 1000 entries)
# Uses a lock file to prevent concurrent rotations from losing entries
LOCK_FILE="$LOG_FILE.lock"
if [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
  if ( set -o noclobber; echo $$ > "$LOCK_FILE" ) 2>/dev/null; then
    trap 'rm -f "$LOCK_FILE"' EXIT
    # Re-check after acquiring lock (another process may have rotated)
    if [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
      tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp"
      mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    rm -f "$LOCK_FILE"
    trap - EXIT
  fi
fi
