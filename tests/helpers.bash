#!/usr/bin/env bash
# Test helpers for worktree-kit BATS test suite

# Assert a script is executable
assert_executable() {
  [ -x "$1" ]
}

# Assert --help outputs usage info and exits 0
assert_help() {
  run "$1" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"Usage"* ]]
}

# Assert last `run` produced valid JSON (object or array)
assert_json_output() {
  [ "$status" -eq 0 ]
  [[ "$output" == "{"* ]] || [[ "$output" == "["* ]]
}

# Assert last `run` output contains specific JSON field names
# Usage: assert_json_fields "folder" "branch" "status"
assert_json_fields() {
  for field in "$@"; do
    [[ "$output" == *"\"$field\":"* ]] || {
      echo "Expected JSON field '$field' not found in output" >&2
      return 1
    }
  done
}

# Assert last `run` failed with "not found" message
assert_not_found() {
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# Make a worktree dirty by appending to README.md
make_dirty() {
  echo "dirty-change" >> "$1/README.md"
}

# Create a test worktree silently
# Usage: create_test_worktree <branch> <folder>
create_test_worktree() {
  "$SCRIPTS_SHARED/wt-create.sh" \
    --branch "$1" \
    --folder "$2" \
    --repo "$TEST_REPO" \
    --no-hooks \
    --no-copy \
    >/dev/null 2>&1
}
