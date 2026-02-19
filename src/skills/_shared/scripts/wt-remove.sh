#!/usr/bin/env bash
# wt-remove.sh - Safely remove a git worktree and optionally its branch
# Usage: wt-remove.sh <FOLDER> [--force] [--delete-branch] [--dry-run] [--repo PATH] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
wt-remove.sh - Safely remove a git worktree

USAGE:
  wt-remove.sh <FOLDER> [options]

ARGUMENTS:
  FOLDER              Worktree folder name to remove

OPTIONS:
  --force             Force removal even with uncommitted changes
  --delete-branch     Also delete the local branch after removal
  --dry-run           Show what would be removed without doing it
  --repo PATH         Repository root (auto-detected if omitted)
  --json              Output result in JSON format
  -h, --help          Show this help

EXIT CODES:
  0   Worktree removed successfully
  1   Error (not found, git failure)
  2   Has uncommitted changes (needs --force)

EXAMPLES:
  wt-remove.sh ABC-1234
  wt-remove.sh ABC-1234 --force --delete-branch
  wt-remove.sh ABC-1234 --json
EOF
  exit 0
}

# --- Argument parsing ---
FOLDER=""
FORCE=false
DELETE_BRANCH=false
DRY_RUN=false
REPO_ROOT=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)         FORCE=true; shift ;;
    --delete-branch) DELETE_BRANCH=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --repo)          REPO_ROOT="$2"; shift 2 ;;
    --json)          OUTPUT_JSON=true; shift ;;
    -h|--help)       show_help ;;
    -*)              echo "Error: Unknown option '$1'" >&2; exit 1 ;;
    *)               [[ -z "$FOLDER" ]] && FOLDER="$1"; shift ;;
  esac
done

if [[ -z "$FOLDER" ]]; then
  echo "Error: folder name is required" >&2
  exit 1
fi

# --- Resolve repo root ---
if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT=$(find_repo_root); then
    printf '%b\n' "$icon_fail Error: Not in a git repository" >&2
    exit 1
  fi
fi
[[ -d "$REPO_ROOT/.git" ]] || { printf '%b\n' "$icon_fail Error: Not a bare git repository" >&2; exit 1; }

# --- Resolve default branch (protect it) ---
DEFAULT_BRANCH=$("$SCRIPT_DIR/parse-config.sh" worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")

# --- Find the worktree ---
wt_path=""
wt_branch=""

if wt_info=$(find_worktree --folder "$FOLDER"); then
  IFS='|' read -r wt_path _ wt_branch <<< "$wt_info"
fi

if [[ -z "$wt_path" ]]; then
  [[ "$OUTPUT_JSON" == "true" ]] && json_error "Worktree not found: $FOLDER"
  printf '%b\n' "$icon_fail Worktree not found: $FOLDER" >&2
  exit 1
fi

# --- Protection: refuse to remove default branch worktree ---
if [[ "$wt_branch" == "$DEFAULT_BRANCH" && "$FORCE" != "true" ]]; then
  [[ "$OUTPUT_JSON" == "true" ]] && json_error "Cannot remove default branch worktree ($DEFAULT_BRANCH). Use --force to override."
  printf '%b\n' "$icon_fail Cannot remove default branch worktree ($DEFAULT_BRANCH). Use --force to override." >&2
  exit 1
fi

# --- Safety check: uncommitted changes ---
HAS_CHANGES=false
CHANGED_FILES=0
if [[ -d "$wt_path" ]]; then
  status=$(get_wt_status "$wt_path")
  if [[ "$status" == "dirty" ]]; then
    HAS_CHANGES=true
    CHANGED_FILES=$(git -C "$wt_path" status --short 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

if [[ "$HAS_CHANGES" == "true" && "$FORCE" != "true" ]]; then
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    json_open_obj
    printf '  %s,\n  %s,\n  %s,\n  %s' \
      "$(json_str error "uncommitted_changes")" "$(json_str folder "$FOLDER")" \
      "$(json_raw changed_files "$CHANGED_FILES")" "$(json_str hint "Use --force to override")"
    json_close_obj
  else
    printf '%b\n' "$icon_warn Worktree ${BOLD}$FOLDER${NC} has $CHANGED_FILES uncommitted change(s)."
    printf '%b\n' "  Removing it will ${RED}lose these changes${NC}."
    printf '%b\n' "  Use ${BOLD}--force${NC} to remove anyway."
  fi
  exit 2
fi

# --- Dry run ---
if [[ "$DRY_RUN" == "true" ]]; then
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    json_open_obj
    printf '  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s' \
      "$(json_raw dry_run true)" "$(json_str folder "$FOLDER")" \
      "$(json_str path "$wt_path")" "$(json_str branch "$wt_branch")" \
      "$(json_raw has_changes "$HAS_CHANGES")" "$(json_raw changed_files "$CHANGED_FILES")" \
      "$(json_raw would_delete_branch "$DELETE_BRANCH")"
    json_close_obj
  else
    printf '%b\n' "\n${BOLD}${CYAN}DRY RUN — nothing will be removed${NC}"
    printf '%b\n' "Folder: ${CYAN}$FOLDER${NC}"
    printf '%b\n' "Path:   $wt_path"
    printf '%b\n' "Branch: ${MAGENTA}$wt_branch${NC}"
    [[ "$HAS_CHANGES" == "true" ]] && printf '%b\n' "Status: $icon_dirty ($CHANGED_FILES change(s))"
    [[ "$DELETE_BRANCH" == "true" ]] && printf '%b\n' "Branch: would be deleted"
  fi
  exit 0
fi

# --- Remove the worktree ---
if [[ "$FORCE" == "true" ]]; then
  git -C "$REPO_ROOT" worktree remove "$wt_path" --force
else
  git -C "$REPO_ROOT" worktree remove "$wt_path"
fi

# --- Optionally delete branch ---
BRANCH_DELETED=false
BRANCH_DELETE_ERROR=""
if [[ "$DELETE_BRANCH" == "true" && "$wt_branch" != "detached" && "$wt_branch" != "$DEFAULT_BRANCH" ]]; then
  if git -C "$REPO_ROOT" branch -d "$wt_branch" 2>/dev/null; then
    BRANCH_DELETED=true
  else
    # Branch not fully merged; try -D only if --force was used
    if [[ "$FORCE" == "true" ]]; then
      git -C "$REPO_ROOT" branch -D "$wt_branch" 2>/dev/null && BRANCH_DELETED=true
    else
      BRANCH_DELETE_ERROR="Branch '$wt_branch' is not fully merged. Use --force to force-delete."
    fi
  fi
fi

# --- Log operation ---
"$SCRIPT_DIR/wt-log.sh" worktree-remove "$FOLDER" "Branch: $wt_branch Deleted: $BRANCH_DELETED" --repo "$REPO_ROOT" 2>/dev/null || true

# --- Output ---
if [[ "$OUTPUT_JSON" == "true" ]]; then
  json_open_obj
  printf '  %s,\n  %s,\n  %s,\n  %s,\n  %s' \
    "$(json_str folder "$FOLDER")" "$(json_str branch "$wt_branch")" \
    "$(json_raw branch_deleted "$BRANCH_DELETED")" "$(json_raw had_changes "$HAS_CHANGES")" \
    "$(json_raw forced "$FORCE")"
  if [[ -n "$BRANCH_DELETE_ERROR" ]]; then
    printf ',\n  %s' "$(json_str branch_delete_error "$BRANCH_DELETE_ERROR")"
  fi
  json_close_obj
else
  printf '%b\n' "\n${BOLD}${GREEN}WORKTREE REMOVED${NC}"
  printf '%b\n' "Folder: ${CYAN}$FOLDER${NC}"
  branch_status="Kept"
  [[ "$BRANCH_DELETED" == "true" ]] && branch_status="Deleted"
  printf '%b\n' "Branch: ${MAGENTA}$wt_branch${NC} ($branch_status)"
  if [[ -n "$BRANCH_DELETE_ERROR" ]]; then
    printf '%b\n' "  $icon_warn $BRANCH_DELETE_ERROR"
  fi
fi
