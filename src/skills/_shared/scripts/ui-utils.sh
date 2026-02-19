#!/usr/bin/env bash
# ui-utils.sh - Professional technical UI utilities for Worktree Kit

# Colors
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
MAGENTA=$'\e[0;35m'
CYAN=$'\e[0;36m'
BOLD=$'\e[1m'
NC=$'\e[0m'

# Disable colors if not in a terminal (for agents/CI)
if [[ ! -t 1 ]]; then
  RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' NC=''
fi

# Simple header
print_header() {
  local title="$1"
  printf '%b\n' "\n${BOLD}${BLUE}=== $title ===${NC}"
}

# Status Technical Icons (Unicode Technical Glyphs)
icon_clean="${GREEN}✓ clean${NC}"
icon_dirty="${YELLOW}✎ dirty${NC}"
icon_behind="${RED}↓ behind${NC}"
icon_ahead="${GREEN}↑ ahead${NC}"
icon_broken="${RED}✖ broken${NC}"
icon_star="${YELLOW}★${NC}"
icon_warn="${YELLOW}⚠${NC}"
icon_info="${BLUE}ℹ${NC}"
icon_pass="${GREEN}✓${NC}"
icon_fail="${RED}✖${NC}"
icon_sync="${CYAN}⟳${NC}"
icon_trash="${RED}✖ rm${NC}"

# Unified Status Logic (Fast & Reliable)
# Returns: "clean" or "dirty"
# Usage: status=$(get_wt_status "/path/to/worktree")
get_wt_status() {
  local wt_path="$1"

  # Check if it's even a valid directory
  if [[ ! -d "$wt_path" ]]; then
    echo "broken"
    return
  fi

  # FAST Status check: git diff-index is much faster than git status
  # 1. Check for modified/staged files
  if ! git -C "$wt_path" diff-index --quiet HEAD -- 2>/dev/null; then
    echo "dirty"
    return
  fi

  # 2. Check for untracked files (also very fast with ls-files)
  if [[ -n "$(git -C "$wt_path" ls-files --others --exclude-standard 2>/dev/null | head -n 1)" ]]; then
    echo "dirty"
    return
  fi

  echo "clean"
}

# Unified Icon Wrapper
# Usage: icon=$(get_wt_icon "dirty")
get_wt_icon() {
  local status="$1"
  case "$status" in
    clean)  printf '%b\n' "$icon_clean" ;;
    dirty)  printf '%b\n' "$icon_dirty" ;;
    broken) printf '%b\n' "$icon_broken" ;;
    *)      printf '%b\n' "$status" ;;
  esac
}

# Find repository root (directory containing .git).
# Usage: find_repo_root [start_dir] [pwd]
# If "pwd" is passed as the second arg, returns $PWD when not found.
find_repo_root() {
  local dir="${1:-$PWD}"
  local fallback="${2:-}"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  if [[ "$fallback" == "pwd" ]]; then
    echo "$PWD"
    return 0
  fi
  return 1
}

# Run a git network command with a timeout (default: 30s).
# Falls back to running without timeout if neither timeout nor gtimeout is available.
# Usage: git_with_timeout git fetch origin --quiet
git_with_timeout() {
  local timeout_secs="${GIT_NETWORK_TIMEOUT:-30}"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_secs" "$@"
  else
    "$@"
  fi
}

# Minimal JSON escaping for double-quotes, backslashes, and control characters.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# --- JSON Builder Helpers ---
# Build JSON objects and arrays with proper comma handling.

# Print a JSON string field: "key": "escaped_value"
# Usage: json_str "key" "value"
json_str() { printf '"%s": "%s"' "$1" "$(json_escape "$2")"; }

# Print a JSON literal field: "key": value (for numbers, booleans, null).
# Caller must ensure value is a valid JSON literal — no validation is done.
# Usage: json_raw "key" true   |   json_raw "count" 42   |   json_raw "val" null
json_raw() { printf '"%s": %s' "$1" "$2"; }

# Array/object delimiters.
# json_open_arr automatically resets the comma tracker so json_comma
# works correctly without a separate json_comma_reset call.
json_open_arr()  { _JSON_FIRST=true; printf '[\n'; }
json_close_arr() { printf '\n]\n'; }
json_open_obj()  { printf '{\n'; }
json_close_obj() { printf '\n}\n'; }

# Comma separator with first-element tracking.
# Automatically reset by json_open_arr. Call json_comma_reset manually
# only when reusing the tracker outside an array (e.g. nested arrays).
_JSON_FIRST=true
json_comma_reset() { _JSON_FIRST=true; }
json_comma() {
  if [[ "$_JSON_FIRST" == "true" ]]; then
    _JSON_FIRST=false
  else
    printf ',\n'
  fi
}

# Output a JSON error object and exit.
# Usage: json_error "message" [exit_code]
json_error() {
  printf '{%s}\n' "$(json_str error "$1")"
  exit "${2:-1}"
}
