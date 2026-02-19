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
  worktrees.default-branch
  worktrees.directory
  defaults.issue-tracker
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

git config -f "$CONFIG_FILE" "$KEY" 2>/dev/null || exit 1
