#!/usr/bin/env bash
# wt-candidates.sh - Find worktrees that are candidates for removal
# Usage: wt-candidates.sh [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/../../_shared/scripts" && pwd)"
source "$SHARED_DIR/ui-utils.sh"
source "$SHARED_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-candidates.sh - Identify worktrees safe to prune

USAGE:
  wt-candidates.sh [options]

OPTIONS:
  --repo PATH Repository root
  -h, --help  Show this help

IDENTIFICATION LOGIC:
  - MERGED: Branch is already merged into the default branch
  - GONE:   Branch has been deleted on the remote
EOF
  exit 0
}

REPO_ROOT=""
OUTPUT_FORMAT="text"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    -h|--help) show_help ;;
    *) REPO_ROOT="$1"; shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"

DEFAULT_BRANCH=$("$SHARED_DIR/parse-config.sh" worktrees.default_branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")
git_with_timeout git -C "$REPO_ROOT" fetch --prune --quiet 2>/dev/null || true

declare -a CANDIDATES=()

while IFS='|' read -r current_wt folder branch; do
  [[ "$branch" == "detached" || "$branch" == "$DEFAULT_BRANCH" ]] && continue

  is_merged="false"
  if git -C "$REPO_ROOT" merge-base --is-ancestor "$branch" "$DEFAULT_BRANCH" 2>/dev/null; then
    is_merged="true"
  fi
  is_gone="false"; [[ "$(git -C "$current_wt" branch -vv 2>/dev/null | grep "^\*")" == *": gone]"* ]] && is_gone="true"

  is_dirty="false"; [[ "$(get_wt_status "$current_wt")" == "dirty" ]] && is_dirty="true"

  if [[ "$is_dirty" == "false" ]]; then
    if [[ "$is_merged" == "true" ]]; then
      CANDIDATES+=("$folder|$branch|merged")
    elif [[ "$is_gone" == "true" ]]; then
      CANDIDATES+=("$folder|$branch|gone")
    fi
  fi
done < <(list_worktrees)

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  printf "[\n"
  first=true
  for entry in "${CANDIDATES[@]}"; do
    IFS='|' read -r folder branch reason <<< "$entry"
    [[ "$first" == "true" ]] && first=false || printf ",\n"
    printf '  {"folder": "%s", "branch": "%s", "reason": "%s"}' \
      "$(json_escape "$folder")" "$(json_escape "$branch")" "$(json_escape "$reason")"
  done
  printf "\n]\n"
  exit 0
fi

print_header "PRUNE CANDIDATES"
if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "  (none)"
  exit 0
fi

for entry in "${CANDIDATES[@]}"; do
  IFS='|' read -r folder branch reason <<< "$entry"
  if [[ "$reason" == "merged" ]]; then
    printf '%b\n' "  $icon_trash ${CYAN}$folder${NC} (merged into $DEFAULT_BRANCH)"
  elif [[ "$reason" == "gone" ]]; then
    printf '%b\n' "  $icon_trash ${YELLOW}$folder${NC} (gone on remote)"
  fi
done
