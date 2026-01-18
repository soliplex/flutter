#!/bin/bash
# Gate Validation Script for AppShell Extraction
# Usage: ./scripts/validate_gate.sh [gate_number]

set -e

GATE=${1:-0}
COVERAGE_TARGET=85

echo "=== Gate $GATE Validation ==="
echo ""

# Step 1: Format check
echo "1. Checking code format..."
if dart format --set-exit-if-changed . > /dev/null 2>&1; then
    echo "   ✓ Code is properly formatted"
else
    echo "   ✗ Code formatting issues found"
    echo "   Run: dart format ."
    exit 1
fi

# Step 2: Analyzer
echo "2. Running analyzer..."
ANALYZER_OUTPUT=$(dart analyze lib/ 2>&1)
if echo "$ANALYZER_OUTPUT" | grep -q "No issues found"; then
    echo "   ✓ No analyzer issues"
else
    echo "   ✗ Analyzer issues found:"
    echo "$ANALYZER_OUTPUT"
    exit 1
fi

# Step 3: Tests
echo "3. Running tests..."
if flutter test --coverage > /dev/null 2>&1; then
    echo "   ✓ All tests pass"
else
    echo "   ✗ Tests failed"
    flutter test
    exit 1
fi

# Step 4: Coverage (only enforced for Gate 7)
echo "4. Checking coverage..."
if command -v lcov &> /dev/null && [ -f coverage/lcov.info ]; then
    COVERAGE=$(lcov --summary coverage/lcov.info 2>/dev/null | grep "lines" | grep -o '[0-9.]*%' | head -1 | tr -d '%')
    echo "   Coverage: ${COVERAGE}%"

    if [ "$GATE" -eq 7 ]; then
        if (( $(echo "$COVERAGE < $COVERAGE_TARGET" | bc -l) )); then
            echo "   ✗ Coverage ${COVERAGE}% is below target ${COVERAGE_TARGET}%"
            exit 1
        else
            echo "   ✓ Coverage meets target"
        fi
    else
        echo "   (Coverage enforcement deferred to Gate 7)"
    fi
else
    echo "   (lcov not available, skipping coverage check)"
fi

echo ""
echo "=== Gate $GATE PASSED ==="
echo ""
echo "Next steps:"
echo "  git tag -a gate-${GATE}-complete -m 'Gate ${GATE} Complete'"
echo "  git push origin gate-${GATE}-complete"
