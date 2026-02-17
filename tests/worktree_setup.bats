#!/usr/bin/env bats

setup() {
  ORIG_KIT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  TEMP_ROOT="$(mktemp -d -t worktree-kit-bats-XXXXXX 2>/dev/null || mktemp -d)"
  command -v git >/dev/null 2>&1 || skip "'git' no está disponible en el entorno de test"
}

teardown() {
  rm -rf "$TEMP_ROOT"
}

# Helper: copy kit and return path in $kit_dir
copy_kit() {
  kit_dir="$TEMP_ROOT/kit-under-test"
  cp -R "$ORIG_KIT_DIR/." "$kit_dir/"
}

@test "init mode creates bare repo and installs skills" {
  copy_kit
  remote="$TEMP_ROOT/remote.git"
  mkdir -p "$remote"
  git -C "$remote" init --bare >/dev/null
  target="$TEMP_ROOT/project"

  run "$kit_dir/setup.sh" "$remote" "$target"
  [ "$status" -eq 0 ]
  [ -d "$target/.git" ]
  is_bare=$(git -C "$target/.git" rev-parse --is-bare-repository)
  [ "$is_bare" = "true" ]

  # Skills should be copied into agent directory
  kit_skills=$(find "$kit_dir/src/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  target_skills=$(find "$target/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  [ "$kit_skills" -eq "$target_skills" ]

  # Default agent (claude) skills should be a directory
  [ -d "$target/.claude/skills" ]

  # CLAUDE.md should exist (copied from AGENTS.md)
  [ -f "$target/CLAUDE.md" ]
}

@test "update mode fails when .git is not bare" {
  copy_kit
  target="$TEMP_ROOT/nonbare"
  mkdir -p "$target"
  git -C "$target" init >/dev/null

  run "$kit_dir/setup.sh" "$target"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "not a bare repository" ]]
}

@test "skills sync preserves custom user skills" {
  copy_kit
  remote="$TEMP_ROOT/remote.git"
  mkdir -p "$remote"
  git -C "$remote" init --bare >/dev/null
  target="$TEMP_ROOT/project"

  "$kit_dir/setup.sh" "$remote" "$target"

  mkdir -p "$target/.claude/skills/my-custom-skill"
  touch "$target/.claude/skills/my-custom-skill/SKILL.md"

  run "$kit_dir/setup.sh" "$target"
  [ "$status" -eq 0 ]
  # Custom skills must survive updates
  [ -f "$target/.claude/skills/my-custom-skill/SKILL.md" ]
}

@test "prevent installing inside the kit directory" {
  copy_kit
  run "$kit_dir/setup.sh" "$kit_dir/remote.git" "$kit_dir/inside"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "cannot be inside the Worktree Kit directory" ]]
}

@test "setup.sh rejects unknown flags" {
  copy_kit
  run "$kit_dir/setup.sh" --skill worktree-list "$TEMP_ROOT"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown option" ]]
}
