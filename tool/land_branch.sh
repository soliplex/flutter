#!/usr/bin/env bash
# =============================================================================
# land_branch.sh — Squash-land a feature branch onto main via worktree
# =============================================================================
#
# Automates the full landing workflow:
#   1. Creates a git worktree from main
#   2. Squash-merges the feature branch into it
#   3. Runs validate_pr.sh
#   4. Reports results (does NOT auto-commit or push)
#
# After the script completes, you're in the worktree with staged changes.
# Review, commit, push, and create the PR manually (or let Claude do it).
#
# Usage:
#   tool/land_branch.sh <feature-branch> [options]
#
# Examples:
#   tool/land_branch.sh feat/soliplex-schema \
#     --packages packages/soliplex_schema \
#     --pr-goal "Add soliplex_schema package"
#
#   tool/land_branch.sh feat/multi-server-support \
#     --packages packages/soliplex_client \
#     --app-tests \
#     --pr-goal "Add multi-server support"
#
# Options:
#   --name NAME        Worktree/branch name (default: land/<feature-branch-basename>)
#   --skip-validate    Skip validation (just create worktree + squash-merge)
#   --packages, --app-tests, --coverage-threshold, --pr-goal
#                      Passed through to validate_pr.sh
#
# Exit codes:
#   0  Worktree ready (validation passed or skipped)
#   1  Validation failed (worktree still exists for fixing)
#   2  Setup failed (worktree may not exist)
# =============================================================================
set -eo pipefail

# ── args ─────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 || "$1" == -* ]]; then
  echo "Usage: $0 <feature-branch> [options]"
  echo "  Run $0 --help for full usage"
  exit 2
fi

FEATURE_BRANCH="$1"
shift

WORKTREE_NAME=""
SKIP_VALIDATE=false
VALIDATE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)          WORKTREE_NAME="$2"; shift 2 ;;
    --skip-validate) SKIP_VALIDATE=true; shift ;;
    --help|-h)
      sed -n '2,/^# ====/p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *)  VALIDATE_ARGS+=("$1"); shift ;;
  esac
done

# ── safety: must run from main checkout, not a worktree ──────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel)"
GIT_COMMON="$(git rev-parse --git-common-dir)"
GIT_DIR_VAL="$(git rev-parse --git-dir)"

if [[ "$GIT_COMMON" != "$GIT_DIR_VAL" ]]; then
  echo "ERROR: Run this from the main checkout, not a worktree." >&2
  echo "  cd $(git -C "$GIT_COMMON/.." rev-parse --show-toplevel)" >&2
  exit 2
fi

# ── resolve branch ───────────────────────────────────────────────────────────
# Accept both bare name and remote-prefixed name
if git rev-parse --verify "runyaga/$FEATURE_BRANCH" >/dev/null 2>&1; then
  REMOTE_BRANCH="runyaga/$FEATURE_BRANCH"
elif git rev-parse --verify "$FEATURE_BRANCH" >/dev/null 2>&1; then
  REMOTE_BRANCH="$FEATURE_BRANCH"
else
  echo "ERROR: Branch '$FEATURE_BRANCH' not found. Try: git fetch runyaga" >&2
  exit 2
fi

# ── derive names ─────────────────────────────────────────────────────────────
BRANCH_BASENAME="$(basename "$FEATURE_BRANCH")"
if [[ -z "$WORKTREE_NAME" ]]; then
  WORKTREE_NAME="land-${BRANCH_BASENAME}"
fi
LAND_BRANCH="land/${BRANCH_BASENAME}"
WORKTREE_PATH="$REPO_ROOT/.claude/worktrees/$WORKTREE_NAME"

echo "Feature branch: $REMOTE_BRANCH"
echo "Landing as:     $LAND_BRANCH"
echo "Worktree:       $WORKTREE_PATH"
echo ""

# ── check for existing worktree ──────────────────────────────────────────────
if [[ -d "$WORKTREE_PATH" ]]; then
  echo "Worktree already exists at $WORKTREE_PATH"
  echo "To remove: git worktree remove $WORKTREE_PATH"
  echo "Or use --name to pick a different name"
  exit 2
fi

# ── create worktree ──────────────────────────────────────────────────────────
echo "Creating worktree..."
git worktree add "$WORKTREE_PATH" -b "$LAND_BRANCH" runyaga/main 2>&1
echo ""

# ── squash-merge ─────────────────────────────────────────────────────────────
echo "Squash-merging $REMOTE_BRANCH..."
cd "$WORKTREE_PATH"

if ! git merge --squash "$REMOTE_BRANCH" 2>&1; then
  echo ""
  echo "MERGE CONFLICTS detected."
  echo "Resolve them in: $WORKTREE_PATH"
  echo "Then run validate_pr.sh manually:"
  echo "  cd $WORKTREE_PATH"
  echo "  tool/validate_pr.sh ${VALIDATE_ARGS[*]}"
  exit 1
fi

echo ""
echo "Squash-merge complete. Changes staged."
git diff --cached --stat
echo ""

# ── pub get ──────────────────────────────────────────────────────────────────
echo "Running pub get..."
if command -v fvm >/dev/null 2>&1; then
  fvm flutter pub get 2>&1 | tail -3
else
  flutter pub get 2>&1 | tail -3
fi
echo ""

# ── validate ─────────────────────────────────────────────────────────────────
if $SKIP_VALIDATE; then
  echo "Skipping validation (--skip-validate)"
  echo ""
  echo "Worktree ready at: $WORKTREE_PATH"
  echo "Branch: $LAND_BRANCH"
  exit 0
fi

echo "Running validation..."
echo ""

# Commit staged changes temporarily so validate_pr.sh can diff against main
git commit -m "wip: squash-merge $FEATURE_BRANCH for validation" --no-verify 2>&1

VALIDATE_EXIT=0
tool/validate_pr.sh "${VALIDATE_ARGS[@]}" || VALIDATE_EXIT=$?

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Worktree: $WORKTREE_PATH"
echo "Branch:   $LAND_BRANCH"
echo ""
echo "Next steps:"
echo "  cd $WORKTREE_PATH"
if [[ $VALIDATE_EXIT -eq 0 ]]; then
  echo "  # Amend the commit message:"
  echo "  git commit --amend -m '<type>(<scope>): <description>'"
  echo "  git push runyaga $LAND_BRANCH"
  echo "  gh pr create --base main --title '...' --body '...'"
else
  echo "  # Fix validation failures, then:"
  echo "  git add -A && git commit --amend --no-edit"
  echo "  tool/validate_pr.sh ${VALIDATE_ARGS[*]}"
fi
echo "═══════════════════════════════════════════════════════"

exit $VALIDATE_EXIT
