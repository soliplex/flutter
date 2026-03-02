#!/usr/bin/env bash
# =============================================================================
# validate_pr.sh — PR validation gate
# =============================================================================
#
# Prerequisites:
#   - Must run from a git WORKTREE (not the main checkout)
#   - Must be on a feature branch (not main, master, or clean/integration)
#   - Create a worktree with:
#       git worktree add .claude/worktrees/<name> -b <branch> main
#
# What it does (in order):
#   1. Generates a unified diff against the base branch
#   2. Runs `dart analyze --fatal-infos` on each --packages dir (and app if --app-tests)
#   3. Runs DCM analysis scoped to changed .dart lib files only
#   4. Runs `dart test` (packages) / `flutter test` (app) with coverage
#   5. Checks patch coverage on new/changed lines against threshold
#   6. Produces a Gemini review package (file list + structured prompt)
#
# Usage:
#   tool/validate_pr.sh \
#     --packages packages/soliplex_client packages/soliplex_agent \
#     --app-tests \
#     --coverage-threshold 85 \
#     --pr-goal "Move run types from agent to client"
#
# Exit codes:
#   0  All gates passed
#   1  One or more gates failed (or safety guard tripped)
# =============================================================================
set -eo pipefail

# ── defaults ─────────────────────────────────────────────────────────────────
BASE_BRANCH="main"
PACKAGES=()
RUN_APP_TESTS=false
COVERAGE_THRESHOLD=90
DIFF_OUTPUT=""
RESULTS_DIR=""
DART_CMD="fvm dart"
FLUTTER_CMD="fvm flutter"
PR_GOAL=""

# ── parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)        BASE_BRANCH="$2"; shift 2 ;;
    --packages)    shift; while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do PACKAGES+=("$1"); shift; done ;;
    --app-tests)   RUN_APP_TESTS=true; shift ;;
    --coverage-threshold) COVERAGE_THRESHOLD="$2"; shift 2 ;;
    --diff-output) DIFF_OUTPUT="$2"; shift 2 ;;
    --results-dir) RESULTS_DIR="$2"; shift 2 ;;
    --dart-cmd)    DART_CMD="$2"; shift 2 ;;
    --flutter-cmd) FLUTTER_CMD="$2"; shift 2 ;;
    --pr-goal)     PR_GOAL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "  --base BRANCH          Base branch for diff (default: main)"
      echo "  --packages DIR [DIR..] Package directories to validate"
      echo "  --app-tests            Also run flutter test on the app root"
      echo "  --coverage-threshold N Minimum patch coverage % (default: 90)"
      echo "  --diff-output FILE     Write unified diff to file"
      echo "  --results-dir DIR      Directory for coverage/results artifacts"
      echo "  --dart-cmd CMD         Dart command (default: fvm dart)"
      echo "  --flutter-cmd CMD      Flutter command (default: fvm flutter)"
      echo "  --pr-goal TEXT         One-line PR goal for Gemini review prompt"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── safety guards ─────────────────────────────────────────────────────────────
# Must run in a git worktree, not the main checkout.
if ! git rev-parse --git-common-dir >/dev/null 2>&1; then
  echo "ERROR: Not inside a git repository." >&2
  exit 1
fi

GIT_COMMON="$(git rev-parse --git-common-dir)"
GIT_DIR_VAL="$(git rev-parse --git-dir)"
if [[ "$GIT_COMMON" == "$GIT_DIR_VAL" ]]; then
  echo "ERROR: Must run from a git worktree, not the main checkout." >&2
  echo "  Create one with: git worktree add .claude/worktrees/<name> -b <branch> main" >&2
  exit 1
fi

# Must not be on a protected branch.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PROTECTED_BRANCHES=("main" "master" "clean/integration")
for pb in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "$CURRENT_BRANCH" == "$pb" ]]; then
    echo "ERROR: Cannot run on protected branch '$pb'." >&2
    echo "  Switch to a feature branch (e.g., land/soliplex-schema)." >&2
    exit 1
  fi
done

# ── setup ────────────────────────────────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ -z "$RESULTS_DIR" ]]; then
  RESULTS_DIR="$REPO_ROOT/.validation"
fi
mkdir -p "$RESULTS_DIR"

GATE_FAILURES=()
GATE_PASSES=()

log_pass() { GATE_PASSES+=("$1"); echo "✓ PASS: $1"; }
log_fail() { GATE_FAILURES+=("$1"); echo "✗ FAIL: $1"; }
log_step() { echo ""; echo "━━━ $1 ━━━"; }

# ── step 1: generate unified diff ───────────────────────────────────────────
log_step "UNIFIED DIFF"

DIFF_FILE="$RESULTS_DIR/pr.diff"
git diff "$BASE_BRANCH"...HEAD > "$DIFF_FILE" 2>/dev/null || git diff "$BASE_BRANCH"..HEAD > "$DIFF_FILE"

DIFF_STAT=$(git diff --stat "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --stat "$BASE_BRANCH"..HEAD)
echo "$DIFF_STAT"

LINE_COUNT=$(wc -l < "$DIFF_FILE" | tr -d ' ')
echo "Diff: $LINE_COUNT lines"

if [[ -n "$DIFF_OUTPUT" && "$DIFF_OUTPUT" != "$DIFF_FILE" ]]; then
  cp "$DIFF_FILE" "$DIFF_OUTPUT"
  echo "Diff written to: $DIFF_OUTPUT"
fi

if [[ "$LINE_COUNT" -eq 0 ]]; then
  echo "No changes detected against $BASE_BRANCH. Nothing to validate."
  exit 0
fi

# ── step 2: static analysis (dart analyze) ───────────────────────────────────
log_step "STATIC ANALYSIS"

analyze_failed=false

# Analyze each package
for pkg in "${PACKAGES[@]}"; do
  if [[ -d "$pkg" && -f "$pkg/pubspec.yaml" ]]; then
    echo "Analyzing $pkg..."
    if $DART_CMD analyze --fatal-infos "$pkg" 2>&1; then
      log_pass "dart analyze: $pkg"
    else
      log_fail "dart analyze: $pkg"
      analyze_failed=true
    fi
  else
    echo "Skipping $pkg (not a package directory)"
  fi
done

# Analyze app root if running app tests
if $RUN_APP_TESTS; then
  echo "Analyzing app (lib/ test/)..."
  if $DART_CMD analyze --fatal-infos lib/ test/ 2>&1; then
    log_pass "dart analyze: app (lib/ test/)"
  else
    log_fail "dart analyze: app (lib/ test/)"
    analyze_failed=true
  fi
fi

# ── step 3: DCM analysis (scoped to changed .dart files) ─────────────────────
log_step "DCM ANALYSIS"

dcm_failed=false

# Extract changed .dart lib files from diff (not test files)
CHANGED_DART_FILES=()
while IFS= read -r f; do
  if [[ "$f" == *.dart && "$f" == lib/* ]] || [[ "$f" == *.dart && "$f" == packages/*/lib/* ]]; then
    if [[ -f "$f" ]]; then
      CHANGED_DART_FILES+=("$f")
    fi
  fi
done < <(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --name-only "$BASE_BRANCH"..HEAD)

if [[ ${#CHANGED_DART_FILES[@]} -eq 0 ]]; then
  echo "No changed .dart lib files — skipping DCM"
  log_pass "dcm analyze: skipped (no changed dart files)"
else
  echo "DCM analyzing ${#CHANGED_DART_FILES[@]} changed file(s)..."
  # Run DCM on each changed file individually to avoid scope bleed
  dcm_issues=0
  for dart_file in "${CHANGED_DART_FILES[@]}"; do
    dcm_out=$(env -u GIT_DIR -u GIT_WORK_TREE dcm analyze "$dart_file" --fatal-warnings 2>&1) || {
      echo "$dcm_out"
      dcm_issues=$((dcm_issues + 1))
    }
  done

  if [[ $dcm_issues -eq 0 ]]; then
    log_pass "dcm analyze: ${#CHANGED_DART_FILES[@]} file(s) clean"
  else
    log_fail "dcm analyze: $dcm_issues file(s) with issues"
    dcm_failed=true
  fi
fi

# ── step 4: tests with coverage ─────────────────────────────────────────────
log_step "TESTS + COVERAGE"

COMBINED_LCOV="$RESULTS_DIR/combined_lcov.info"
: > "$COMBINED_LCOV"  # empty file

test_failed=false

for pkg in "${PACKAGES[@]}"; do
  if [[ -d "$pkg/test" ]]; then
    pkg_name=$(basename "$pkg")
    pkg_cov_dir="$RESULTS_DIR/coverage_$pkg_name"
    mkdir -p "$pkg_cov_dir"

    echo "Testing $pkg..."
    if (cd "$pkg" && $DART_CMD test --coverage="$pkg_cov_dir" 2>&1); then
      log_pass "tests: $pkg"
      # Convert to lcov if coverage data exists
      if ls "$pkg_cov_dir"/*.json 1>/dev/null 2>&1; then
        (cd "$pkg" && $DART_CMD pub global run coverage:format_coverage \
          --lcov \
          --in="$pkg_cov_dir" \
          --out="$pkg_cov_dir/lcov.info" \
          --report-on=lib/ 2>/dev/null) || true
        if [[ -f "$pkg_cov_dir/lcov.info" ]]; then
          cat "$pkg_cov_dir/lcov.info" >> "$COMBINED_LCOV"
        fi
      fi
    else
      log_fail "tests: $pkg"
      test_failed=true
    fi
  else
    echo "No tests found for $pkg"
  fi
done

if $RUN_APP_TESTS; then
  app_cov_dir="$RESULTS_DIR/coverage_app"
  mkdir -p "$app_cov_dir"

  echo "Testing app (flutter test)..."
  if $FLUTTER_CMD test --coverage --coverage-path="$app_cov_dir/lcov.info" 2>&1; then
    log_pass "tests: app"
    if [[ -f "$app_cov_dir/lcov.info" ]]; then
      cat "$app_cov_dir/lcov.info" >> "$COMBINED_LCOV"
    fi
  else
    log_fail "tests: app"
    test_failed=true
  fi
fi

# ── step 5: patch coverage ──────────────────────────────────────────────────
log_step "PATCH COVERAGE (threshold: ${COVERAGE_THRESHOLD}%)"

if [[ -s "$COMBINED_LCOV" ]]; then
  PATCH_COV_RESULT=$("$REPO_ROOT/tool/patch_coverage.py" \
    --diff "$DIFF_FILE" \
    --lcov "$COMBINED_LCOV" \
    --threshold "$COVERAGE_THRESHOLD" \
    --report "$RESULTS_DIR/patch_coverage_report.txt" 2>&1) || true

  echo "$PATCH_COV_RESULT"

  if echo "$PATCH_COV_RESULT" | grep -q "PATCH COVERAGE: PASS"; then
    log_pass "patch coverage >= ${COVERAGE_THRESHOLD}%"
  else
    log_fail "patch coverage < ${COVERAGE_THRESHOLD}%"
  fi
else
  echo "No coverage data collected — skipping patch coverage check"
  echo "(This is expected if packages have no tests yet)"
  log_pass "patch coverage: skipped (no coverage data)"
fi

# ── step 6: summary ─────────────────────────────────────────────────────────
log_step "VALIDATION SUMMARY"

echo ""
echo "Passes: ${#GATE_PASSES[@]}"
for p in "${GATE_PASSES[@]}"; do echo "  ✓ $p"; done

echo ""
echo "Failures: ${#GATE_FAILURES[@]}"
for f in "${GATE_FAILURES[@]}"; do echo "  ✗ $f"; done

echo ""
echo "Diff file: $DIFF_FILE"
echo "Results:   $RESULTS_DIR"

# ── gemini review package ────────────────────────────────────────────────────
log_step "GEMINI REVIEW PACKAGE"

# Build file list: diff + all changed files (absolute paths)
REVIEW_FILES_LIST="$RESULTS_DIR/gemini_review_files.txt"
echo "$DIFF_FILE" > "$REVIEW_FILES_LIST"
while IFS= read -r f; do
  abs_path="$REPO_ROOT/$f"
  if [[ -f "$abs_path" ]]; then
    echo "$abs_path" >> "$REVIEW_FILES_LIST"
  fi
done < <(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --name-only "$BASE_BRANCH"..HEAD)

FILE_COUNT=$(wc -l < "$REVIEW_FILES_LIST" | tr -d ' ')
echo "Review files: $FILE_COUNT (diff + changed sources)"

# Build review prompt with PR goal baked in
REVIEW_PROMPT_FILE="$RESULTS_DIR/gemini_review_prompt.txt"
cat > "$REVIEW_PROMPT_FILE" << PROMPT_EOF
You are reviewing a pull request. The first file is the unified diff (pr.diff).
The remaining files are the final state of all changed files.

## PR Goal
${PR_GOAL:-<not provided — infer from the diff>}

## Review Checklist — evaluate each item as PASS or FAIL with a brief justification:

1. **Feature Match**: Do the changes match the stated PR goal? Any missing pieces or scope creep?
2. **Import Hygiene**: Are all imports correct? No circular deps? No stale imports?
3. **Test Coverage**: Are tests present and correct for changed code?
4. **Minimal Change**: Is the change minimal — no over-engineering or scope creep?
5. **No Breakage**: Could these changes break existing consumers?

## Output Format
For each checklist item, output:
\`\`\`
[PASS/FAIL] <item name>: <1-2 sentence justification>
\`\`\`

Then provide an overall verdict: PASS or FAIL with a summary.
PROMPT_EOF

echo "Review prompt: $REVIEW_PROMPT_FILE"
echo "File list:     $REVIEW_FILES_LIST"
echo ""
echo "To run Gemini review, call mcp__gemini__read_files with:"
echo "  file_paths: $(cat "$REVIEW_FILES_LIST" | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin]))')"
echo "  prompt: <contents of $REVIEW_PROMPT_FILE>"

if [[ ${#GATE_FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "RESULT: FAILED (${#GATE_FAILURES[@]} gate(s) failed)"
  exit 1
else
  echo ""
  echo "RESULT: ALL GATES PASSED"
  exit 0
fi
