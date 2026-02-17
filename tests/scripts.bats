#!/usr/bin/env bats

# Tests for helper scripts in skills/

setup() {
  ORIG_KIT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  source "$ORIG_KIT_DIR/tests/helpers.bash"
  TEMP_ROOT="$(mktemp -d -t worktree-kit-scripts-XXXXXX 2>/dev/null || mktemp -d)"

  # Copy kit to temp
  cp -R "$ORIG_KIT_DIR/." "$TEMP_ROOT/kit/"
  KIT_DIR="$TEMP_ROOT/kit"
  SCRIPTS_SHARED="$KIT_DIR/src/skills/_shared/scripts"

  # Make all scripts executable
  chmod +x "$SCRIPTS_SHARED"/*.sh
  find "$KIT_DIR/src/skills" -name "*.sh" -type f -exec chmod +x {} \;

  # Create a test repo with bare .git
  TEST_REPO="$TEMP_ROOT/test-repo"
  mkdir -p "$TEST_REPO"
  git -C "$TEST_REPO" init --bare .git >/dev/null 2>&1

  # Ensure HEAD points to main (git init may default to master)
  git -C "$TEST_REPO/.git" symbolic-ref HEAD refs/heads/main

  # Create initial commit in a worktree
  MAIN_WT="$TEST_REPO/main"
  git -C "$TEST_REPO/.git" worktree add "$MAIN_WT" -b main >/dev/null 2>&1
  touch "$MAIN_WT/README.md"
  git -C "$MAIN_WT" config user.email "test@example.com"
  git -C "$MAIN_WT" config user.name "Test User"
  git -C "$MAIN_WT" add . >/dev/null 2>&1
  git -C "$MAIN_WT" commit -m "Initial commit" >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEMP_ROOT"
}

# ============================================
# parse-config.sh tests
# ============================================

# @test "parse-config.sh returns defaults when no .worktreeconfig exists" {
#   run "$SCRIPTS_SHARED/parse-config.sh" worktrees.default_branch --repo "$TEST_REPO"
#   [ "$status" -eq 0 ]
#   [ "$output" = "main" ]
# }

@test "parse-config.sh reads worktrees.default_branch from config" {
  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[worktrees]
directory = .worktrees
default_branch = develop
EOF

  run "$SCRIPTS_SHARED/parse-config.sh" worktrees.default_branch --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "develop" ]
}

@test "parse-config.sh reads worktrees.directory from config" {
  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[worktrees]
directory = .worktrees
EOF

  run "$SCRIPTS_SHARED/parse-config.sh" worktrees.directory --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ "$output" = ".worktrees" ]
}

@test "parse-config.sh reads defaults.issue_tracker from config" {
  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[defaults]
issue_tracker = linear
EOF

  run "$SCRIPTS_SHARED/parse-config.sh" defaults.issue_tracker --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "linear" ]
}

# @test "parse-config.sh --json outputs valid structure" {
#   cat > "$TEST_REPO/.worktreeconfig" <<EOF
# [worktrees]
# default_branch = main
#
# [defaults]
# editor = cursor
# EOF
#
#   run "$SCRIPTS_SHARED/parse-config.sh" --json --repo "$TEST_REPO"
#   [ "$status" -eq 0 ]
#   [[ "$output" == *'"worktrees.default_branch": "main"'* ]]
#   [[ "$output" == *'"defaults.editor": "cursor"'* ]]
# }
#
# @test "parse-config.sh --all lists all config values" {
#   cat > "$TEST_REPO/.worktreeconfig" <<EOF
# [worktrees]
# default_branch = main
# EOF
#
#   run "$SCRIPTS_SHARED/parse-config.sh" --all --repo "$TEST_REPO"
#   # Script may output to stderr for fetch, check output contains expected values
#   [[ "$output" == *"default_branch=main"* ]] || [[ "$output" == *"default_branch"* ]]
# }

# ============================================
# wt-list.sh tests
# ============================================

@test "wt-list.sh lists worktrees in table format" {
  run "$KIT_DIR/src/skills/worktree-list/scripts/wt-list.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE"* ]]
  [[ "$output" == *"BRANCH"* ]]
  [[ "$output" == *"SIZE"* ]]
  [[ "$output" == *"main"* ]]
}

@test "wt-list.sh --json outputs valid JSON" {
  run "$KIT_DIR/src/skills/worktree-list/scripts/wt-list.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == "["* ]]
  [[ "$output" == *'"folder":'* ]]
  [[ "$output" == *'"branch": "main"'* ]]
}

@test "wt-list.sh --short outputs compact format" {
  run "$KIT_DIR/src/skills/worktree-list/scripts/wt-list.sh" --short --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"main (main)"* ]]
}

@test "wt-list.sh shows detached worktrees" {
  DETACHED_WT="$TEST_REPO/detached"
  git -C "$TEST_REPO/.git" worktree add --detach "$DETACHED_WT" HEAD >/dev/null 2>&1

  run "$KIT_DIR/src/skills/worktree-list/scripts/wt-list.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"branch": "detached"'* ]]
}

@test "wt-list.sh detects dirty worktree" {
  make_dirty "$MAIN_WT"

  run "$KIT_DIR/src/skills/worktree-list/scripts/wt-list.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"dirty": true'* ]]
}

# ============================================
# wt-candidates.sh tests
# ============================================

@test "wt-candidates.sh shows no candidates for active branches" {
  run "$KIT_DIR/src/skills/worktree-prune/scripts/wt-candidates.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PRUNE CANDIDATES"* ]]
  [[ "$output" == *"(none)"* ]]
}

@test "wt-candidates.sh --json outputs valid structure" {
  run "$KIT_DIR/src/skills/worktree-prune/scripts/wt-candidates.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == "["* ]]
}

@test "wt-candidates.sh detects merged branches" {
  # Create a feature branch worktree
  FEATURE_WT="$TEST_REPO/feature-test"
  git -C "$TEST_REPO/.git" worktree add "$FEATURE_WT" -b feature-test >/dev/null 2>&1

  # Make a commit in feature branch
  echo "feature" > "$FEATURE_WT/feature.txt"
  git -C "$FEATURE_WT" add . >/dev/null 2>&1
  git -C "$FEATURE_WT" commit -m "Add feature" >/dev/null 2>&1

  # Merge into main
  git -C "$MAIN_WT" merge feature-test --no-edit >/dev/null 2>&1

  run "$KIT_DIR/src/skills/worktree-prune/scripts/wt-candidates.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  # Either shows as merged or in removable section
  [[ "$output" == *"feature-test"* ]]
}

# ============================================
# wt-inspect.sh tests
# ============================================

@test "wt-inspect.sh shows worktree details" {
  run "$KIT_DIR/src/skills/worktree-status/scripts/wt-inspect.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Worktree Status: main"* ]]
  [[ "$output" == *"Branch"* ]]
  [[ "$output" == *"main"* ]]
}

@test "wt-inspect.sh --json outputs valid JSON" {
  run "$KIT_DIR/src/skills/worktree-status/scripts/wt-inspect.sh" main --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == "{"* ]]
  [[ "$output" == *'"folder": "main"'* ]]
  [[ "$output" == *'"branch": "main"'* ]]
}

@test "wt-inspect.sh handles detached worktree" {
  DETACHED_WT="$TEST_REPO/detached-inspect"
  git -C "$TEST_REPO/.git" worktree add --detach "$DETACHED_WT" HEAD >/dev/null 2>&1

  run "$KIT_DIR/src/skills/worktree-status/scripts/wt-inspect.sh" detached-inspect --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"branch": "detached"'* ]]
}

@test "wt-inspect.sh fails for non-existent worktree" {
  run "$KIT_DIR/src/skills/worktree-status/scripts/wt-inspect.sh" nonexistent --repo "$TEST_REPO"
  assert_not_found
}

@test "wt-inspect.sh shows uncommitted changes" {
  make_dirty "$MAIN_WT"

  run "$KIT_DIR/src/skills/worktree-status/scripts/wt-inspect.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"README.md"* ]] || [[ "$output" == *"Uncommitted"* ]]
}

# ============================================
# wt-pr-link.sh tests
# ============================================

@test "wt-pr-link.sh generates GitHub PR link" {
  # Set up a GitHub remote
  git -C "$TEST_REPO/.git" remote add origin "git@github.com:testuser/testrepo.git" 2>/dev/null || \
  git -C "$TEST_REPO/.git" remote set-url origin "git@github.com:testuser/testrepo.git"

  run "$KIT_DIR/src/skills/worktree-push/scripts/wt-pr-link.sh" feature-branch --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github.com"* ]]
  [[ "$output" == *"testuser/testrepo"* ]]
  [[ "$output" == *"feature-branch"* ]]
}

@test "wt-pr-link.sh --json outputs provider info" {
  git -C "$TEST_REPO/.git" remote add origin "https://github.com/myorg/myrepo.git" 2>/dev/null || \
  git -C "$TEST_REPO/.git" remote set-url origin "https://github.com/myorg/myrepo.git"

  run "$KIT_DIR/src/skills/worktree-push/scripts/wt-pr-link.sh" my-branch --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"provider": "github"'* ]]
  [[ "$output" == *'"organization": "myorg"'* ]]
  [[ "$output" == *'"repository": "myrepo"'* ]]
}

@test "wt-pr-link.sh supports GitLab URLs" {
  git -C "$TEST_REPO/.git" remote add origin "git@gitlab.com:mygroup/myproject.git" 2>/dev/null || \
  git -C "$TEST_REPO/.git" remote set-url origin "git@gitlab.com:mygroup/myproject.git"

  run "$KIT_DIR/src/skills/worktree-push/scripts/wt-pr-link.sh" feature --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"provider": "gitlab"'* ]]
  [[ "$output" == *"gitlab.com"* ]]
}

@test "wt-pr-link.sh respects --base parameter" {
  git -C "$TEST_REPO/.git" remote add origin "https://github.com/org/repo.git" 2>/dev/null || \
  git -C "$TEST_REPO/.git" remote set-url origin "https://github.com/org/repo.git"

  run "$KIT_DIR/src/skills/worktree-push/scripts/wt-pr-link.sh" feature --base develop --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"develop"* ]]
}

# ============================================
# wt-sync.sh tests
# ============================================

@test "wt-sync.sh syncs default branch" {
  run "$KIT_DIR/src/skills/worktree-sync/scripts/wt-sync.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYNC STATUS"* ]]
  [[ "$output" == *"main"* ]]
}

@test "wt-sync.sh --json outputs sync results" {
  run "$KIT_DIR/src/skills/worktree-sync/scripts/wt-sync.sh" --json --repo "$TEST_REPO" 2>/dev/null
  [ "$status" -eq 0 ]
  # JSON output should contain branch and status
  [[ "$output" == *'"branch"'* ]]
  [[ "$output" == *'"status"'* ]]
}

@test "wt-sync.sh skips dirty worktrees" {
  make_dirty "$MAIN_WT"

  run "$KIT_DIR/src/skills/worktree-sync/scripts/wt-sync.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]] || [[ "$output" == *"Uncommitted"* ]] || [[ "$output" == *"⚠"* ]]
}

# ============================================
# copy-files.sh tests
# ============================================

@test "copy-files.sh does nothing without .worktreeconfig" {
  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
}

@test "copy-files.sh copies files matching include pattern" {
  # Create source file
  echo "example" > "$TEST_REPO/.env.example"

  # Create config
  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = .env.example
EOF

  # Create target
  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.env.example" ]
}

@test "copy-files.sh --dry-run does not copy files" {
  echo "test" > "$TEST_REPO/test.txt"

  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = test.txt
EOF

  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/test.txt" ]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "copy-files.sh copies space-separated files and directories" {
  echo "env" > "$TEST_REPO/.env.example"
  mkdir -p "$TEST_REPO/mydir/sub"
  echo "data" > "$TEST_REPO/mydir/sub/file.txt"

  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = .env.example mydir
EOF

  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.env.example" ]
  [ -d "$TARGET/mydir" ]
  [ -f "$TARGET/mydir/sub/file.txt" ]
}

@test "copy-files.sh exclude skips matching file and directory" {
  echo "keep" > "$TEST_REPO/keep.txt"
  echo "skip" > "$TEST_REPO/skip.txt"
  mkdir -p "$TEST_REPO/skipdir"
  echo "x" > "$TEST_REPO/skipdir/a.txt"

  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = keep.txt skip.txt skipdir
exclude = skip.txt skipdir
EOF

  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [ -f "$TARGET/keep.txt" ]
  [ ! -f "$TARGET/skip.txt" ]
  [ ! -d "$TARGET/skipdir" ]
}

@test "copy-files.sh exclude exact path skips file inside copied directory" {
  mkdir -p "$TEST_REPO/mydir/sub"
  echo "keep" > "$TEST_REPO/mydir/file1.txt"
  echo "skip" > "$TEST_REPO/mydir/file2.txt"
  echo "nested" > "$TEST_REPO/mydir/sub/file2.txt"

  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = mydir
exclude = mydir/file2.txt
EOF

  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [ -d "$TARGET/mydir" ]
  [ -f "$TARGET/mydir/file1.txt" ]
  [ ! -f "$TARGET/mydir/file2.txt" ]
  # nested file2.txt is NOT excluded (different path)
  [ -f "$TARGET/mydir/sub/file2.txt" ]
}

@test "copy-files.sh exclude exact path only skips specific nested file" {
  mkdir -p "$TEST_REPO/mydir/sub"
  echo "keep" > "$TEST_REPO/mydir/file2.txt"
  echo "skip" > "$TEST_REPO/mydir/sub/file2.txt"

  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = mydir
exclude = mydir/sub/file2.txt
EOF

  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [ -d "$TARGET/mydir" ]
  [ -f "$TARGET/mydir/file2.txt" ]
  [ ! -f "$TARGET/mydir/sub/file2.txt" ]
}

@test "copy-files.sh exclude exact path skips only root-level standalone file" {
  echo "keep" > "$TEST_REPO/keep.txt"
  mkdir -p "$TEST_REPO/subdir"
  echo "skip-root" > "$TEST_REPO/secret.txt"
  echo "keep-nested" > "$TEST_REPO/subdir/secret.txt"

  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[copy]
include = keep.txt secret.txt
exclude = secret.txt
EOF

  TARGET="$TEMP_ROOT/target-wt"
  mkdir -p "$TARGET"

  run "$SCRIPTS_SHARED/copy-files.sh" "$TARGET" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [ -f "$TARGET/keep.txt" ]
  [ ! -f "$TARGET/secret.txt" ]
  # subdir/secret.txt is NOT excluded (different exact path)
  [ -f "$TARGET/subdir/secret.txt" ]
}

# ============================================
# wt-diagnose.sh tests
# ============================================

@test "wt-diagnose.sh runs health check successfully" {
  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repository"* ]]
}

@test "wt-diagnose.sh detects bare repository" {
  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO" --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"bare"* ]] || [[ "$output" == *"✓"* ]]
}

@test "wt-diagnose.sh checks for robustness settings" {
  # Force disable settings to see if it warns
  git -C "$TEST_REPO" config --unset core.filesRefLockTimeout || true
  git -C "$TEST_REPO" config gc.auto true

  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO"
  [[ "$output" == *"core.filesRefLockTimeout is not set"* ]]
  [[ "$output" == *"gc.auto is enabled"* ]]

  # Set them and check if it passes
  git -C "$TEST_REPO" config core.filesRefLockTimeout 100
  git -C "$TEST_REPO" config gc.auto 0
  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO"
  [[ "$output" == *"core.filesRefLockTimeout is set"* ]]
  [[ "$output" == *"gc.auto is disabled"* ]]
}

@test "wt-diagnose.sh checks for dependencies" {
  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  # Should check for git
}

# ============================================
# wt-run-hooks.sh tests
# ============================================

@test "wt-run-hooks.sh does nothing without config" {
  run "$SCRIPTS_SHARED/wt-run-hooks.sh" post_create "$MAIN_WT" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
}

@test "wt-run-hooks.sh executes post_create hooks" {
  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[hooks]
post_create = echo "Hook executed" > hook-test.txt
EOF

  run "$SCRIPTS_SHARED/wt-run-hooks.sh" post_create "$MAIN_WT" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -f "$MAIN_WT/hook-test.txt" ]
}

@test "wt-run-hooks.sh --dry-run shows hooks without executing" {
  cat > "$TEST_REPO/.worktreeconfig" <<EOF
[hooks]
post_create = echo "Test"
EOF

  run "$SCRIPTS_SHARED/wt-run-hooks.sh" post_create "$MAIN_WT" --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"Would execute"* ]]
}

# ============================================
# wt-log.sh tests
# ============================================

@test "wt-log.sh creates log file" {
  run "$SCRIPTS_SHARED/wt-log.sh" test-operation ABC-123 "Test details" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -f "$TEST_REPO/.worktree-history.log" ]
}

@test "wt-log.sh logs operation with correct format" {
  "$SCRIPTS_SHARED/wt-log.sh" worktree-add ABC-123 "Created from ticket" --repo "$TEST_REPO"

  LOG_CONTENT=$(cat "$TEST_REPO/.worktree-history.log")
  [[ "$LOG_CONTENT" == *"worktree-add"* ]]
  [[ "$LOG_CONTENT" == *"ABC-123"* ]]
  [[ "$LOG_CONTENT" == *"Created from ticket"* ]]
}

@test "wt-log.sh appends multiple operations" {
  "$SCRIPTS_SHARED/wt-log.sh" worktree-add ABC-123 "First" --repo "$TEST_REPO"
  "$SCRIPTS_SHARED/wt-log.sh" commit ABC-123 "Second" --repo "$TEST_REPO"

  LINE_COUNT=$(wc -l < "$TEST_REPO/.worktree-history.log" | tr -d ' ')
  [ "$LINE_COUNT" -eq 2 ]
}

# ============================================
# wt-history.sh tests
# ============================================

@test "wt-history.sh shows empty message without log" {
  rm -f "$TEST_REPO/.worktree-history.log"

  run "$SCRIPTS_SHARED/wt-history.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No history"* ]] || [[ "$output" == "" ]]
}

@test "wt-history.sh displays logged operations" {
  "$SCRIPTS_SHARED/wt-log.sh" worktree-add ABC-123 "Test" --repo "$TEST_REPO"

  run "$SCRIPTS_SHARED/wt-history.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ABC-123"* ]]
}

@test "wt-history.sh filters by worktree" {
  "$SCRIPTS_SHARED/wt-log.sh" worktree-add ABC-123 "First" --repo "$TEST_REPO"
  "$SCRIPTS_SHARED/wt-log.sh" worktree-add XYZ-456 "Second" --repo "$TEST_REPO"

  run "$SCRIPTS_SHARED/wt-history.sh" --worktree ABC-123 --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ABC-123"* ]]
  [[ "$output" != *"XYZ-456"* ]]
}

@test "wt-history.sh --json outputs valid JSON" {
  "$SCRIPTS_SHARED/wt-log.sh" worktree-add ABC-123 "Test" --repo "$TEST_REPO"

  run "$SCRIPTS_SHARED/wt-history.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == "["* ]]
}

# ============================================
# wt-stash.sh tests
# ============================================

@test "wt-stash.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-stash.sh"
}

@test "wt-stash.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-stash.sh"
}

@test "wt-stash.sh list command exists" {
  # Just test that calling with list doesn't error on command parse
  run bash -c "'$SCRIPTS_SHARED/wt-stash.sh' list 2>&1 | head -1"
  # May fail due to no git repo, but should not complain about unknown command
  [[ "$output" != *"Unknown command"* ]]
}

@test "wt-stash.sh --json flag is accepted" {
  # Verify the script accepts --json flag without error
  run bash -c "'$SCRIPTS_SHARED/wt-stash.sh' list --json 2>&1 | head -1"
  # Should start with [ for JSON or error about no repo, not about unknown flag
  [[ "$output" != *"Unknown option"* ]]
}

@test "wt-stash.sh move command transfers stashes" {
  mkdir -p "$TEST_REPO/wt1" "$TEST_REPO/wt2"

  # Create a stash for wt1
  echo "change" > "$MAIN_WT/file.txt"
  git -C "$TEST_REPO" config user.email "test@example.com"
  git -C "$TEST_REPO" config user.name "Test User"

  run bash -c "cd '$MAIN_WT' && '$SCRIPTS_SHARED/wt-stash.sh' save wt1 'Feature work' --repo '$TEST_REPO'"
  echo "Save output: $output"
  [ "$status" -eq 0 ]

  # List stashes and check for worktree label (must run from worktree context)
  run bash -c "cd '$MAIN_WT' && '$SCRIPTS_SHARED/wt-stash.sh' list --repo '$TEST_REPO'"
  echo "List output: $output" # Debug output for failures
  [[ "$output" =~ "wt1" ]]

  # Move it to wt2
  run bash -c "cd '$MAIN_WT' && '$SCRIPTS_SHARED/wt-stash.sh' move wt1 wt2 --repo '$TEST_REPO'"
  [ "$status" -eq 0 ]

  run bash -c "cd '$MAIN_WT' && '$SCRIPTS_SHARED/wt-stash.sh' list --repo '$TEST_REPO'"
  [[ "$output" =~ "wt2" ]]
  [[ "$output" != *"wt1"* ]]
}

# ============================================
# wt-hotfix.sh tests
# ============================================

@test "wt-hotfix.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-hotfix.sh"
}

@test "wt-hotfix.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-hotfix.sh"
}

@test "wt-hotfix.sh requires hotfix name" {
  run "$SCRIPTS_SHARED/wt-hotfix.sh"
  [ "$status" -ne 0 ]
}

@test "wt-hotfix.sh detects missing repository" {
  run bash -c "cd /tmp && '$SCRIPTS_SHARED/wt-hotfix.sh' test-fix 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"repository"* ]]
}

@test "wt-hotfix.sh creates hotfix worktree" {
  run "$SCRIPTS_SHARED/wt-hotfix.sh" critical-bug --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE READY"* ]]
  [ -d "$TEST_REPO/hotfix-critical-bug" ]
}

@test "wt-hotfix.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-hotfix.sh" json-bug --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"folder": "hotfix-json-bug"'* ]]
  [[ "$output" == *'"branch": "hotfix/json-bug"'* ]]
  [[ "$output" == *'"action": "created"'* ]]
  [ -d "$TEST_REPO/hotfix-json-bug" ]
}

@test "wt-optimize.sh identifies and cleans artifacts" {
  mkdir -p "$MAIN_WT/node_modules" "$MAIN_WT/target"
  touch "$MAIN_WT/node_modules/heavy.lib"

  # Dry run should find them but not delete
  run "$SCRIPTS_SHARED/wt-optimize.sh" --dry-run --repo "$TEST_REPO"
  [[ "$output" == *"node_modules"* ]]
  [[ "$output" == *"target"* ]]
  [ -d "$MAIN_WT/node_modules" ]

  # Actual run should delete
  run "$SCRIPTS_SHARED/wt-optimize.sh" --repo "$TEST_REPO"
  [ ! -d "$MAIN_WT/node_modules" ]
  [ ! -d "$MAIN_WT/target" ]
}

@test "wt-prune.sh cleans orphaned references" {
  mkdir -p "$TEST_REPO/orphaned_wt"
  git -C "$TEST_REPO" worktree add "$TEST_REPO/orphaned_wt" -b orphaned-branch

  # Delete manually
  rm -rf "$TEST_REPO/orphaned_wt"

  # Diagnose should catch it
  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO"
  [[ "$output" == *"Orphaned worktree detected"* ]]

  # Prune should fix it
  run "$SCRIPTS_SHARED/wt-prune.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]

  # Diagnose should now be clean of orphans
  run "$SCRIPTS_SHARED/wt-diagnose.sh" --repo "$TEST_REPO"
  [[ "$output" != *"Orphaned worktree detected"* ]]
}

# ============================================
# wt-fetch-all.sh tests
# ============================================

@test "wt-fetch-all.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-fetch-all.sh"
}

@test "wt-fetch-all.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-fetch-all.sh"
}

@test "wt-fetch-all.sh fetches in all worktrees" {
  run "$SCRIPTS_SHARED/wt-fetch-all.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fetched"* ]] || [[ "$output" == *"No worktrees"* ]]
}

# ============================================
# wt-status-all.sh tests
# ============================================

@test "wt-status-all.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-status-all.sh"
}

@test "wt-status-all.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-status-all.sh"
}

@test "wt-status-all.sh shows status" {
  run "$SCRIPTS_SHARED/wt-status-all.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
}

@test "wt-status-all.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-status-all.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == "["* ]] || [[ "$output" == "[]" ]]
}

# ============================================
# wt-branch-cleanup.sh tests
# ============================================

@test "wt-branch-cleanup.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-branch-cleanup.sh"
}

@test "wt-branch-cleanup.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-branch-cleanup.sh"
}

@test "wt-branch-cleanup.sh --dry-run shows preview" {
  run "$SCRIPTS_SHARED/wt-branch-cleanup.sh" --dry-run --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
}

@test "wt-branch-cleanup.sh cleans branches" {
  run "$SCRIPTS_SHARED/wt-branch-cleanup.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleted local"* ]] || [[ "$output" == *"Deleted 0"* ]]
}

# ============================================
# wt-create.sh tests
# ============================================

@test "wt-create.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-create.sh"
}

@test "wt-create.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-create.sh"
}

@test "wt-create.sh requires --branch" {
  run "$SCRIPTS_SHARED/wt-create.sh" --folder test-folder --repo "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--branch is required"* ]]
}

@test "wt-create.sh requires --folder" {
  run "$SCRIPTS_SHARED/wt-create.sh" --branch test-branch --repo "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--folder is required"* ]]
}

@test "wt-create.sh creates a new worktree" {
  run "$SCRIPTS_SHARED/wt-create.sh" --branch feature-test --folder ABC-1234 --repo "$TEST_REPO" --no-hooks --no-copy
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE READY"* ]]
  [ -d "$TEST_REPO/ABC-1234" ]
}

@test "wt-create.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-create.sh" --branch feature-json --folder JSON-TEST --repo "$TEST_REPO" --json --no-hooks --no-copy
  [ "$status" -eq 0 ]
  [[ "$output" == *'"folder": "JSON-TEST"'* ]]
  [[ "$output" == *'"branch": "feature-json"'* ]]
  [[ "$output" == *'"action": "created"'* ]]
}

@test "wt-create.sh reuses existing worktree" {
  create_test_worktree feature-reuse REUSE-TEST

  # Try to create again - should reuse
  run "$SCRIPTS_SHARED/wt-create.sh" --branch feature-reuse --folder REUSE-TEST --repo "$TEST_REPO" --json --no-hooks --no-copy
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action": "reused"'* ]]
}

@test "wt-create.sh reuses worktree when branch is already checked out" {
  create_test_worktree feature-checked-out CHECKED-OUT

  # Try to create with same branch but different folder - should reuse
  run "$SCRIPTS_SHARED/wt-create.sh" --branch feature-checked-out --folder DIFFERENT-FOLDER --repo "$TEST_REPO" --json --no-hooks --no-copy
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action": "reused"'* ]]
}

@test "wt-create.sh --dry-run does not create worktree" {
  run "$SCRIPTS_SHARED/wt-create.sh" --branch feature-dryrun --folder DRY-CREATE --repo "$TEST_REPO" --dry-run --no-hooks --no-copy
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [ ! -d "$TEST_REPO/DRY-CREATE" ]
}

@test "wt-create.sh --dry-run --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-create.sh" --branch feature-dryrun-json --folder DRY-JSON --repo "$TEST_REPO" --dry-run --json --no-hooks --no-copy
  [ "$status" -eq 0 ]
  [[ "$output" == *'"dry_run": true'* ]]
  [[ "$output" == *'"folder": "DRY-JSON"'* ]]
  [ ! -d "$TEST_REPO/DRY-JSON" ]
}

# ============================================
# wt-remove.sh tests
# ============================================

@test "wt-remove.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-remove.sh"
}

@test "wt-remove.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-remove.sh"
}

@test "wt-remove.sh requires folder argument" {
  run "$SCRIPTS_SHARED/wt-remove.sh" --repo "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"folder name is required"* ]]
}

@test "wt-remove.sh fails for non-existent worktree" {
  run "$SCRIPTS_SHARED/wt-remove.sh" nonexistent --repo "$TEST_REPO"
  assert_not_found
}

@test "wt-remove.sh removes clean worktree" {
  create_test_worktree feature-to-remove REMOVE-ME
  [ -d "$TEST_REPO/REMOVE-ME" ]

  # Remove it
  run "$SCRIPTS_SHARED/wt-remove.sh" REMOVE-ME --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE REMOVED"* ]]
  [ ! -d "$TEST_REPO/REMOVE-ME" ]
}

@test "wt-remove.sh exits with code 2 for dirty worktree" {
  create_test_worktree feature-dirty-rm DIRTY-RM

  # Make it dirty
  echo "dirty" > "$TEST_REPO/DIRTY-RM/dirty-file.txt"

  # Try to remove without --force
  run "$SCRIPTS_SHARED/wt-remove.sh" DIRTY-RM --repo "$TEST_REPO"
  [ "$status" -eq 2 ]
  [[ "$output" == *"uncommitted"* ]]
  [ -d "$TEST_REPO/DIRTY-RM" ]
}

@test "wt-remove.sh --force removes dirty worktree" {
  create_test_worktree feature-force-rm FORCE-RM

  # Make it dirty
  echo "dirty" > "$TEST_REPO/FORCE-RM/dirty-file.txt"

  # Force remove
  run "$SCRIPTS_SHARED/wt-remove.sh" FORCE-RM --force --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE REMOVED"* ]]
  [ ! -d "$TEST_REPO/FORCE-RM" ]
}

@test "wt-remove.sh --delete-branch removes branch too" {
  create_test_worktree feature-del-branch DEL-BRANCH

  # Remove with branch deletion
  run "$SCRIPTS_SHARED/wt-remove.sh" DEL-BRANCH --delete-branch --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleted"* ]]

  # Verify branch is gone
  run git -C "$TEST_REPO" show-ref --verify --quiet refs/heads/feature-del-branch
  [ "$status" -ne 0 ]
}

@test "wt-remove.sh --json outputs valid JSON" {
  create_test_worktree feature-rm-json RM-JSON

  run "$SCRIPTS_SHARED/wt-remove.sh" RM-JSON --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"folder": "RM-JSON"'* ]]
  [[ "$output" == *'"branch":'* ]]
}

@test "wt-remove.sh protects default branch worktree" {
  run "$SCRIPTS_SHARED/wt-remove.sh" main --repo "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot remove default branch"* ]]
}

@test "wt-remove.sh --dry-run does not remove worktree" {
  create_test_worktree feature-dryrun-rm DRYRUN-RM

  run "$SCRIPTS_SHARED/wt-remove.sh" DRYRUN-RM --dry-run --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  # Worktree should still exist
  [ -d "$TEST_REPO/DRYRUN-RM" ]
}

@test "wt-remove.sh --dry-run --json outputs valid JSON" {
  create_test_worktree feature-dryrun-rm-json DRYRUN-RM-JSON

  run "$SCRIPTS_SHARED/wt-remove.sh" DRYRUN-RM-JSON --dry-run --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"dry_run": true'* ]]
  [[ "$output" == *'"folder": "DRYRUN-RM-JSON"'* ]]
  # Worktree should still exist
  [ -d "$TEST_REPO/DRYRUN-RM-JSON" ]
}

# ============================================
# wt-switch.sh tests
# ============================================

@test "wt-switch.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-switch.sh"
}

@test "wt-switch.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-switch.sh"
}

@test "wt-switch.sh shows context for worktree" {
  run "$SCRIPTS_SHARED/wt-switch.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT SWITCHED"* ]]
  [[ "$output" == *"Branch"* ]]
  [[ "$output" == *"main"* ]]
}

@test "wt-switch.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-switch.sh" main --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"folder": "main"'* ]]
  [[ "$output" == *'"branch": "main"'* ]]
  [[ "$output" == *'"status":'* ]]
}

@test "wt-switch.sh fails for non-existent worktree" {
  run "$SCRIPTS_SHARED/wt-switch.sh" nonexistent --repo "$TEST_REPO"
  assert_not_found
}

@test "wt-switch.sh detects dirty worktree" {
  make_dirty "$MAIN_WT"

  run "$SCRIPTS_SHARED/wt-switch.sh" main --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "dirty"'* ]]

  # Clean up
  git -C "$MAIN_WT" checkout -- README.md 2>/dev/null || true
}

# ============================================
# wt-branch-info.sh tests
# ============================================

@test "wt-branch-info.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-branch-info.sh"
}

@test "wt-branch-info.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-branch-info.sh"
}

@test "wt-branch-info.sh detects local branch" {
  run "$SCRIPTS_SHARED/wt-branch-info.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BRANCH INFO"* ]]
  [[ "$output" == *"exists"* ]]
}

@test "wt-branch-info.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-branch-info.sh" main --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"branch": "main"'* ]]
  [[ "$output" == *'"exists_local": true'* ]]
}

@test "wt-branch-info.sh detects non-existent branch" {
  run "$SCRIPTS_SHARED/wt-branch-info.sh" nonexistent-branch --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"exists_local": false'* ]]
  [[ "$output" == *'"exists_remote": false'* ]]
}

@test "wt-branch-info.sh shows worktree checkout info" {
  run "$SCRIPTS_SHARED/wt-branch-info.sh" main --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"checked_out_in": "main"'* ]]
}

# ============================================
# wt-diff.sh tests
# ============================================

@test "wt-diff.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-diff.sh"
}

@test "wt-diff.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-diff.sh"
}

@test "wt-diff.sh shows no changes for clean worktree" {
  run "$SCRIPTS_SHARED/wt-diff.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes"* ]]
}

@test "wt-diff.sh detects changes" {
  make_dirty "$MAIN_WT"

  run "$SCRIPTS_SHARED/wt-diff.sh" main --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"README.md"* ]] || [[ "$output" == *"Files changed"* ]]

  # Clean up
  git -C "$MAIN_WT" checkout -- README.md 2>/dev/null || true
}

@test "wt-diff.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-diff.sh" main --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"folder":'* ]]
  [[ "$output" == *'"files_changed":'* ]]
  [[ "$output" == *'"lines_added":'* ]]
}

@test "wt-diff.sh fails for non-existent worktree" {
  run "$SCRIPTS_SHARED/wt-diff.sh" nonexistent --repo "$TEST_REPO"
  assert_not_found
}

# ============================================
# wt-merge-status.sh tests
# ============================================

@test "wt-merge-status.sh is executable" {
  assert_executable "$SCRIPTS_SHARED/wt-merge-status.sh"
}

@test "wt-merge-status.sh shows help" {
  assert_help "$SCRIPTS_SHARED/wt-merge-status.sh"
}

@test "wt-merge-status.sh shows status" {
  run "$SCRIPTS_SHARED/wt-merge-status.sh" --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MERGE STATUS"* ]]
  [[ "$output" == *"main"* ]]
}

@test "wt-merge-status.sh --json outputs valid JSON" {
  run "$SCRIPTS_SHARED/wt-merge-status.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == "["* ]]
  [[ "$output" == *'"folder":'* ]]
  [[ "$output" == *'"merge_status":'* ]]
}

@test "wt-merge-status.sh detects merged branches" {
  create_test_worktree feature-merge-test MERGE-TEST

  # Make a commit in feature branch
  echo "feature" > "$TEST_REPO/MERGE-TEST/feature.txt"
  git -C "$TEST_REPO/MERGE-TEST" add . >/dev/null 2>&1
  git -C "$TEST_REPO/MERGE-TEST" commit -m "Add feature" >/dev/null 2>&1

  # Merge into main
  git -C "$MAIN_WT" merge feature-merge-test --no-edit >/dev/null 2>&1

  run "$SCRIPTS_SHARED/wt-merge-status.sh" --json --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"merge_status": "merged"'* ]]
}

# ============================================
# setup.sh --agent tests
# ============================================

@test "setup.sh --help mentions --agent option" {
  run "$KIT_DIR/setup.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--agent"* ]]
  [[ "$output" == *"claude"* ]]
  [[ "$output" == *"codex"* ]]
}

@test "setup.sh --agent invalid fails" {
  run "$KIT_DIR/setup.sh" --agent invalid "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown agent"* ]]
}

@test "setup.sh default installs only claude-code" {
  # Remove any agent dirs first
  rm -rf "$TEST_REPO/.claude" "$TEST_REPO/.codex" "$TEST_REPO/CLAUDE.md" "$TEST_REPO/AGENTS.md"

  run "$KIT_DIR/setup.sh" "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -d "$TEST_REPO/.claude" ]
  [ -d "$TEST_REPO/.claude/skills" ]
  [ ! -d "$TEST_REPO/.codex" ]
  [ -f "$TEST_REPO/CLAUDE.md" ]
}

@test "setup.sh --agent claude-code installs only claude-code" {
  rm -rf "$TEST_REPO/.claude" "$TEST_REPO/.codex" "$TEST_REPO/CLAUDE.md" "$TEST_REPO/AGENTS.md"

  run "$KIT_DIR/setup.sh" --agent claude-code "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -d "$TEST_REPO/.claude" ]
  [ -d "$TEST_REPO/.claude/skills" ]
  [ ! -d "$TEST_REPO/.codex" ]
  [[ "$output" == *"claude-code"* ]]
}

@test "setup.sh --agent codex installs only codex" {
  rm -rf "$TEST_REPO/.claude" "$TEST_REPO/.codex" "$TEST_REPO/CLAUDE.md" "$TEST_REPO/AGENTS.md"

  run "$KIT_DIR/setup.sh" --agent codex "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -d "$TEST_REPO/.codex" ]
  [ -d "$TEST_REPO/.codex/skills" ]
  [ ! -d "$TEST_REPO/.claude" ]
  [ ! -f "$TEST_REPO/CLAUDE.md" ]
}

@test "setup.sh --agent all is not supported" {
  rm -rf "$TEST_REPO/.claude" "$TEST_REPO/.codex" "$TEST_REPO/CLAUDE.md" "$TEST_REPO/AGENTS.md"

  run "$KIT_DIR/setup.sh" --agent all "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown agent" ]]
}

@test "setup.sh --agent codex does not create CLAUDE.md" {
  rm -rf "$TEST_REPO/.claude" "$TEST_REPO/.codex" "$TEST_REPO/CLAUDE.md" "$TEST_REPO/AGENTS.md"

  run "$KIT_DIR/setup.sh" --agent codex "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_REPO/CLAUDE.md" ]
}


