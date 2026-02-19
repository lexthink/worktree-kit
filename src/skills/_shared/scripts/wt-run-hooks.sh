#!/usr/bin/env bash
# wt-run-hooks.sh - Execute hooks defined in .worktreeconfig
# Usage: wt-run-hooks.sh <hook_type> [worktree_path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-run-hooks.sh - Execute custom hooks from .worktreeconfig

USAGE:
  wt-run-hooks.sh <hook_type> [worktree_path] [options]

HOOK TYPES:
  post-create, pre-commit

OPTIONS:
  --repo PATH      Repository root
  -h, --help       Show this help
EOF
  exit 0
}

HOOK_TYPE=""
WORKTREE_PATH=""
REPO_ROOT=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) show_help ;;
    *)
      if [[ -z "$HOOK_TYPE" ]]; then HOOK_TYPE="$1"
      elif [[ -z "$WORKTREE_PATH" ]]; then WORKTREE_PATH="$1"; fi
      shift ;;
  esac
done

[[ -z "$HOOK_TYPE" ]] && show_help
WORKTREE_PATH="${WORKTREE_PATH:-$PWD}"
if [[ ! -d "$WORKTREE_PATH" ]]; then echo "Error: Path not found: $WORKTREE_PATH" >&2; exit 1; fi

REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$WORKTREE_PATH" pwd)}"
CONFIG_FILE="$REPO_ROOT/.worktreeconfig"

[[ ! -f "$CONFIG_FILE" ]] && exit 0

# Extract hook command via git config
hook_cmd=$(git config -f "$CONFIG_FILE" "hooks.$HOOK_TYPE" 2>/dev/null) || exit 0
HOOKS=("$hook_cmd")

print_header "RUNNING HOOKS: $HOOK_TYPE"
FAILED=false
for cmd in "${HOOKS[@]}"; do
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%b\n' "  $icon_info DRY-RUN Would execute: ${CYAN}$cmd${NC}"
    continue
  fi
  printf '%b\n' "  $icon_sync Executing: ${CYAN}$cmd${NC}"
  # Run in isolated bash instead of eval to prevent hooks from
  # accessing or modifying the parent script's internal state.
  if ! (cd "$WORKTREE_PATH" && bash -c "$cmd"); then
    printf '%b\n' "  $icon_fail Failed: $cmd"
    FAILED=true
  fi
done

[[ "$FAILED" == "true" ]] && exit 1
exit 0
