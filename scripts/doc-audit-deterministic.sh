#!/usr/bin/env bash
# Deterministic documentation audit — Stage 1 (no LLM required)
# Runs assertions from MAINTENANCE.md and outputs structured JSON report.
set -euo pipefail

REPO_ROOT="${1:-.}"
TMPDIR_AUDIT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_AUDIT"' EXIT

# Use temp files so subshells can contribute findings
ASSERTIONS_FILE="$TMPDIR_AUDIT/assertions.jsonl"
BROKEN_FILE="$TMPDIR_AUDIT/broken.jsonl"
FRESHNESS_FILE="$TMPDIR_AUDIT/freshness.jsonl"
touch "$ASSERTIONS_FILE" "$BROKEN_FILE" "$FRESHNESS_FILE"

add_assertion() {
  local id="$1" name="$2" status="$3" detail="$4"
  printf '{"id":"%s","name":"%s","status":"%s","detail":"%s"}\n' \
    "$id" "$name" "$status" "$detail" >> "$ASSERTIONS_FILE"
}

echo "=== Doc Audit: Deterministic Stage ===" >&2

# ---------------------------------------------------------------------------
# A1: Public API Exports
# ---------------------------------------------------------------------------
echo "[A1] Checking soliplex_agent exports..." >&2
BARREL="$REPO_ROOT/packages/soliplex_agent/lib/soliplex_agent.dart"
if [ -f "$BARREL" ]; then
  EXPORT_COUNT=$(grep -c "^export" "$BARREL" || true)
  add_assertion "A1" "Public API exports exist" "pass" "$EXPORT_COUNT export statements found"
else
  add_assertion "A1" "Public API exports exist" "fail" "Barrel file not found"
fi

# ---------------------------------------------------------------------------
# A2: HostApi package contract — no visual-domain methods beyond grandfathered
# ---------------------------------------------------------------------------
echo "[A2] Checking HostApi package contract..." >&2
HOST_API="$REPO_ROOT/packages/soliplex_agent/lib/src/host/host_api.dart"
if [ -f "$HOST_API" ]; then
  # Only check actual method/field declarations, not comments or doc strings
  VIOLATIONS=$(grep -n 'chart\|widget\|form\|Chart\|Widget\|Form' "$HOST_API" \
    | grep -vE '^\s*[0-9]+:\s*//' \
    | grep -vE '//' \
    | grep -v 'import ' \
    | grep -v 'registerDataFrame\|registerChart\|getDataFrame\|updateChart\|chartId\|chartConfig' \
    || true)
  if [ -z "$VIOLATIONS" ]; then
    add_assertion "A2" "HostApi package contract" "pass" "No visual-domain methods beyond grandfathered"
  else
    CLEAN_VIOLATIONS=$(echo "$VIOLATIONS" | tr '\n' ' ' | tr '"' "'")
    add_assertion "A2" "HostApi package contract" "fail" "$CLEAN_VIOLATIONS"
  fi
else
  add_assertion "A2" "HostApi package contract" "fail" "File not found"
fi

# ---------------------------------------------------------------------------
# A3: Package READMEs exist
# ---------------------------------------------------------------------------
echo "[A3] Checking package READMEs..." >&2
MISSING_READMES=""
for pkg in "$REPO_ROOT"/packages/soliplex_*/; do
  if [ ! -f "$pkg/README.md" ]; then
    PKG_NAME=$(basename "$pkg")
    MISSING_READMES="${MISSING_READMES}${PKG_NAME} "
  fi
done
if [ -z "$MISSING_READMES" ]; then
  add_assertion "A3" "Package READMEs exist" "pass" "All packages have READMEs"
else
  add_assertion "A3" "Package READMEs exist" "fail" "Missing: $MISSING_READMES"
fi

# ---------------------------------------------------------------------------
# A4: No broken internal doc links
# ---------------------------------------------------------------------------
echo "[A4] Checking internal doc links..." >&2
while IFS= read -r file; do
  DIR=$(dirname "$file")
  LINKS=$(grep -oE '\]\([^)]+\.md[^)]*\)' "$file" 2>/dev/null | \
    sed 's/\](//;s/)$//;s/#.*//' || true)
  if [ -n "$LINKS" ]; then
    while IFS= read -r link; do
      case "$link" in http*) continue ;; esac
      case "$link" in ~*) continue ;; esac
      case "$link" in path.md*) continue ;; esac
      [ -z "$link" ] && continue
      TARGET="$DIR/$link"
      if [ ! -f "$TARGET" ]; then
        printf '{"file":"%s","link":"%s"}\n' "$file" "$link" >> "$BROKEN_FILE"
      fi
    done <<< "$LINKS"
  fi
done < <(find "$REPO_ROOT/docs" -name "*.md" -not -path "*/archive/*")

BROKEN_COUNT=$(wc -l < "$BROKEN_FILE" | tr -d ' ')
if [ "$BROKEN_COUNT" -eq 0 ]; then
  add_assertion "A4" "No broken internal doc links" "pass" "All links resolve"
else
  add_assertion "A4" "No broken internal doc links" "fail" "$BROKEN_COUNT broken links found"
fi

# ---------------------------------------------------------------------------
# A6: Pure Dart contract — no Flutter imports in pure Dart packages
# ---------------------------------------------------------------------------
echo "[A6] Checking pure Dart contract..." >&2
PURE_VIOLATIONS=""
for pkg in soliplex_agent soliplex_client soliplex_logging soliplex_scripting soliplex_interpreter_monty; do
  PKG_LIB="$REPO_ROOT/packages/$pkg/lib/"
  if [ -d "$PKG_LIB" ]; then
    FLUTTER_IMPORTS=$(grep -rl "import 'package:flutter" "$PKG_LIB" 2>/dev/null || true)
    if [ -n "$FLUTTER_IMPORTS" ]; then
      PURE_VIOLATIONS="${PURE_VIOLATIONS}${pkg} "
    fi
  fi
done
if [ -z "$PURE_VIOLATIONS" ]; then
  add_assertion "A6" "Pure Dart contract" "pass" "No Flutter imports in pure Dart packages"
else
  add_assertion "A6" "Pure Dart contract" "fail" "Violations: $PURE_VIOLATIONS"
fi

# ---------------------------------------------------------------------------
# Freshness markers
# ---------------------------------------------------------------------------
echo "[FRESHNESS] Scanning freshness markers..." >&2
TODAY=$(date -u +%Y-%m-%d)
while IFS= read -r file; do
  MARKER=$(grep -o 'freshness: verified=[0-9-]*, by=[a-z]*, next-check=[0-9-]*' "$file" 2>/dev/null || true)
  if [ -n "$MARKER" ]; then
    VERIFIED=$(echo "$MARKER" | sed 's/.*verified=\([0-9-]*\).*/\1/')
    NEXT_CHECK=$(echo "$MARKER" | sed 's/.*next-check=\([0-9-]*\).*/\1/')
    if [[ "$TODAY" > "$NEXT_CHECK" ]]; then
      STATUS="stale"
    else
      STATUS="current"
    fi
    printf '{"file":"%s","verified":"%s","next_check":"%s","status":"%s"}\n' \
      "$file" "$VERIFIED" "$NEXT_CHECK" "$STATUS" >> "$FRESHNESS_FILE"
  fi
done < <(find "$REPO_ROOT/docs" -name "*.md" -not -path "*/archive/*")

# ---------------------------------------------------------------------------
# Assemble final JSON report
# ---------------------------------------------------------------------------
ASSERTIONS=$(jq -s '.' "$ASSERTIONS_FILE")
BROKEN=$(jq -s '.' "$BROKEN_FILE")
FRESHNESS=$(jq -s '.' "$FRESHNESS_FILE")

PASS_COUNT=$(echo "$ASSERTIONS" | jq '[.[] | select(.status=="pass")] | length')
FAIL_COUNT=$(echo "$ASSERTIONS" | jq '[.[] | select(.status=="fail")] | length')
STALE_COUNT=$(echo "$FRESHNESS" | jq '[.[] | select(.status=="stale")] | length')

jq -n \
  --argjson assertions "$ASSERTIONS" \
  --argjson broken_links "$BROKEN" \
  --argjson freshness "$FRESHNESS" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson pass "$PASS_COUNT" \
  --argjson fail "$FAIL_COUNT" \
  --argjson stale "$STALE_COUNT" \
  --argjson broken_count "$BROKEN_COUNT" \
  '{
    assertions: $assertions,
    broken_links: $broken_links,
    freshness: $freshness,
    timestamp: $timestamp,
    summary: {
      pass: $pass,
      fail: $fail,
      stale_freshness: $stale,
      broken_links: $broken_count
    }
  }'

echo "" >&2
echo "=== Summary: $PASS_COUNT pass, $FAIL_COUNT fail, $STALE_COUNT stale, $BROKEN_COUNT broken links ===" >&2
