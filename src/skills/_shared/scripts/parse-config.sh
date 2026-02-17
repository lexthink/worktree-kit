#!/usr/bin/env bash
# parse-config.sh - Internal config parser for .worktreeconfig
# Usage: parse-config.sh <key> [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
show_help() {
  cat <<EOF
parse-config.sh - Internal .worktreeconfig parser

USAGE:
  parse-config.sh <key> [--repo PATH]

KEYS SUPPORTED:
  worktrees.default_branch
  worktrees.directory
  defaults.issue_tracker
EOF
  exit 0
}

KEY=""
REPO_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) KEY="$1"; shift ;;
  esac
done

[[ -z "$KEY" ]] && show_help
REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"
CONFIG_FILE="$REPO_ROOT/.worktreeconfig"

[[ ! -f "$CONFIG_FILE" ]] && exit 1

SECTION_REQ="${KEY%.*}"
PROP_REQ="${KEY#*.}"

current_section=""
while IFS= read -r line || [[ -n "$line" ]]; do
  # Remove comments and trim leading/trailing whitespace
  line=$(echo "$line" | sed 's/#.*//' | xargs)
  [[ -z "$line" ]] && continue

  if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
    current_section="${BASH_REMATCH[1]}"
  elif [[ "$current_section" == "$SECTION_REQ" && "$line" == *"="* ]]; then
    key_found=$(echo "${line%%=*}" | xargs)
    if [[ "$key_found" == "$PROP_REQ" ]]; then
      val_found=$(echo "${line#*=}" | xargs)
      echo "$val_found" | tr -d '"' | tr -d "'"
      exit 0
    fi
  fi
done < "$CONFIG_FILE"

exit 1
