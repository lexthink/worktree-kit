#!/usr/bin/env bash
# wt-sync.sh - Sync reference worktrees with remote
# Usage: wt-sync.sh [branch_or_folder1 branch_or_folder2 ...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/../../_shared/scripts" && pwd)"
source "$SHARED_DIR/ui-utils.sh"
source "$SHARED_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-sync.sh - Sync worktree branches with remote

USAGE:
  wt-sync.sh [branch_or_folder...] [options]

OPTIONS:
  --repo PATH    Repository root
  -h, --help     Show this help
EOF
  exit 0
}

REPO_ROOT=""
OUTPUT_FORMAT="text"
declare -a TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    -h|--help) show_help ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  DEFAULT_BRANCH=$("$SHARED_DIR/parse-config.sh" worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")
  TARGETS=("$DEFAULT_BRANCH")
fi

if [[ "$OUTPUT_FORMAT" != "json" ]]; then
  print_header "SYNC STATUS"
  printf '%b\n' "Fetching from origin... $icon_sync" >&2
fi
git_with_timeout git -C "$REPO_ROOT" fetch --all --prune --quiet 2>/dev/null || true

# Map Worktrees (by branch AND by folder name)
declare -A BRANCH_TO_PATH=()
declare -A FOLDER_TO_PATH=()
declare -A PATH_TO_BRANCH=()

while IFS='|' read -r wt_p folder branch; do
  FOLDER_TO_PATH["$folder"]="$wt_p"
  if [[ "$branch" != "detached" ]]; then
    BRANCH_TO_PATH["$branch"]="$wt_p"
    PATH_TO_BRANCH["$wt_p"]="$branch"
  fi
done < <(list_worktrees)

declare -a RESULTS=()
for target in "${TARGETS[@]}"; do
  # Try finding by branch name first, then by folder name
  wt_path="${BRANCH_TO_PATH[$target]:-}"
  if [[ -z "$wt_path" ]]; then
    wt_path="${FOLDER_TO_PATH[$target]:-}"
  fi

  if [[ -z "$wt_path" ]]; then
    [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_fail $target: No worktree or branch found"
    RESULTS+=("$target|not-found")
    continue
  fi

  # Get the actual branch for this path (in case target was a folder name)
  branch="${PATH_TO_BRANCH[$wt_path]:-}"
  if [[ -z "$branch" || "$branch" == "detached" ]]; then
    [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_warn $target: Detached HEAD (cannot sync)"
    RESULTS+=("$target|detached")
    continue
  fi

  # Use unified status check for dirty state
  if [[ "$(get_wt_status "$wt_path")" == "dirty" ]]; then
    [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_warn $branch: $icon_dirty (skipping due to changes)"
    RESULTS+=("$branch|skipped-dirty")
    continue
  fi

  if ! git -C "$wt_path" remote get-url origin >/dev/null 2>&1; then
    [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_warn $branch: No origin remote (skipping)"
    RESULTS+=("$branch|no-remote")
    continue
  fi

  # Pull
  if out=$(git -C "$wt_path" pull origin "$branch" --ff-only 2>&1); then
    if [[ "$out" == *"Already up to date"* ]]; then
      [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_pass $branch: ${GREEN}Already up to date${NC}"
      RESULTS+=("$branch|up-to-date")
    else
      [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_sync $branch: ${CYAN}Updated successfully${NC}"
      RESULTS+=("$branch|updated")
    fi
  else
    [[ "$OUTPUT_FORMAT" != "json" ]] && printf '%b\n' "  $icon_fail $branch: ${RED}Pull failed${NC}"
    RESULTS+=("$branch|failed")
  fi
done

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  json_open_arr
  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r branch status <<< "$entry"
    json_comma
    printf '  {%s, %s}' "$(json_str branch "$branch")" "$(json_str status "$status")"
  done
  json_close_arr
fi
