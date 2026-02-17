#!/usr/bin/env bash
# wt-parse.sh - Shared worktree list parsing functions
# Source this file to get list_worktrees and find_worktree.
# Requires: $REPO_ROOT to be set before calling.

# list_worktrees - List all non-bare worktrees
# Output: one line per worktree as path|folder|branch
#   branch is the branch name, or "detached" if HEAD is detached
list_worktrees() {
  local wt_path="" wt_branch="" is_bare="false" is_detached="false"
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+) ]]; then
      wt_path="${BASH_REMATCH[1]}"
      wt_branch=""
      is_bare="false"
      is_detached="false"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+) ]]; then
      wt_branch="${BASH_REMATCH[1]}"
    elif [[ "$line" == "detached" ]]; then
      is_detached="true"
    elif [[ "$line" == "bare" ]]; then
      is_bare="true"
    elif [[ -z "$line" && -n "$wt_path" ]]; then
      if [[ "$is_bare" == "true" ]]; then
        wt_path=""
        continue
      fi
      local branch="$wt_branch"
      if [[ "$is_detached" == "true" || -z "$branch" ]]; then
        branch="detached"
      fi
      printf '%s|%s|%s\n' "$wt_path" "$(basename "$wt_path")" "$branch"
      wt_path=""
    fi
  done < <(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null; echo "")
}

# find_worktree - Find a single worktree by folder name, branch, or path
# Usage:
#   find_worktree --folder <name>   Match by folder name (basename)
#   find_worktree --branch <name>   Match by branch name
#   find_worktree <name>            Match by folder, then path, then branch
# Output: path|folder|branch (exit 0 on match, exit 1 if not found)
find_worktree() {
  local mode="auto" search=""
  case "${1:-}" in
    --folder) mode="folder"; search="$2" ;;
    --branch) mode="branch"; search="$2" ;;
    *) search="$1" ;;
  esac
  [[ -z "$search" ]] && return 1

  local path folder branch
  local branch_match=""

  while IFS='|' read -r path folder branch; do
    case "$mode" in
      folder)
        [[ "$folder" == "$search" ]] && { echo "$path|$folder|$branch"; return 0; }
        ;;
      branch)
        [[ "$branch" == "$search" ]] && { echo "$path|$folder|$branch"; return 0; }
        ;;
      auto)
        [[ "$folder" == "$search" ]] && { echo "$path|$folder|$branch"; return 0; }
        [[ "$path" == "$search" ]] && { echo "$path|$folder|$branch"; return 0; }
        [[ -z "$branch_match" && "$branch" == "$search" ]] && branch_match="$path|$folder|$branch"
        ;;
    esac
  done < <(list_worktrees)

  if [[ -n "$branch_match" ]]; then
    echo "$branch_match"
    return 0
  fi
  return 1
}
