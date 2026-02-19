#!/usr/bin/env bash
# wt-list.sh - List all worktrees and their statuses
# Usage: wt-list.sh [--json|--short|--size] [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/../../_shared/scripts" && pwd)"
source "$SHARED_DIR/ui-utils.sh"
source "$SHARED_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-list.sh - List all worktrees and their current status

USAGE:
  wt-list.sh [options]

OPTIONS:
  --size      Show disk usage for each worktree (slower)
  --short     Show only worktree names
  --json      Output results in JSON format
  --repo PATH Repository root
  -h, --help  Show this help
EOF
  exit 0
}

# Defaults
OUTPUT_FORMAT="table"
REPO_ROOT=""
SHOW_SIZE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_FORMAT="json"; shift ;;
    --short) OUTPUT_FORMAT="short"; shift ;;
    --size) SHOW_SIZE=true; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) REPO_ROOT="$1"; shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root)}"

# Get config
DEFAULT_BRANCH=$("$SHARED_DIR/parse-config.sh" worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")

# Scan worktrees
WORKTREES=()
w_folder=8; w_branch=6 # Dynamic widths

while IFS='|' read -r current_wt folder branch; do
  [[ "$current_wt" == "$REPO_ROOT" ]] && folder="main"
  [[ ${#folder} -gt $w_folder ]] && w_folder=${#folder}
  [[ ${#branch} -gt $w_branch ]] && w_branch=${#branch}

  status=$(get_wt_status "$current_wt")

  last=$(git -C "$current_wt" log -1 --format="%ar" 2>/dev/null || echo "no activity")
  ahead=0; behind=0
  if [[ "$branch" != "detached" ]] && git -C "$REPO_ROOT" rev-parse --verify "${branch}@{u}" >/dev/null 2>&1; then
    counts=$(git -C "$REPO_ROOT" rev-list --left-right --count "${branch}...${branch}@{u}" 2>/dev/null || echo "0 0")
    ahead=$(echo "$counts" | awk '{print $1}'); behind=$(echo "$counts" | awk '{print $2}')
  fi
  size="-"
  if [[ "$SHOW_SIZE" == "true" ]]; then
    size=$(du -sh "$current_wt" 2>/dev/null | awk '{print $1}' || echo "-")
  fi
  WORKTREES+=("$folder|$current_wt|$branch|$status|$ahead|$behind|$size|$last")
done < <(list_worktrees)
[[ $w_folder -gt 30 ]] && w_folder=30; [[ $w_branch -gt 40 ]] && w_branch=40

output_table() {
  # Header
  printf "${BOLD}%-${w_folder}s  %-${w_branch}s  %-10s  %-6s  %-6s  %-8s  %s${NC}\n" "WORKTREE" "BRANCH" "STATUS" "AHEAD" "BEHIND" "SIZE" "ACTIVITY"
  printf "%s\n" "$(printf '%.0s-' $(seq 1 $((w_folder + w_branch + 55))))"
  for entry in "${WORKTREES[@]}"; do
    IFS='|' read -r folder _ branch status ahead behind size last <<< "$entry"
    f_disp="$folder"; [[ "$branch" == "$DEFAULT_BRANCH" ]] && f_disp="$folder $icon_star"

    # Use unified icon
    s_disp=$(get_wt_icon "$status")

    a_disp="-"; [[ "$ahead" -gt 0 ]] && a_disp="${GREEN}↑$ahead${NC}"
    b_disp="-"; [[ "$behind" -gt 0 ]] && b_disp="${RED}↓$behind${NC}"

    printf "%-${w_folder}b  %-${w_branch}b  %-10b  %-6b  %-6b  %-8b  %s\n" \
      "${BOLD}$f_disp${NC}" "${CYAN}$branch${NC}" "$s_disp" "$a_disp" "$b_disp" "${MAGENTA}$size${NC}" "${BLUE}$last${NC}"
  done
}
case "$OUTPUT_FORMAT" in
  json)
    printf "[\n"
    first=true
    for entry in "${WORKTREES[@]}"; do
      IFS='|' read -r folder path branch status ahead behind size last <<< "$entry"
      dirty="false"
      [[ "$status" == "dirty" ]] && dirty="true"
      if [[ "$first" == "true" ]]; then
        first=false
      else
        printf ",\n"
      fi
      printf '  {"folder": "%s", "path": "%s", "branch": "%s", "status": "%s", "dirty": %s, "ahead": %s, "behind": %s, "size": "%s", "activity": "%s"}' \
        "$(json_escape "$folder")" "$(json_escape "$path")" "$(json_escape "$branch")" "$(json_escape "$status")" "$dirty" "$ahead" "$behind" "$(json_escape "$size")" "$(json_escape "$last")"
    done
    printf "\n]\n"
    ;;
  short) for e in "${WORKTREES[@]}"; do IFS='|' read -r f _ b _ <<< "$e"; echo "$f ($b)"; done ;;
  *) output_table ;;
esac
