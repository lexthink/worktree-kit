#!/usr/bin/env bash
# wt-merge-status.sh - Show merge status of all worktree branches against default branch
# Usage: wt-merge-status.sh [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-merge-status.sh - Show merge status of all worktree branches

USAGE:
  wt-merge-status.sh [options]

OPTIONS:
  --repo PATH         Repository root (auto-detected if omitted)
  --json              Output result in JSON format
  -h, --help          Show this help

EXAMPLES:
  wt-merge-status.sh
  wt-merge-status.sh --json
  wt-merge-status.sh --repo /path/to/repo
EOF
  exit 0
}

# --- Argument parsing ---
REPO_ROOT=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    -h|--help) show_help ;;
    -*) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
    *)  shift ;;
  esac
done

# --- Resolve repo root ---
if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi

# --- Get default branch ---
DEFAULT_BRANCH=$("$SCRIPT_DIR/parse-config.sh" worktrees.default_branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")

# --- Scan worktrees ---
declare -a results=()

while IFS='|' read -r _wt_path folder branch; do
  if [[ "$branch" == "detached" || "$branch" == "$DEFAULT_BRANCH" ]]; then
    results+=("$folder|$branch|skip|0|0")
  else
    # Check if branch is merged into default branch
    merge_base=$(git -C "$REPO_ROOT" merge-base "$branch" "$DEFAULT_BRANCH" 2>/dev/null || echo "")
    branch_tip=$(git -C "$REPO_ROOT" rev-parse "$branch" 2>/dev/null || echo "")

    branch_only=0
    default_only=0
    if [[ -n "$merge_base" && "$merge_base" == "$branch_tip" ]]; then
      merge_status="merged"
    elif [[ -n "$merge_base" ]]; then
      branch_only=$(git -C "$REPO_ROOT" rev-list --count "$merge_base..$branch" 2>/dev/null || echo "0")
      default_only=$(git -C "$REPO_ROOT" rev-list --count "$merge_base..$DEFAULT_BRANCH" 2>/dev/null || echo "0")
      merge_status="diverged"
    else
      merge_status="unknown"
    fi

    results+=("$folder|$branch|$merge_status|$branch_only|$default_only")
  fi
done < <(list_worktrees)

# --- Output ---
if [[ "$OUTPUT_JSON" == "true" ]]; then
  printf '[\n'
  first=true
  for entry in "${results[@]}"; do
    IFS='|' read -r folder branch status branch_commits default_commits <<< "$entry"
    [[ "$first" == "false" ]] && printf ',\n'
    first=false
    printf '  {"folder": "%s", "branch": "%s", "merge_status": "%s", "branch_commits": %s, "default_commits": %s}' \
      "$(json_escape "$folder")" "$(json_escape "$branch")" "$status" "$branch_commits" "$default_commits"
  done
  printf '\n]\n'
else
  print_header "MERGE STATUS (vs $DEFAULT_BRANCH)"

  w_folder=8
  w_branch=8
  for entry in "${results[@]}"; do
    IFS='|' read -r folder branch _ _ _ <<< "$entry"
    [[ ${#folder} -gt $w_folder ]] && w_folder=${#folder}
    [[ ${#branch} -gt $w_branch ]] && w_branch=${#branch}
  done
  [[ $w_folder -gt 30 ]] && w_folder=30
  [[ $w_branch -gt 40 ]] && w_branch=40

  printf "  ${BOLD}%-${w_folder}s  %-${w_branch}s  %-12s  %s${NC}\n" "WORKTREE" "BRANCH" "STATUS" "DETAILS"
  printf "  %s\n" "$(printf '%.0s-' $(seq 1 $((w_folder + w_branch + 30))))"

  for entry in "${results[@]}"; do
    IFS='|' read -r folder branch status branch_commits default_commits <<< "$entry"

    case "$status" in
      merged)
        s_icon="${GREEN}✓ merged${NC}"
        details="safe to remove"
        ;;
      diverged)
        s_icon="${YELLOW}⑂ diverged${NC}"
        details="${GREEN}+$branch_commits${NC} branch / ${RED}+$default_commits${NC} $DEFAULT_BRANCH"
        ;;
      skip)
        s_icon="${BLUE}— skip${NC}"
        details=""
        [[ "$branch" == "$DEFAULT_BRANCH" ]] && details="default branch"
        [[ "$branch" == "detached" ]] && details="detached HEAD"
        ;;
      *)
        s_icon="${RED}? unknown${NC}"
        details=""
        ;;
    esac

    printf "  %-${w_folder}b  %-${w_branch}b  %-12b  %b\n" \
      "${BOLD}$folder${NC}" "${CYAN}$branch${NC}" "$s_icon" "$details"
  done
fi
