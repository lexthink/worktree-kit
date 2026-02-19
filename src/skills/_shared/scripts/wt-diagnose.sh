#!/usr/bin/env bash
# wt-diagnose.sh - Diagnose worktree-kit health and configuration
# Usage: wt-diagnose.sh [--verbose] [--repo PATH]

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-diagnose.sh - Health check for Worktree Kit repository

USAGE:
  wt-diagnose.sh [options]

OPTIONS:
  --verbose   Show detailed information
  --repo PATH Repository root
  -h, --help  Show this help
EOF
  exit 0
}

REPO_ROOT=""
VERBOSE="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE="true"; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"
GIT_CMD_ROOT="$REPO_ROOT"
if [[ -f "$REPO_ROOT/.git/HEAD" ]]; then
  GIT_CMD_ROOT="$REPO_ROOT/.git"
elif ! git -C "$GIT_CMD_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$REPO_ROOT/.git" rev-parse --git-dir >/dev/null 2>&1; then
    GIT_CMD_ROOT="$REPO_ROOT/.git"
  else
    GIT_CMD_ROOT="$REPO_ROOT"
  fi
fi
CHECKS_TOTAL=0; CHECKS_PASSED=0; CHECKS_WARNING=0; CHECKS_FAILED=0
GIT_DIR_RAW=$(git -C "$GIT_CMD_ROOT" rev-parse --git-dir 2>/dev/null || echo ".git")
if [[ "$GIT_DIR_RAW" == /* ]]; then
  GIT_DIR_ABS="$GIT_DIR_RAW"
else
  GIT_DIR_ABS="$GIT_CMD_ROOT/$GIT_DIR_RAW"
fi

if [[ "$VERBOSE" == "true" ]]; then
  printf '%b\n' "${BOLD}DEBUG${NC}"
  echo "  repo_root: $REPO_ROOT"
  echo "  git_cmd_root: $GIT_CMD_ROOT"
  echo "  git_dir_raw: $GIT_DIR_RAW"
  echo "  git_dir_abs: $GIT_DIR_ABS"
  echo "  git_common_dir: $(git -C "$GIT_CMD_ROOT" rev-parse --git-common-dir 2>/dev/null || echo "")"
  echo "  worktree_list:"
  git -C "$GIT_CMD_ROOT" worktree list --porcelain -v 2>/dev/null | sed 's/^/    /'
  if [[ -d "$GIT_DIR_ABS/worktrees" ]]; then
    echo "  worktrees_dir: $GIT_DIR_ABS/worktrees"
    for wt in "$GIT_DIR_ABS/worktrees"/*; do
      [[ -d "$wt" ]] || continue
      if [[ -f "$wt/worktree" ]]; then
        echo "    $(basename "$wt")/worktree: $(cat "$wt/worktree" 2>/dev/null || echo "")"
      fi
      if [[ -f "$wt/gitdir" ]]; then
        echo "    $(basename "$wt")/gitdir: $(cat "$wt/gitdir" 2>/dev/null || echo "")"
      fi
    done
  fi
fi

path_exists() {
  local p="$1"
  if [[ "$p" == /* ]]; then
    [[ -d "$p" ]] && return 0
    return 1
  fi
  [[ -d "$REPO_ROOT/$p" ]] && return 0
  [[ -d "$GIT_DIR_ABS/$p" ]] && return 0
  return 1
}

declare -A ORPHAN_SEEN=()
add_orphan() {
  local p="$1"
  [[ -z "$p" ]] && p="(unknown)"
  if [[ -z "${ORPHAN_SEEN[$p]:-}" ]]; then
    ORPHAN_SEEN["$p"]=1
    ((orphaned++))
    if [[ "$p" == "(unknown)" ]]; then
      check_warn "Orphaned worktree detected"
    else
      check_warn "Orphaned worktree detected: $p"
    fi
  fi
}

# Ensure these return true even if the counter starts at 0
check_pass() { printf '%b\n' "  $icon_pass $1"; ((CHECKS_PASSED++)) || true; ((CHECKS_TOTAL++)) || true; }
check_warn() { printf '%b\n' "  $icon_warn $1"; ((CHECKS_WARNING++)) || true; ((CHECKS_TOTAL++)) || true; }
check_fail() { printf '%b\n' "  $icon_fail $1"; ((CHECKS_FAILED++)) || true; ((CHECKS_TOTAL++)) || true; }
check_info() { [[ "$VERBOSE" == "true" ]] && printf '%b\n' "  $icon_info $1"; return 0; }

print_header "WORKTREE KIT HEALTH CHECK"

# 1. Repo Structure
HAS_GIT="true"
if ! git -C "$GIT_CMD_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  check_fail "Git directory not found"
  HAS_GIT="false"
fi
if [[ "$HAS_GIT" == "true" ]]; then
  if git -C "$GIT_CMD_ROOT" rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
    check_pass "Repository is bare"
  else
    check_warn "Repository is NOT bare (recommended for worktree setups)"
  fi
fi

# 2. Config
if [[ -f "$REPO_ROOT/.worktreeconfig" ]]; then
  check_pass ".worktreeconfig found"
  check_info "Default branch: $($SCRIPT_DIR/parse-config.sh worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo 'main')"
else
  check_warn ".worktreeconfig not found (using defaults)"
fi

# 3. Dependencies
if command -v git >/dev/null 2>&1; then check_pass "Dependency: git"; else check_fail "Missing: git"; fi

# 4. Agent Skills (infer current agent from script path)
# SCRIPT_DIR is .../.<agent>/skills/_shared/scripts
AGENT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT_NAME="$(basename "$AGENT_DIR")"
if [[ -d "$AGENT_DIR/skills" ]]; then
  check_pass "$AGENT_NAME skills installed"
else
  check_fail "$AGENT_NAME skills directory missing"
fi

# 5. Git Configs
if [[ "$HAS_GIT" == "true" ]]; then
  lt=$(git -C "$GIT_CMD_ROOT" config --get core.filesRefLockTimeout 2>/dev/null || echo "")
  if [[ -n "$lt" && "$lt" -gt 0 ]]; then
    check_pass "core.filesRefLockTimeout is set ($lt)"
  else
    check_warn "core.filesRefLockTimeout is not set"
  fi

  gc_auto=$(git -C "$GIT_CMD_ROOT" config --get gc.auto 2>/dev/null || echo "")
  if [[ -n "$gc_auto" && "$gc_auto" != "0" ]]; then
    check_warn "gc.auto is enabled"
  else
    check_pass "gc.auto is disabled"
  fi
fi

# 6. Orphaned Worktrees
orphaned=0
PRUNE_OUT=""
if [[ "$HAS_GIT" == "true" ]]; then
  PRUNE_OUT=$(git -C "$GIT_CMD_ROOT" worktree prune --dry-run -v 2>&1 || true)
fi
if [[ -n "$PRUNE_OUT" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == *"worktree"* || "$line" == *"prunable"* ]]; then
      path=$(echo "$line" | awk '{print $NF}')
      if [[ -n "$path" ]]; then
        if ! path_exists "$path"; then
          add_orphan "$path"
        fi
      else
        add_orphan "(unknown)"
      fi
    fi
  done <<< "$PRUNE_OUT"
fi

[[ $orphaned -eq 0 ]] && check_pass "No orphaned worktrees"

# Summary
printf '%b\n' "\n${BOLD}SUMMARY${NC}"
printf "  Checks: %d | ${GREEN}Passed: %d${NC} | ${YELLOW}Warn: %d${NC} | ${RED}Fail: %d${NC}\n" \
  "$CHECKS_TOTAL" "$CHECKS_PASSED" "$CHECKS_WARNING" "$CHECKS_FAILED"

if [[ $CHECKS_FAILED -eq 0 ]]; then
  printf '%b\n' "\n${BOLD}${icon_pass} ${GREEN}Everything looks good!${NC}"
else
  printf '%b\n' "\n${BOLD}${icon_fail} ${RED}Issues detected. Please review the details above.${NC}"
fi
