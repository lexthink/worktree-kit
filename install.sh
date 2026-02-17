#!/usr/bin/env bash
# Worktree Kit — One-Line Installer
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/lexthink/worktree-kit/main/install.sh) [options] <git_url> <target_path>
#
# This script downloads the kit to a temporary directory,
# runs the real setup.sh, and cleans up automatically.
set -euo pipefail

REPO_OWNER="lexthink"
REPO_NAME="worktree-kit"
BRANCH="main"

# Show help if no arguments
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Worktree Kit — One-Line Installer"
  echo ""
  echo "Usage:"
  echo "  bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh) [options] <git_url> <target_path>"
  echo "  bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh) [options] <target_path>"
  echo ""
  echo "Options:"
  echo "  -a, --agent <name>   Agent to configure (default: claude-code)"
  echo "  --ref <ref>          Git ref to download (default: main)"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "Examples:"
  echo "  # Initialize a new project"
  echo "  bash <(curl -fsSL URL) git@github.com:your-org/repo.git ~/dev/repo"
  echo ""
  echo "  # Update an existing project"
  echo "  bash <(curl -fsSL URL) ~/dev/repo"
  exit 0
fi

# Parse flags: consume --ref locally, pass everything else to setup.sh
INSTALL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --ref requires a value (branch or commit)."
        exit 1
      fi
      BRANCH="$2"
      shift 2
      ;;
    -a|--agent)
      INSTALL_ARGS+=("$1" "$2")
      shift 2
      ;;
    -*)
      echo "Error: Unknown option '$1'. See --help for usage."
      exit 1
      ;;
    *)
      INSTALL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Check dependencies
for cmd in curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed."
    exit 1
  fi
done

# Create temp directory with cleanup trap
TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "▶ Downloading Worktree Kit (${BRANCH})..."
TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.tar.gz"
if ! curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP_DIR" 2>/dev/null; then
  # Fallback: direct ref (works for commits and short refs)
  TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/${BRANCH}.tar.gz"
  curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP_DIR"
fi

# Find the extracted directory (GitHub creates <repo>-<ref>/)
KIT_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -1)
if [[ -z "$KIT_DIR" ]]; then
  echo "Error: Failed to extract Worktree Kit archive."
  exit 1
fi

# Run the real installer
bash "$KIT_DIR/setup.sh" ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}
