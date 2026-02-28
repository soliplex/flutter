#!/usr/bin/env bash
# =============================================================================
# Milestone Review — soliplex-flutter-charting
# =============================================================================
# Runs tests/analyze, captures metrics delta, generates unified diff, and
# assembles a lean review prompt. The prompt contains instructions + metrics.
# Changed source files and the diff are passed separately to read_files.
#
# Ported from dart_monty/tool/slice_review.sh, adapted for Flutter project.
#
# Usage:
#   bash tool/milestone_review.sh M1                # full: tests + analyze + metrics
#   bash tool/milestone_review.sh M1 --skip-tests   # reuse existing lcov data
#   bash tool/milestone_review.sh M1 --skip-analyze  # skip flutter analyze
#   bash tool/milestone_review.sh M1 --skip-all      # skip both tests and analyze
#   bash tool/milestone_review.sh M1 --context path/to/file  # add unchanged context file
#   bash tool/milestone_review.sh M1 --plan docs/planning/monty-integration-roadmap.md
#   bash tool/milestone_review.sh M1 --range abc123..def456  # explicit commit range
#
# Diff scoping:
#   By default, the script auto-detects the commit range for the given
#   milestone by searching commit messages for "(M<N>)" or "(Milestone <N>)".
#   It diffs between the previous milestone's last commit and this milestone's
#   last commit. Use --range to override. Use --full to diff the entire branch
#   against main (legacy behavior).
#
# Plan auto-detection:
#   Looks for docs/planning/monty-m<N>-*.md first, then falls back to
#   docs/planning/monty-integration-roadmap.md. Use --plan to override.
#
# Output:
#   ci-review/milestone-reviews/M<N>-prompt.md   (review instructions)
#   ci-review/milestone-reviews/M<N>.diff         (unified diff)
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# -------------------------------------------------------
# Argument parsing
# -------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: bash tool/milestone_review.sh <milestone> [--skip-tests|--skip-analyze|--skip-all] [--context <file>] [--plan <file>] [--range BASE..HEAD] [--full]"
  echo ""
  echo "Milestones: M0, M1, M2, M3, M4"
  exit 1
fi

MILESTONE="$1"
shift

# Extract numeric part (M0 → 0, M1 → 1, etc.)
MILESTONE_NUM="${MILESTONE#M}"
if ! [[ "$MILESTONE_NUM" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Milestone must be M0, M1, M2, M3, or M4 (got: $MILESTONE)"
  exit 1
fi

SKIP_TESTS=false
SKIP_ANALYZE=false
CONTEXT_FILES=()
PLAN_OVERRIDE=""
DIFF_RANGE=""
FULL_BRANCH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)   SKIP_TESTS=true ;;
    --skip-analyze) SKIP_ANALYZE=true ;;
    --skip-all)     SKIP_TESTS=true; SKIP_ANALYZE=true ;;
    --context)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --context requires a file path argument"
        exit 1
      fi
      if [[ ! -f "$1" ]]; then
        echo "ERROR: context file not found: $1"
        exit 1
      fi
      CONTEXT_FILES+=("$1")
      ;;
    --plan)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --plan requires a file path argument"
        exit 1
      fi
      PLAN_OVERRIDE="$1"
      ;;
    --range)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --range requires BASE..HEAD argument"
        exit 1
      fi
      DIFF_RANGE="$1"
      ;;
    --full)
      FULL_BRANCH=true
      ;;
    *)
      echo "Unknown flag: $1"
      exit 1
      ;;
  esac
  shift
done

OUTPUT_DIR="$ROOT/ci-review/milestone-reviews"
OUTPUT_FILE="$OUTPUT_DIR/${MILESTONE}-prompt.md"
DIFF_FILE="$OUTPUT_DIR/${MILESTONE}.diff"
BASELINE_FILE="$ROOT/ci-review/baseline.json"

# Plan file resolution
ROADMAP_FILE="$ROOT/docs/planning/monty-integration-roadmap.md"

if [[ -n "$PLAN_OVERRIDE" ]]; then
  if [[ "$PLAN_OVERRIDE" = /* ]]; then
    MILESTONE_PLAN="$PLAN_OVERRIDE"
  else
    MILESTONE_PLAN="$ROOT/$PLAN_OVERRIDE"
  fi
else
  # Auto-detect: look for monty-m<N>-*.md
  MILESTONE_PLAN=$(find "$ROOT/docs/planning" -name "monty-m${MILESTONE_NUM}-*.md" -type f 2>/dev/null | head -1)
  if [[ -z "$MILESTONE_PLAN" ]]; then
    MILESTONE_PLAN="$ROADMAP_FILE"
  fi
fi

mkdir -p "$OUTPUT_DIR"

# -------------------------------------------------------
# Validate prerequisites
# -------------------------------------------------------
MERGE_BASE=$(git merge-base main HEAD 2>/dev/null || echo "")

# Auto-refresh baseline from merge-base with main if stale.
if [[ -n "$MERGE_BASE" && -f "$BASELINE_FILE" ]]; then
  BASELINE_SHA=$(jq -r '.git_sha // ""' "$BASELINE_FILE" 2>/dev/null || echo "")
  MERGE_BASE_SHORT=$(git rev-parse --short "$MERGE_BASE")
  if [[ "$BASELINE_SHA" != "$MERGE_BASE_SHORT" ]]; then
    echo "=== Baseline stale (was $BASELINE_SHA, need $MERGE_BASE_SHORT) — refreshing ==="
    bash tool/metrics.sh > "$BASELINE_FILE"
    echo "  Baseline updated to $MERGE_BASE_SHORT"
  fi
fi

# Create baseline if it doesn't exist
if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "=== No baseline found — capturing now ==="
  mkdir -p "$(dirname "$BASELINE_FILE")"
  if [[ -f "$ROOT/tool/metrics.sh" ]]; then
    bash tool/metrics.sh > "$BASELINE_FILE"
  else
    # Generate minimal baseline inline
    echo "  (tool/metrics.sh not found — generating minimal baseline)"
    cat > "$BASELINE_FILE" << BASELINE_JSON
{
  "git_sha": "$(git rev-parse --short HEAD)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "packages": {},
  "note": "auto-generated minimal baseline"
}
BASELINE_JSON
  fi
fi

if [[ ! -f "$MILESTONE_PLAN" ]]; then
  echo "ERROR: Milestone plan not found: $MILESTONE_PLAN"
  exit 1
fi

echo "  Plan file: $MILESTONE_PLAN"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed"
  exit 1
fi

# -------------------------------------------------------
# Tempfiles — cleaned on exit
# -------------------------------------------------------
METRICS_AFTER=$(mktemp)
ANALYZE_OUTPUT=$(mktemp)
trap 'rm -f "$METRICS_AFTER" "$ANALYZE_OUTPUT"' EXIT

# -------------------------------------------------------
# Phase 1: Run tests (unless --skip-tests)
# -------------------------------------------------------
if [[ "$SKIP_TESTS" == false ]]; then
  echo "=== Phase 1: Running tests ==="
  set +e

  # Root-level tests
  flutter test 2>&1 | tail -5
  ROOT_EXIT=${PIPESTATUS[0]}

  # Package tests
  PKG_EXIT=0
  for pkg_dir in packages/*/; do
    if [[ -d "$pkg_dir/test" ]]; then
      echo "  Testing $pkg_dir..."
      (cd "$pkg_dir" && flutter test 2>&1 | tail -3)
      if [[ ${PIPESTATUS[0]} -ne 0 ]]; then PKG_EXIT=1; fi
    fi
  done

  set -e
  if [[ $ROOT_EXIT -ne 0 || $PKG_EXIT -ne 0 ]]; then
    TEST_STATUS="FAILED"
  else
    TEST_STATUS="PASSED"
  fi
else
  echo "=== Phase 1: SKIPPED (--skip-tests) ==="
  TEST_STATUS="SKIPPED"
fi

# -------------------------------------------------------
# Phase 2: Run flutter analyze (unless --skip-analyze)
# -------------------------------------------------------
if [[ "$SKIP_ANALYZE" == false ]]; then
  echo "=== Phase 2: Running flutter analyze ==="
  set +e
  flutter analyze --fatal-infos > "$ANALYZE_OUTPUT" 2>&1
  ANALYZE_EXIT=$?
  set -e
  if [[ $ANALYZE_EXIT -eq 0 ]]; then
    ANALYZE_STATUS="PASSED"
    ANALYZE_SUMMARY="No issues found."
  else
    ANALYZE_STATUS="FAILED (exit $ANALYZE_EXIT)"
    ANALYZE_SUMMARY="$(tail -20 "$ANALYZE_OUTPUT")"
  fi
else
  echo "=== Phase 2: SKIPPED (--skip-analyze) ==="
  ANALYZE_STATUS="SKIPPED"
  ANALYZE_SUMMARY="(analyze skipped via --skip-analyze)"
fi

# -------------------------------------------------------
# Phase 3: Capture metrics
# -------------------------------------------------------
echo "=== Phase 3: Capturing metrics ==="

# Count source and test lines per package
capture_pkg_metrics() {
  local pkg_name="$1"
  local pkg_dir="$2"
  local src_lines=0
  local test_lines=0
  local test_count=0

  if [[ -d "$pkg_dir/lib" ]]; then
    src_lines=$(find "$pkg_dir/lib" -name '*.dart' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [[ -d "$pkg_dir/test" ]]; then
    test_lines=$(find "$pkg_dir/test" -name '*.dart' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    test_count=$(grep -r 'test(' "$pkg_dir/test" --include='*.dart' -l 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "    \"$pkg_name\": {\"source_lines\": $src_lines, \"test_lines\": $test_lines, \"test_count\": $test_count}"
}

{
  echo "{"
  echo "  \"git_sha\": \"$(git rev-parse --short HEAD)\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"packages\": {"

  FIRST=true
  # Root lib/
  if [[ "$FIRST" == false ]]; then echo ","; fi
  capture_pkg_metrics "soliplex_app" "."
  FIRST=false

  for pkg_dir in packages/*/; do
    pkg_name=$(basename "$pkg_dir")
    echo ","
    capture_pkg_metrics "$pkg_name" "$pkg_dir"
  done

  echo ""
  echo "  }"
  echo "}"
} > "$METRICS_AFTER"

# -------------------------------------------------------
# Phase 4: Determine diff range + collect git data
# -------------------------------------------------------
echo "=== Phase 4: Collecting git data ==="
GIT_SHA=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

DIFF_BASE="main"
DIFF_HEAD="HEAD"

if [[ -n "$DIFF_RANGE" ]]; then
  DIFF_BASE="${DIFF_RANGE%%..*}"
  DIFF_HEAD="${DIFF_RANGE##*..}"
  echo "  Using explicit range: ${DIFF_BASE}..${DIFF_HEAD}"
elif [[ "$FULL_BRANCH" == true ]]; then
  echo "  Using full branch diff against main"
else
  # Auto-detect: find commits tagged with "(M<N>)" in commit messages
  MILESTONE_COMMIT=$(git log --format='%H %s' main..HEAD 2>/dev/null \
    | grep -iE "\(M${MILESTONE_NUM}\)|\(Milestone ${MILESTONE_NUM}\)" | head -1 | awk '{print $1}')
  if [[ -n "$MILESTONE_COMMIT" ]]; then
    DIFF_HEAD="$MILESTONE_COMMIT"
    # Walk backwards to find the previous milestone's commit as the base
    PREV=$((MILESTONE_NUM - 1))
    FOUND_PREV=false
    while [[ $PREV -ge 0 ]]; do
      PREV_COMMIT=$(git log --format='%H %s' main..HEAD 2>/dev/null \
        | grep -iE "\(M${PREV}\)|\(Milestone ${PREV}\)" | head -1 | awk '{print $1}')
      if [[ -n "$PREV_COMMIT" ]]; then
        DIFF_BASE="$PREV_COMMIT"
        FOUND_PREV=true
        break
      fi
      PREV=$((PREV - 1))
    done
    if [[ "$FOUND_PREV" == false ]]; then
      DIFF_BASE="${MERGE_BASE:-main}"
    fi
    echo "  Auto-detected range: $(git rev-parse --short "$DIFF_BASE")..$(git rev-parse --short "$DIFF_HEAD")"
  else
    echo "  WARNING: No commit matching '(M${MILESTONE_NUM})' — falling back to full branch diff"
  fi
fi

DIFF_STAT=$(git diff "$DIFF_BASE" "$DIFF_HEAD" --stat 2>/dev/null || echo "(could not compute diff stat)")

# Generate unified diff — exclude lockfiles and generated code
git diff "$DIFF_BASE" "$DIFF_HEAD" -- . \
  ':(exclude)*.lock' ':(exclude)*.g.dart' ':(exclude)*.freezed.dart' \
  ':(exclude)*.mocks.dart' > "$DIFF_FILE" 2>/dev/null
DIFF_SIZE=$(wc -c < "$DIFF_FILE" | tr -d ' ')

# Collect changed source/test files (skip docs, config, deleted files)
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ ! -f "$ROOT/$file" ]] && continue
  case "$file" in
    *.md|*.yaml|*.yml|*.toml|*.json|*.lock) continue ;;
  esac
  CHANGED_FILES+=("$file")
done < <(git diff "$DIFF_BASE" "$DIFF_HEAD" --name-only 2>/dev/null)

# -------------------------------------------------------
# Phase 5: Extract milestone spec
# -------------------------------------------------------
echo "=== Phase 5: Extracting milestone spec ==="
if [[ "$MILESTONE_PLAN" != "$ROADMAP_FILE" ]]; then
  # Dedicated milestone file — use the whole file
  MILESTONE_SPEC=$(cat "$MILESTONE_PLAN")
else
  # Extract section from the roadmap
  MILESTONE_SPEC=$(awk "
    /^## M${MILESTONE_NUM}:/ { found=1; print; next }
    found && /^---\$/ { exit }
    found && /^## M[0-9]/ { exit }
    found { print }
  " "$ROADMAP_FILE")
fi

if [[ -z "$MILESTONE_SPEC" ]]; then
  MILESTONE_SPEC="(Milestone $MILESTONE spec not found in $MILESTONE_PLAN)"
fi

# -------------------------------------------------------
# Phase 6: Compute metrics delta
# -------------------------------------------------------
echo "=== Phase 6: Computing metrics delta ==="

pkg_metric() {
  local file="$1" pkg="$2" field="$3"
  jq -r ".packages.\"$pkg\".\"$field\" // \"N/A\"" "$file"
}

delta() {
  local before="$1" after="$2"
  if [[ "$before" == "N/A" || "$before" == "null" || "$after" == "N/A" || "$after" == "null" ]]; then
    echo "—"
  else
    local d=$(( after - before ))
    if [[ $d -gt 0 ]]; then echo "+$d"
    elif [[ $d -eq 0 ]]; then echo "0"
    else echo "$d"
    fi
  fi
}

FLUTTER_PACKAGES=(
  soliplex_app
  soliplex_client
  soliplex_client_native
  soliplex_logging
  soliplex_monty
)

AFFECTED_PKGS=()
UNAFFECTED_PKGS=()
METRICS_LINES=""

for pkg in "${FLUTTER_PACKAGES[@]}"; do
  has_delta=false
  for field in source_lines test_lines test_count; do
    b=$(pkg_metric "$BASELINE_FILE" "$pkg" "$field")
    a=$(pkg_metric "$METRICS_AFTER" "$pkg" "$field")
    d=$(delta "$b" "$a")
    if [[ "$d" != "0" && "$d" != "—" ]]; then
      has_delta=true
    fi
  done
  if [[ "$has_delta" == true ]]; then
    AFFECTED_PKGS+=("$pkg")
    src_b=$(pkg_metric "$BASELINE_FILE" "$pkg" "source_lines")
    src_a=$(pkg_metric "$METRICS_AFTER" "$pkg" "source_lines")
    src_d=$(delta "$src_b" "$src_a")
    tst_b=$(pkg_metric "$BASELINE_FILE" "$pkg" "test_lines")
    tst_a=$(pkg_metric "$METRICS_AFTER" "$pkg" "test_lines")
    tst_d=$(delta "$tst_b" "$tst_a")
    cnt_b=$(pkg_metric "$BASELINE_FILE" "$pkg" "test_count")
    cnt_a=$(pkg_metric "$METRICS_AFTER" "$pkg" "test_count")
    cnt_d=$(delta "$cnt_b" "$cnt_a")
    METRICS_LINES="$METRICS_LINES
- **$pkg**: source ${src_d} (${src_a}), tests ${tst_d} (${tst_a} lines, ${cnt_a} tests)"
  else
    UNAFFECTED_PKGS+=("$pkg")
  fi
done

METRICS_SUMMARY="**Affected packages:**$METRICS_LINES"
if [[ ${#UNAFFECTED_PKGS[@]} -gt 0 ]]; then
  UNAFFECTED_LIST=$(printf '%s' "${UNAFFECTED_PKGS[0]}"; printf ', %s' "${UNAFFECTED_PKGS[@]:1}")
  METRICS_SUMMARY="$METRICS_SUMMARY
- **Containment:** No changes in ${UNAFFECTED_LIST}."
fi

# -------------------------------------------------------
# Phase 7: Build file list for read_files
# -------------------------------------------------------
echo "=== Phase 7: Building file list ==="

FILES_JSON="[\"$OUTPUT_FILE\",\"$DIFF_FILE\""
if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
  for file in "${CHANGED_FILES[@]}"; do
    FILES_JSON="$FILES_JSON,\"$ROOT/$file\""
  done
fi
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
  for file in "${CONTEXT_FILES[@]}"; do
    if [[ "$file" = /* ]]; then
      FILES_JSON="$FILES_JSON,\"$file\""
    else
      FILES_JSON="$FILES_JSON,\"$ROOT/$file\""
    fi
  done
fi
FILES_JSON="$FILES_JSON]"

FILE_COUNT=$(( 2 + ${#CHANGED_FILES[@]} + ${#CONTEXT_FILES[@]} ))

# -------------------------------------------------------
# Phase 8: Assemble prompt markdown
# -------------------------------------------------------
echo "=== Phase 8: Assembling prompt ==="

cat > "$OUTPUT_FILE" << PROMPT
# Milestone $MILESTONE Review

You are a strict, adversarial Principal Engineer reviewing
Milestone $MILESTONE for the soliplex-flutter-charting project.
Do not trust the author's stated intentions — verify every claim
against the unified diff.

The unified diff is provided as \`${MILESTONE}.diff\`. The changed
source files are provided alongside this prompt. Read the diff first,
then cross-reference with the source files. Any additional files after the
changed sources are **context files** — unchanged pre-existing code included
so you can verify claims about existing infrastructure without guessing.

**Branch:** $GIT_BRANCH | **SHA:** $GIT_SHA | **Date:** $GIT_DATE

---

## Review Rubric

Check each item. Flag violations explicitly.

1. **Correctness**: Does the diff implement what the milestone spec says?
2. **Containment**: Are changes scoped to the milestone? No scope creep.
3. **Tests**: Are new/changed code paths tested? Coverage not regressed.
4. **Style**: Matches surrounding code. No \`// ignore:\` directives.
5. **Platform safety**: No \`dart:ffi\`/\`dart:isolate\` in unconditional imports.
   Conditional imports used where needed.
6. **KISS/YAGNI**: No over-engineering. No premature abstractions.
7. **Immutability**: New types immutable where possible.
8. **Linting**: \`very_good_analysis\` compliant. Zero warnings.

---

## Milestone Spec

$MILESTONE_SPEC

---

## Diff Stats

\`\`\`text
$DIFF_STAT
\`\`\`

## Metrics Summary

$METRICS_SUMMARY

## Tests: $TEST_STATUS

## Analyze: $ANALYZE_STATUS

$ANALYZE_SUMMARY

---

*Generated by tool/milestone_review.sh*
PROMPT

# -------------------------------------------------------
# Done
# -------------------------------------------------------
OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
echo ""
echo "========================================"
echo "  Milestone $MILESTONE review ready"
echo "  Prompt:  $OUTPUT_FILE ($OUTPUT_SIZE bytes)"
echo "  Diff:    $DIFF_FILE ($DIFF_SIZE bytes)"
echo "  Files:   $FILE_COUNT total (prompt + diff + ${#CHANGED_FILES[@]} source + ${#CONTEXT_FILES[@]} context)"
echo "  Tests:   $TEST_STATUS"
echo "  Analyze: $ANALYZE_STATUS"
echo "========================================"
echo ""
echo "Next step:"
echo ""
echo "  mcp__gemini__read_files("
echo "    file_paths=$FILES_JSON,"
echo "    prompt=\"You are a strict Principal Engineer. Review this milestone."
echo "      The first file is the review prompt with rubric and metrics."
echo "      The second file is the unified diff — read it carefully."
echo "      Files after the diff are changed source files, followed by"
echo "      context files (unchanged, for verifying pre-existing state)."
echo "      Follow the review instructions exactly.\","
echo "    model=\"gemini-3.1-pro-preview\""
echo "  )"
echo ""
