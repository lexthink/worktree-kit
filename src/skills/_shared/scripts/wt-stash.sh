#!/usr/bin/env bash
# wt-stash.sh - Manage stashes per worktree
# Usage: wt-stash.sh <command> [worktree_name] [args...] [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-stash.sh - Worktree-aware stash management

USAGE:
  wt-stash.sh <command> [worktree_name] [options]

COMMANDS:
  list [worktree]      List stashes (optionally filtered by worktree)
  save <worktree> [msg] Save current changes to stash with worktree prefix
  pop <worktree>       Pop latest stash for this worktree
  apply <worktree> [n] Apply stash n for this worktree (default: latest)
  drop <worktree> [n]  Drop stash n for this worktree
  show <worktree> [n]  Show stash content
  move <worktree> <new_worktree> [n] Move stash to a different worktree tag

OPTIONS:
  --json              Output in JSON format (for list command)
  -h, --help          Show this help

STASH FORMAT:
  Stashes are prefixed with [worktree:NAME] for identification
EOF
}

REPO_ROOT=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"

[[ -z "$REPO_ROOT" ]] && REPO_ROOT=$(find_repo_root "$PWD" pwd)
OUTPUT_JSON=false

if [[ $# -eq 0 ]]; then show_help; exit 1; fi

COMMAND="$1"
shift

case "$COMMAND" in
  -h|--help) show_help; exit 0 ;;
esac

WORKTREE_NAME=""
MESSAGE=""
STASH_INDEX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_JSON=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    *)
      if [[ -z "$WORKTREE_NAME" ]]; then WORKTREE_NAME="$1"
      elif [[ -z "$MESSAGE" && -z "$STASH_INDEX" ]]; then
        if [[ "$1" =~ ^[0-9]+$ ]]; then STASH_INDEX="$1"
        else MESSAGE="$1"; fi
      fi
      shift
      ;;
  esac
done

case "$COMMAND" in
  list)
    stash_list=$(git stash list --format="%gd|%gs" 2>/dev/null || git -C "$REPO_ROOT" stash list --format="%gd|%gs" 2>/dev/null || echo "")

    if [[ "$OUTPUT_JSON" == "true" ]]; then
      echo "["
      first=true
      echo "$stash_list" | while IFS='|' read -r ref message; do
        [[ -z "$ref" ]] && continue
        if [[ -n "$WORKTREE_NAME" ]] && [[ ! "$message" =~ \[worktree:$WORKTREE_NAME\] ]]; then continue; fi
        [[ "$first" == "false" ]] && echo ","
        first=false
        index="0"; [[ "$ref" =~ stash@\{([0-9]+)\} ]] && index="${BASH_REMATCH[1]}"
        worktree=""; [[ "$message" =~ \[worktree:([^\]]+)\] ]] && { worktree="${BASH_REMATCH[1]}"; message="${message#*] }"; }
        printf '  {"index": %s, "ref": "%s", "worktree": "%s", "message": "%s"}' \
          "$index" "$(json_escape "$ref")" "$(json_escape "$worktree")" "$(json_escape "$message")"
      done
      printf '%b\n' "\n]"
    else
      print_header "WORKTREE STASHES"
      printf '%b\n' "${BOLD}INDEX  WORKTREE     MESSAGE${NC}"
      echo "------------------------------------------------------------"
      echo "$stash_list" | while IFS='|' read -r ref message; do
        [[ -z "$ref" ]] && continue
        if [[ -n "$WORKTREE_NAME" ]] && [[ ! "$message" =~ \[worktree:$WORKTREE_NAME\] ]]; then continue; fi
        index="0"; [[ "$ref" =~ stash@\{([0-9]+)\} ]] && index="${BASH_REMATCH[1]}"
        worktree="-"; worktree_display="-"
        if [[ "$message" =~ \[worktree:([^\]]+)\] ]]; then
          worktree="${BASH_REMATCH[1]}"; message="${message#*] }"; worktree_display="${CYAN}$worktree${NC}"
        fi
        printf "%-6s %-21b %s\n" "${YELLOW}$index${NC}" "$worktree_display" "$message"
      done
    fi
    ;;

  save)
    [[ -z "$WORKTREE_NAME" ]] && { echo "Error: worktree name required" >&2; exit 1; }
    STASH_MSG="[worktree:$WORKTREE_NAME] ${MESSAGE:-WIP}"
    git stash push -u -m "$STASH_MSG"
    echo "✓ Stashed changes for $WORKTREE_NAME"
    ;;

  pop|apply|show)
    [[ -z "$WORKTREE_NAME" ]] && { echo "Error: worktree name required" >&2; exit 1; }
    TARGET_STASH=""
    if [[ -n "$STASH_INDEX" ]]; then TARGET_STASH="stash@{$STASH_INDEX}"
    else
      while IFS='|' read -r ref message; do
        if [[ "$message" =~ \[worktree:$WORKTREE_NAME\] ]]; then TARGET_STASH="$ref"; break; fi
      done < <(git stash list --format="%gd|%gs" 2>/dev/null || git -C "$REPO_ROOT" stash list --format="%gd|%gs" 2>/dev/null || echo "")
    fi
    [[ -z "$TARGET_STASH" ]] && { echo "Error: No stash found for $WORKTREE_NAME" >&2; exit 1; }
    case "$COMMAND" in
      pop) git stash pop "$TARGET_STASH" ;;
      apply) git stash apply "$TARGET_STASH" ;;
      show) git stash show -p "$TARGET_STASH" ;;
    esac
    ;;

  drop)
    [[ -z "$WORKTREE_NAME" ]] && { echo "Error: worktree name required" >&2; exit 1; }
    TARGET_STASH=""
    if [[ -n "$STASH_INDEX" ]]; then TARGET_STASH="stash@{$STASH_INDEX}"
    else
      while IFS='|' read -r ref message; do
        if [[ "$message" =~ \[worktree:$WORKTREE_NAME\] ]]; then TARGET_STASH="$ref"; break; fi
      done < <(git stash list --format="%gd|%gs" 2>/dev/null || git -C "$REPO_ROOT" stash list --format="%gd|%gs" 2>/dev/null || echo "")
    fi
    [[ -z "$TARGET_STASH" ]] && { echo "Error: No stash found for $WORKTREE_NAME" >&2; exit 1; }
    git stash drop "$TARGET_STASH"
    echo "✓ Dropped stash $TARGET_STASH"
    ;;

  move)
    [[ -z "$WORKTREE_NAME" ]] && { echo "Error: current worktree name required" >&2; exit 1; }
    NEW_WORKTREE="$MESSAGE"
    [[ -z "$NEW_WORKTREE" ]] && { echo "Error: target worktree name required" >&2; exit 1; }
    TARGET_STASH=""; STASH_MSG=""
    while IFS='|' read -r ref message; do
      if [[ "$message" =~ \[worktree:$WORKTREE_NAME\] ]]; then TARGET_STASH="$ref"; STASH_MSG="${message#*] }"; break; fi
    done < <(git stash list --format="%gd|%gs" 2>/dev/null || git -C "$REPO_ROOT" stash list --format="%gd|%gs" 2>/dev/null || echo "")
    [[ -z "$TARGET_STASH" ]] && { echo "Error: No stash found for $WORKTREE_NAME" >&2; exit 1; }
    echo "Moving stash from $WORKTREE_NAME to $NEW_WORKTREE..."
    git stash apply "$TARGET_STASH" >/dev/null
    git stash drop "$TARGET_STASH" >/dev/null
    NEW_MSG="[worktree:$NEW_WORKTREE] $STASH_MSG"
    git stash push -u -m "$NEW_MSG" >/dev/null
    printf '%b\n' "${GREEN}✓ Stash moved to $NEW_WORKTREE${NC}"
    ;;
  *) echo "Error: Unknown command '$COMMAND'" >&2; show_help; exit 1 ;;
esac
