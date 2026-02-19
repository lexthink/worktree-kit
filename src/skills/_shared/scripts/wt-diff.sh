#!/usr/bin/env bash
# wt-diff.sh - Show a summary of changes in a worktree
# Usage: wt-diff.sh [FOLDER] [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-diff.sh - Show a summary of changes in a worktree

USAGE:
  wt-diff.sh [FOLDER] [options]

ARGUMENTS:
  FOLDER              Worktree folder name (default: current directory)

OPTIONS:
  --staged            Show only staged changes
  --repo PATH         Repository root (auto-detected if omitted)
  --json              Output result in JSON format
  -h, --help          Show this help

EXAMPLES:
  wt-diff.sh ABC-1234
  wt-diff.sh --staged
  wt-diff.sh ABC-1234 --json
EOF
  exit 0
}

# --- Argument parsing ---
FOLDER=""
REPO_ROOT=""
OUTPUT_JSON=false
STAGED_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO_ROOT="$2"; shift 2 ;;
    --json)    OUTPUT_JSON=true; shift ;;
    --staged)  STAGED_ONLY=true; shift ;;
    -h|--help) show_help ;;
    -*)        echo "Error: Unknown option '$1'" >&2; exit 1 ;;
    *)         [[ -z "$FOLDER" ]] && FOLDER="$1"; shift ;;
  esac
done

# --- Resolve repo root ---
if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi

# --- Find worktree path ---
wt_path=""
if [[ -z "$FOLDER" ]]; then
  # Use current directory
  wt_path="$PWD"
  FOLDER=$(basename "$wt_path")
else
  if wt_info=$(find_worktree --folder "$FOLDER"); then
    IFS='|' read -r wt_path _ _ <<< "$wt_info"
  fi
fi

if [[ -z "$wt_path" || ! -d "$wt_path" ]]; then
  [[ "$OUTPUT_JSON" == "true" ]] && json_error "Worktree not found: $FOLDER"
  printf '%b\n' "$icon_fail Worktree not found: $FOLDER" >&2
  exit 1
fi

# --- Gather diff stats ---
if [[ "$STAGED_ONLY" == "true" ]]; then
  diff_stat=$(git -C "$wt_path" diff --cached --stat 2>/dev/null || echo "")
  diff_numstat=$(git -C "$wt_path" diff --cached --numstat 2>/dev/null || echo "")
else
  diff_stat=$(git -C "$wt_path" diff --stat 2>/dev/null || echo "")
  diff_numstat=$(git -C "$wt_path" diff --numstat 2>/dev/null || echo "")
fi

# Untracked files
untracked=$(git -C "$wt_path" ls-files --others --exclude-standard 2>/dev/null || echo "")
untracked_count=0
[[ -n "$untracked" ]] && untracked_count=$(echo "$untracked" | wc -l | tr -d ' ')

# Parse numstat for totals
total_added=0
total_removed=0
file_count=0
declare -a files_data=()

while IFS=$'\t' read -r added removed filename; do
  [[ -z "$filename" ]] && continue
  # Handle binary files (shown as - -)
  if [[ "$added" == "-" ]]; then added=0; fi
  if [[ "$removed" == "-" ]]; then removed=0; fi
  total_added=$((total_added + added))
  total_removed=$((total_removed + removed))
  file_count=$((file_count + 1))
  files_data+=("$filename|$added|$removed")
done <<< "$diff_numstat"

# Staged changes (if not --staged mode, also show staged separately)
staged_count=0
if [[ "$STAGED_ONLY" != "true" ]]; then
  staged_count=$(git -C "$wt_path" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
fi

# --- Output ---
if [[ "$OUTPUT_JSON" == "true" ]]; then
  json_open_obj
  printf '  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n' \
    "$(json_str folder "$FOLDER")" "$(json_raw files_changed "$file_count")" \
    "$(json_raw lines_added "$total_added")" "$(json_raw lines_removed "$total_removed")" \
    "$(json_raw staged_files "$staged_count")" "$(json_raw untracked_files "$untracked_count")"
  printf '  "files": [\n'
  _JSON_FIRST=true
  for entry in "${files_data[@]}"; do
    IFS='|' read -r fname added removed <<< "$entry"
    json_comma
    printf '    {%s, %s, %s}' \
      "$(json_str file "$fname")" "$(json_raw added "$added")" "$(json_raw removed "$removed")"
  done
  printf '\n  ]\n'
  printf '}\n'
else
  print_header "DIFF SUMMARY: $FOLDER"

  if [[ "$file_count" -eq 0 && "$untracked_count" -eq 0 && "$staged_count" -eq 0 ]]; then
    printf '%b\n' "  $icon_clean No changes"
  else
    printf '%b\n' "  Files changed:  ${BOLD}$file_count${NC}"
    printf '%b\n' "  Lines added:    ${GREEN}+$total_added${NC}"
    printf '%b\n' "  Lines removed:  ${RED}-$total_removed${NC}"
    [[ "$staged_count" -gt 0 ]] && printf '%b\n' "  Staged files:   ${YELLOW}$staged_count${NC}"
    [[ "$untracked_count" -gt 0 ]] && printf '%b\n' "  Untracked:      ${CYAN}$untracked_count${NC}"

    if [[ "$file_count" -gt 0 ]]; then
      echo ""
      printf "  ${BOLD}%-40s  %8s  %8s${NC}\n" "FILE" "ADDED" "REMOVED"
      printf "  %s\n" "$(printf '%.0s-' $(seq 1 60))"
      for entry in "${files_data[@]}"; do
        IFS='|' read -r fname added removed <<< "$entry"
        # Truncate long filenames
        display_name="$fname"
        [[ ${#display_name} -gt 40 ]] && display_name="...${display_name: -37}"
        printf "  %-40s  ${GREEN}%+8s${NC}  ${RED}%+8s${NC}\n" "$display_name" "+$added" "-$removed"
      done
    fi
  fi
fi
