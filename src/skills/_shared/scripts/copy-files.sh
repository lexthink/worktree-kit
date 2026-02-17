#!/usr/bin/env bash
# copy-files.sh - Copy files/directories into a worktree based on .worktreeconfig rules
# Usage: copy-files.sh <target_worktree_path> [--repo PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/wt-parse.sh"

show_help() {
  cat <<EOF
copy-files.sh - Sync configuration files to a new worktree

USAGE:
  copy-files.sh <target_path> [options]

OPTIONS:
  --repo PATH    Repository root
  -h, --help     Show this help

RULES (.worktreeconfig [copy] section):
  include = pattern [pattern ...]   Files or directories to copy (space-separated)
  exclude = path [path ...]         Exact paths to exclude, relative to repo root (space-separated)
                                    e.g. .env  mydir/file2.txt  mydir/sub/secret.json
EOF
  exit 0
}

TARGET_PATH=""
REPO_ROOT=""
DRY_RUN="false"
VERBOSE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --verbose) VERBOSE="true"; shift ;;
    -h|--help) show_help ;;
    *) [[ -z "$TARGET_PATH" ]] && TARGET_PATH="$1"; shift ;;
  esac
done

[[ -z "$TARGET_PATH" ]] && show_help
REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"
CONFIG_FILE="$REPO_ROOT/.worktreeconfig"
[[ -f "$CONFIG_FILE" ]] || exit 0

# Resolve paths
[[ "$TARGET_PATH" != /* ]] && TARGET_PATH="$REPO_ROOT/$TARGET_PATH"
[[ ! -d "$TARGET_PATH" ]] && { echo "Error: Target dir not found: $TARGET_PATH" >&2; exit 1; }

print_header "SYNCING ENVIRONMENT FILES"

# Parse rules (include/exclude support space-separated lists of files and directories)
declare -a includes=()
declare -a excludes=()

in_copy=false
while IFS='=' read -r key val || [[ -n "$key" ]]; do
  line=$(echo "$key" | xargs)
  [[ "$line" =~ ^\[copy\]$ ]] && { in_copy=true; continue; }
  [[ "$line" =~ ^\[.*\]$ ]] && { in_copy=false; continue; }
  [[ "$in_copy" == "false" || -z "$val" ]] && continue

  k=$(echo "$key" | xargs); v=$(echo "$val" | tr -d '"' | tr -d "'" | xargs)
  case "$k" in
    include|include_dirs) for token in $v; do includes+=("$token"); done ;;
    exclude|exclude_dirs) for token in $v; do excludes+=("$token"); done ;;
  esac
done < "$CONFIG_FILE"

# Build worktree exclusions so we don't copy files from sibling worktrees
WT_EXCLUDES=()
while IFS='|' read -r wt_path _ _; do
  [[ "$wt_path" == "$REPO_ROOT" ]] && continue
  WT_EXCLUDES+=(-not -path "$wt_path/*")
done < <(list_worktrees)

# Copy entries (auto-detect file vs directory)
# Note: ${arr[@]+${arr[@]}} is used instead of ${arr[@]} to safely handle empty
# arrays on bash 3.2 (macOS default) where set -u treats empty arrays as unbound.
for entry in "${includes[@]}"; do
  src="$REPO_ROOT/$entry"

  if [[ -d "$src" ]]; then
    # Directory: check if the directory itself is excluded (exact match)
    skip=false
    for exc in ${excludes[@]+"${excludes[@]}"}; do [[ "$entry" == "$exc" ]] && skip=true; done
    [[ "$skip" == "true" ]] && continue

    dest="$TARGET_PATH/$entry"
    if [[ "$DRY_RUN" == "true" ]]; then
      printf '%b\n' "  $icon_info DRY-RUN Folder: $entry"
      continue
    fi
    mkdir -p "$dest"
    if command -v rsync &>/dev/null; then
      # Build rsync exclude args: only excludes that target paths inside this directory
      rsync_excludes=(--exclude=".git")
      for exc in ${excludes[@]+"${excludes[@]}"}; do
        [[ "$exc" == "$entry/"* ]] && rsync_excludes+=(--exclude="/${exc#"$entry"/}")
      done
      rsync -a "${rsync_excludes[@]}" "$src/" "$dest/"
    else
      cp -Rp "$src/." "$dest/"
      # Remove excluded paths inside the copied directory
      for exc in ${excludes[@]+"${excludes[@]}"}; do
        [[ "$exc" == "$entry/"* ]] && [[ -e "$dest/${exc#"$entry"/}" ]] && rm -rf "$dest/${exc#"$entry"/}"
      done
    fi
    if [[ "$VERBOSE" == "true" ]]; then printf '%b\n' "  $icon_pass Folder: $entry"; fi
  else
    # File pattern: find matching files
    find "$REPO_ROOT" -maxdepth 2 -name "$entry" -not -path "*/.git/*" ${WT_EXCLUDES[@]+"${WT_EXCLUDES[@]}"} | while read -r match; do
      rel="${match#$REPO_ROOT/}"
      skip=false
      for exc in ${excludes[@]+"${excludes[@]}"}; do [[ "$rel" == "$exc" ]] && skip=true; done
      [[ "$skip" == "true" ]] && continue

      dest="$TARGET_PATH/$rel"
      if [[ "$DRY_RUN" == "true" ]]; then
        printf '%b\n' "  $icon_info DRY-RUN File: $rel"
        continue
      fi
      mkdir -p "$(dirname "$dest")"
      cp -p "$match" "$dest"
      if [[ "$VERBOSE" == "true" ]]; then printf '%b\n' "  $icon_pass File: $rel"; fi
    done
  fi
done
