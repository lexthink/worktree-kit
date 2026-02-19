#!/usr/bin/env bash
# wt-pr-link.sh - Generate PR creation link based on git remote
# Usage: wt-pr-link.sh [branch_name] [--base <base_branch>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/../../_shared/scripts" && pwd)"
source "$SHARED_DIR/ui-utils.sh"

show_help() {
  cat <<EOF
wt-pr-link.sh - Generate a browser link to create a PR

USAGE:
  wt-pr-link.sh [branch_name] [options]

OPTIONS:
  --base BRANCH   Target branch for PR (default: main)
  --json          Output result as JSON
  --repo PATH     Repository root
  -h, --help      Show this help

SUPPORTS:
  GitHub, GitLab, Bitbucket, Azure DevOps
EOF
  exit 0
}

BRANCH=""
BASE_BRANCH=""
REPO_ROOT=""
OUTPUT_FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_BRANCH="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) [[ -z "$BRANCH" ]] && BRANCH="$1"; shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(find_repo_root "$PWD" pwd)}"

# Context detection
[[ -z "$BRANCH" ]] && BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "")
[[ -z "$BRANCH" ]] && { echo "Error: Could not determine branch" >&2; exit 1; }

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH=$("$SHARED_DIR/parse-config.sh" worktrees.default-branch --repo "$REPO_ROOT" 2>/dev/null || echo "main")
fi

REMOTE_URL=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
[[ -z "$REMOTE_URL" ]] && { echo "Error: No origin remote found" >&2; exit 1; }

# Provider Parsing
PROVIDER="unknown"; ORG=""; REPO_NAME=""
CLEAN_URL="${REMOTE_URL%.git}"

if [[ "$CLEAN_URL" =~ ^git@([^:]+):(.+)/([^/]+)$ ]]; then
  HOST="${BASH_REMATCH[1]}"; ORG="${BASH_REMATCH[2]}"; REPO_NAME="${BASH_REMATCH[3]}"
  [[ "$HOST" == *"github.com"* ]] && PROVIDER="github"
  [[ "$HOST" == *"gitlab.com"* ]] && PROVIDER="gitlab"
  [[ "$HOST" == *"bitbucket.org"* ]] && PROVIDER="bitbucket"
elif [[ "$CLEAN_URL" =~ ^https?://([^/]+)/(.+)/([^/]+)$ ]]; then
  HOST="${BASH_REMATCH[1]}"; ORG="${BASH_REMATCH[2]}"; REPO_NAME="${BASH_REMATCH[3]}"
  [[ "$HOST" == *"github.com"* ]] && PROVIDER="github"
  [[ "$HOST" == *"gitlab.com"* ]] && PROVIDER="gitlab"
elif [[ "$CLEAN_URL" =~ ^https://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)$ ]]; then
  HOST="dev.azure.com"
  PROVIDER="azure"; ORG="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"; REPO_NAME="${BASH_REMATCH[3]}"
fi

[[ "$PROVIDER" == "unknown" ]] && { echo "Error: Unknown git provider" >&2; exit 1; }

# URL Encoding (minimal for branch names)
encoded_branch=$(echo "$BRANCH" | sed 's/\//%2F/g')

case "$PROVIDER" in
  github)    PR_LINK="https://github.com/$ORG/$REPO_NAME/compare/$BASE_BRANCH...$encoded_branch?expand=1" ;;
  gitlab)    PR_LINK="https://gitlab.com/$ORG/$REPO_NAME/-/merge_requests/new?merge_request%5Bsource_branch%5D=$encoded_branch&merge_request%5Btarget_branch%5D=$BASE_BRANCH" ;;
  bitbucket) PR_LINK="https://bitbucket.org/$ORG/$REPO_NAME/pull-requests/new?source=$encoded_branch&dest=$BASE_BRANCH" ;;
  azure)     PR_LINK="https://dev.azure.com/$ORG/_git/$REPO_NAME/pullrequestcreate?sourceRef=$encoded_branch&targetRef=$BASE_BRANCH" ;;
esac

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  printf '{ "provider": "%s", "host": "%s", "organization": "%s", "repository": "%s", "branch": "%s", "base": "%s", "link": "%s" }\n' \
    "$(json_escape "$PROVIDER")" "$(json_escape "$HOST")" "$(json_escape "$ORG")" "$(json_escape "$REPO_NAME")" \
    "$(json_escape "$BRANCH")" "$(json_escape "$BASE_BRANCH")" "$(json_escape "$PR_LINK")"
else
  printf '%b\n' "${BOLD}${BLUE}PR Link ($PROVIDER) ${icon_info}${NC}"
  echo "$PR_LINK"
fi
