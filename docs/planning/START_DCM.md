# DCM Adoption Guide

Step-by-step guide for adopting Dart Code Metrics (DCM) in the Soliplex Flutter
project with zero disruption to existing workflows.

---

## Table of Contents

1. [Goals](#goals)
2. [Stage 0: Installation](#stage-0-installation-optional)
3. [Stage 1: Metrics Only](#stage-1-metrics-only-no-enforcement)
4. [Stage 2: CI Integration](#stage-2-ci-integration-non-blocking)
5. [Stage 3: Simple Style Rules](#stage-3-simple-style-rules-warnings)
6. [Stage 4: Structural Rules](#stage-4-structural-rules-warnings)
7. [Stage 5: Architectural Rules](#stage-5-architectural-rules-errors)
8. [Stage 6: Full Enforcement](#stage-6-full-enforcement)
9. [Quick Reference](#quick-reference)
10. [Troubleshooting](#troubleshooting)

---

## Goals

1. **No breaking changes** - DCM must not block developers who don't have it
   installed
2. **Progressive adoption** - Start with metrics/warnings, graduate to errors
3. **CI integration** - Optional initially, mandatory once team is comfortable
4. **Staged lints** - Add rules in batches from least to most impactful

---

## Stage 0: Installation (Optional)

**Duration:** Day 1
**Risk:** None
**Blocking:** No

DCM is optional during rollout. The codebase compiles and runs without it.

### Prerequisites

- Dart SDK 3.5.0+
- Flutter 3.35.0+

### Developer Installation

#### macOS/Linux

```bash
# Install DCM CLI globally
dart pub global activate dcm_cli

# Verify installation
dcm --version
# Expected output: dcm_cli version: X.Y.Z
```

If `dcm: command not found` appears, add pub-cache to PATH:

```bash
# For zsh (default on macOS)
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### Windows

```powershell
# Install DCM CLI globally
dart pub global activate dcm_cli

# Add to PATH (if not already)
# Add %USERPROFILE%\AppData\Local\Pub\Cache\bin to your PATH environment variable

# Verify
dcm --version
```

### IDE Integration

#### VS Code

1. Open Extensions (Cmd+Shift+X / Ctrl+Shift+X)
2. Search "DCM"
3. Install "DCM" by Dmitry Zhifarsky
4. Restart VS Code

#### IntelliJ IDEA / Android Studio

DCM integrates automatically when configured in `analysis_options.yaml`. No
plugin required.

1. File > Invalidate Caches and Restart (after adding DCM config)

### Verification

```bash
# Navigate to project root
cd /path/to/soliplex-flutter

# Run analysis (should complete without errors)
dcm check lib --reporter=console

# Expected: Summary output with metrics (may show warnings - that's OK)
```

### Stage 0 Checklist

- [ ] DCM CLI installed (`dcm --version` works)
- [ ] PATH configured (command accessible from any directory)
- [ ] IDE extension installed (optional but recommended)
- [ ] `dcm check lib` runs without crashing

---

## Stage 1: Metrics Only (No Enforcement)

**Duration:** 1-2 weeks
**Risk:** Zero
**Blocking:** No

Establish baseline metrics. No rules enforced, just data collection.

### What This Stage Does

- Measures cyclomatic complexity per function
- Counts lines of code per function/class
- Reports parameter counts
- Identifies deep nesting

### File: dcm_options.yaml (Create New)

Create this file in the project root (`/soliplex-flutter/dcm_options.yaml`):

```yaml
# =============================================================================
# DCM Configuration - Stage 1: Metrics Only
# =============================================================================
# This file configures Dart Code Metrics (DCM) for static analysis.
# Stage 1 collects metrics without enforcing any rules.
#
# Documentation: https://dcm.dev/docs/configuration
# =============================================================================

dart_code_metrics:
  # ---------------------------------------------------------------------------
  # Metrics Thresholds
  # ---------------------------------------------------------------------------
  # These thresholds generate WARNINGS when exceeded.
  # Stage 1 uses relaxed values to establish a baseline.

  metrics:
    # Cyclomatic complexity measures decision points (if/else/switch/loops)
    # High complexity = hard to test and maintain
    # Relaxed: 20 (will tighten to 15 in Stage 5)
    cyclomatic-complexity: 20

    # Lines of executable code per function (excludes comments/blanks)
    # Long functions are hard to understand
    # Relaxed: 100 (will tighten to 50 in Stage 5)
    lines-of-code: 100

    # Maximum parameters per function/method
    # Many parameters suggest the function does too much
    # Relaxed: 7 (will tighten to 5 in Stage 5)
    number-of-parameters: 7

    # Maximum nesting depth (if inside if inside loop, etc.)
    # Deep nesting is hard to follow
    # Relaxed: 5 (will tighten to 4 in Stage 5)
    maximum-nesting-level: 5

  # ---------------------------------------------------------------------------
  # Exclusions
  # ---------------------------------------------------------------------------
  # Skip generated and third-party code

  metrics-exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"
    - "packages/soliplex_client/lib/src/schema/**"

  # ---------------------------------------------------------------------------
  # Rules
  # ---------------------------------------------------------------------------
  # Stage 1: No rules enabled - metrics collection only

  rules: []
```

### File: analysis_options.yaml (No Changes Required)

The existing `analysis_options.yaml` does not need modification for Stage 1.
DCM reads its configuration from `dcm_options.yaml` independently.

For reference, current file remains:

```yaml
include: package:very_good_analysis/analysis_options.6.0.0.yaml

analyzer:
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
    - 'build/**'

  errors:
    invalid_annotation_target: error

linter:
  rules:
    public_member_api_docs: false
    avoid_print: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
```

### Generate Baseline Report

```bash
# Generate HTML report (save for comparison)
dcm check lib --reporter=html --output-file=dcm_baseline_$(date +%Y%m%d).html

# Console summary
dcm check lib --reporter=console

# JSON for programmatic analysis
dcm check lib --reporter=json --output-file=dcm_baseline.json
```

### Understanding the Output

```text
lib/features/chat/chat_panel.dart:
  _handleSend:
    Cyclomatic Complexity: 12 (threshold: 20) ✓
    Lines of Code: 67 (threshold: 100) ✓
    ...
```

Values exceeding thresholds appear as warnings. In Stage 1, these are
informational only.

### Expected Violations (Known Technical Debt)

Based on MAINTENANCE.md, expect warnings in:

| File | Function | Metric | Value |
|------|----------|--------|-------|
| `chat_panel.dart` | `_handleSend` | lines-of-code | ~67 |
| `room_screen.dart` | `_initializeThreadSelection` | cyclomatic-complexity | ~8 |
| `quiz_provider.dart` | various | lines-of-code | file is 621 lines |

These are known issues tracked for remediation in Phase 1 of MAINTENANCE.md.

### Stage 1 Checklist

- [ ] `dcm_options.yaml` created in project root
- [ ] `dcm check lib` runs successfully
- [ ] Baseline HTML report saved with date stamp
- [ ] Team notified that DCM is available (optional to install)

---

## Stage 2: CI Integration (Non-Blocking)

**Duration:** 1 week
**Risk:** Zero
**Blocking:** No

Add DCM to CI pipeline. Reports results but never fails builds.

### What This Stage Does

- Installs DCM in CI environment
- Runs analysis on every PR
- Outputs results to CI logs
- Gracefully skips if installation fails

### File: .github/workflows/flutter.yaml (Full File)

Replace the entire workflow file:

```yaml
name: Flutter CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    env:
      SLACK_NOTIFY_URL: ${{ secrets.SLACK_NOTIFY_URL }}
    steps:
      - uses: actions/checkout@v6

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Cache pub dependencies
        uses: actions/cache@v5
        with:
          path: ~/.pub-cache
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-pub-

      - name: Install dependencies
        run: flutter pub get

      - name: Check formatting
        run: |
          find . -name "*.dart" \
            -not -path "./packages/soliplex_client/lib/src/schema/*" \
            | xargs dart format --set-exit-if-changed

      - name: Analyze code
        run: flutter analyze --fatal-infos

      # =========================================================================
      # DCM Analysis - Stage 2: Non-Blocking
      # =========================================================================
      # This step reports DCM findings but NEVER fails the build.
      # - continue-on-error: true ensures CI passes even with DCM warnings
      # - The script checks if DCM can be installed before running
      # - Output appears in CI logs for team visibility
      #
      # To advance to Stage 5 (blocking), remove continue-on-error and
      # change the dcm command to use --fatal-warnings
      # =========================================================================
      - name: DCM Analysis (non-blocking)
        continue-on-error: true
        run: |
          echo "::group::Installing DCM"
          if dart pub global activate dcm_cli 2>/dev/null; then
            echo "DCM installed successfully"
          else
            echo "::warning::DCM installation failed - skipping analysis"
            echo "::endgroup::"
            exit 0
          fi
          echo "::endgroup::"

          echo "::group::Running DCM Analysis"
          # Run DCM and capture exit code
          dcm check lib --reporter=console || DCM_EXIT=$?

          if [ "${DCM_EXIT:-0}" -ne 0 ]; then
            echo ""
            echo "::warning::DCM found issues (see above). This is non-blocking during rollout."
            echo "::warning::Fix these issues before Stage 5 enforcement begins."
          else
            echo ""
            echo "DCM analysis passed with no issues!"
          fi
          echo "::endgroup::"

          # Always exit 0 in Stage 2 (non-blocking)
          exit 0

      - name: Run tests with coverage
        run: flutter test --coverage

      - name: Check coverage threshold
        run: |
          sudo apt-get install -y lcov
          COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | sed 's/.*: \([0-9.]*\)%.*/\1/')
          echo "Coverage: ${COVERAGE}%"
          COVERAGE_INT=${COVERAGE%.*}
          if [ "$COVERAGE_INT" -lt 70 ]; then
            echo "::error::Coverage ${COVERAGE}% is below minimum 70%"
            exit 1
          fi
          echo "::notice::Coverage check passed with ${COVERAGE}%"

      - name: Build web (verification)
        run: flutter build web --release

      - name: Upload coverage artifact
        uses: actions/upload-artifact@v6
        with:
          name: coverage-report
          path: coverage/
          retention-days: 7

      - name: Notify Slack on failure
        if: failure()
        env:
          GITHUB_REF: ${{ github.ref }}
          COMMIT_MSG: ${{ github.event.head_commit.message }}
          RUN_URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: |
          curl -X POST \
            --data-urlencode \
            "payload={\"channel\": \"#soliplex\", \"username\": \"flutter-ci\", \"text\": \":x: Flutter CI failed on $GITHUB_REF:\n$COMMIT_MSG\n$RUN_URL\", \"icon_emoji\": \":flutter:\"}" \
            "$SLACK_NOTIFY_URL"
```

### CI Output Example

When the workflow runs, you'll see:

```text
▶ DCM Analysis (non-blocking)
  ::group::Installing DCM
  Resolving dependencies...
  Downloading dcm_cli X.Y.Z...
  DCM installed successfully
  ::endgroup::

  ::group::Running DCM Analysis
  lib/features/chat/chat_panel.dart:
    _handleSend - Lines of Code: 67 (warning)

  ⚠ 3 warnings found

  ::warning::DCM found issues (see above). This is non-blocking during rollout.
  ::warning::Fix these issues before Stage 5 enforcement begins.
  ::endgroup::

✓ DCM Analysis (non-blocking) completed with warnings (non-blocking)
```

### Stage 2 Checklist

- [ ] `.github/workflows/flutter.yaml` updated with DCM step
- [ ] PR opened to verify CI runs DCM
- [ ] DCM output visible in CI logs
- [ ] Build passes even with DCM warnings

---

## Stage 3: Simple Style Rules (Warnings)

**Duration:** 2 weeks
**Risk:** Low
**Blocking:** No

Enable rules with automatic fixes. Easy to remediate.

### What This Stage Does

- Adds 4 simple style rules
- All rules have auto-fix support via `dcm fix`
- Violations appear as warnings (non-blocking)

### Rules Explained

| Rule | What It Catches | Why It Matters |
|------|-----------------|----------------|
| `prefer-immediate-return` | `var x = expr; return x;` | Unnecessary variable |
| `avoid-redundant-async` | `async` without `await` | Misleading signature |
| `avoid-unnecessary-type-assertions` | `x as String` when x is String | Dead code |
| `prefer-trailing-comma` | Multi-line without trailing comma | Cleaner diffs |

### File: dcm_options.yaml (Replace)

```yaml
# =============================================================================
# DCM Configuration - Stage 3: Simple Style Rules
# =============================================================================
# Adds auto-fixable style rules. Run `dcm fix lib` to auto-remediate.
# =============================================================================

dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    lines-of-code: 100
    number-of-parameters: 7
    maximum-nesting-level: 5

  metrics-exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"
    - "packages/soliplex_client/lib/src/schema/**"

  # ---------------------------------------------------------------------------
  # Stage 3 Rules: Simple Style (Auto-Fixable)
  # ---------------------------------------------------------------------------
  rules:
    # -------------------------------------------------------------------------
    # prefer-immediate-return
    # -------------------------------------------------------------------------
    # BAD:
    #   final result = computeValue();
    #   return result;
    #
    # GOOD:
    #   return computeValue();
    #
    # Auto-fix: Yes
    # -------------------------------------------------------------------------
    - prefer-immediate-return

    # -------------------------------------------------------------------------
    # avoid-redundant-async
    # -------------------------------------------------------------------------
    # BAD:
    #   Future<int> getValue() async {
    #     return 42;  // No await anywhere
    #   }
    #
    # GOOD:
    #   Future<int> getValue() {
    #     return Future.value(42);
    #   }
    #
    # Auto-fix: Yes
    # -------------------------------------------------------------------------
    - avoid-redundant-async

    # -------------------------------------------------------------------------
    # avoid-unnecessary-type-assertions
    # -------------------------------------------------------------------------
    # BAD:
    #   String name = getName();
    #   print(name as String);  // Already a String!
    #
    # GOOD:
    #   String name = getName();
    #   print(name);
    #
    # Auto-fix: Yes
    # -------------------------------------------------------------------------
    - avoid-unnecessary-type-assertions

    # -------------------------------------------------------------------------
    # prefer-trailing-comma
    # -------------------------------------------------------------------------
    # BAD:
    #   Widget build(BuildContext context) {
    #     return Container(
    #       child: Text('Hello')  // Missing comma
    #     );
    #   }
    #
    # GOOD:
    #   Widget build(BuildContext context) {
    #     return Container(
    #       child: Text('Hello'),  // Trailing comma
    #     );
    #   }
    #
    # Why: Cleaner git diffs when adding/removing items
    # Auto-fix: Yes
    # -------------------------------------------------------------------------
    - prefer-trailing-comma
```

### Remediation Workflow

```bash
# Step 1: See all violations
dcm check lib --reporter=console

# Step 2: Count violations by rule
dcm check lib --reporter=json | jq -r '
  .records[]?.issues[]? |
  .ruleId
' | sort | uniq -c | sort -rn

# Step 3: Preview fixes (dry run)
dcm fix lib --dry-run

# Step 4: Apply fixes
dcm fix lib

# Step 5: Verify no violations remain
dcm check lib --reporter=console

# Step 6: Run formatter (fixes may change formatting)
dart format .

# Step 7: Run tests
flutter test
```

### Stage 3 Checklist

- [ ] `dcm_options.yaml` updated with Stage 3 rules
- [ ] `dcm check lib` run locally
- [ ] `dcm fix lib` applied to codebase
- [ ] All tests pass after fixes
- [ ] PR merged with Stage 3 rules

---

## Stage 4: Structural Rules (Warnings)

**Duration:** 2-3 weeks
**Risk:** Medium
**Blocking:** No

Rules that improve code structure. May require manual refactoring.

### What This Stage Does

- Adds 5 structural rules
- Some require manual fixes
- Catches Flutter-specific anti-patterns

### Rules Explained

| Rule | What It Catches | Auto-Fix |
|------|-----------------|----------|
| `prefer-correct-identifier-length` | `x`, `aa`, `veryLongVariableNameThatIsHardToRead` | No |
| `prefer-first` | `list[0]` instead of `list.first` | Yes |
| `prefer-last` | `list[list.length - 1]` | Yes |
| `avoid-unnecessary-setstate` | `setState` that doesn't change state | No |
| `avoid-returning-widgets` | Helper methods returning widgets | No |

### File: dcm_options.yaml (Replace)

```yaml
# =============================================================================
# DCM Configuration - Stage 4: Structural Rules
# =============================================================================
# Adds rules that catch structural issues. Some require manual refactoring.
# =============================================================================

dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    lines-of-code: 100
    number-of-parameters: 7
    maximum-nesting-level: 5

  metrics-exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"
    - "packages/soliplex_client/lib/src/schema/**"

  rules:
    # =========================================================================
    # Stage 3 Rules (carried forward)
    # =========================================================================
    - prefer-immediate-return
    - avoid-redundant-async
    - avoid-unnecessary-type-assertions
    - prefer-trailing-comma

    # =========================================================================
    # Stage 4 Rules: Structural
    # =========================================================================

    # -------------------------------------------------------------------------
    # prefer-correct-identifier-length
    # -------------------------------------------------------------------------
    # BAD:
    #   final x = getValue();
    #   for (var a in items) { ... }
    #
    # GOOD:
    #   final value = getValue();
    #   for (var item in items) { ... }
    #
    # Exceptions: i, j, k for loop indices; x, y for coordinates
    # Auto-fix: No (requires understanding context)
    # -------------------------------------------------------------------------
    - prefer-correct-identifier-length:
        exceptions:
          - i
          - j
          - k
          - x
          - y
          - id
          - db
          - io
        min-identifier-length: 2
        max-identifier-length: 40

    # -------------------------------------------------------------------------
    # prefer-first
    # -------------------------------------------------------------------------
    # BAD:
    #   final first = items[0];
    #
    # GOOD:
    #   final first = items.first;
    #
    # Why: .first throws StateError on empty list (explicit failure)
    #      [0] throws RangeError (less clear)
    # Auto-fix: Yes
    # -------------------------------------------------------------------------
    - prefer-first

    # -------------------------------------------------------------------------
    # prefer-last
    # -------------------------------------------------------------------------
    # BAD:
    #   final last = items[items.length - 1];
    #
    # GOOD:
    #   final last = items.last;
    #
    # Auto-fix: Yes
    # -------------------------------------------------------------------------
    - prefer-last

    # -------------------------------------------------------------------------
    # avoid-unnecessary-setstate
    # -------------------------------------------------------------------------
    # BAD:
    #   void _onTap() {
    #     setState(() {});  // Empty setState
    #   }
    #
    #   void _update() {
    #     _counter++;
    #     setState(() {
    #       // _counter already modified outside setState
    #     });
    #   }
    #
    # GOOD:
    #   void _update() {
    #     setState(() {
    #       _counter++;
    #     });
    #   }
    #
    # Auto-fix: No
    # -------------------------------------------------------------------------
    - avoid-unnecessary-setstate

    # -------------------------------------------------------------------------
    # avoid-returning-widgets
    # -------------------------------------------------------------------------
    # BAD:
    #   Widget _buildHeader() {
    #     return Text('Header');
    #   }
    #
    #   @override
    #   Widget build(BuildContext context) {
    #     return Column(children: [_buildHeader()]);
    #   }
    #
    # GOOD:
    #   class _Header extends StatelessWidget {
    #     @override
    #     Widget build(BuildContext context) => Text('Header');
    #   }
    #
    #   @override
    #   Widget build(BuildContext context) {
    #     return Column(children: [_Header()]);
    #   }
    #
    # Why: Widget classes can be const, have better rebuild optimization
    # Auto-fix: No
    # -------------------------------------------------------------------------
    - avoid-returning-widgets
```

### Manual Refactoring Guide

#### prefer-correct-identifier-length

```dart
// Find violations
dcm check lib --reporter=console | grep "prefer-correct-identifier-length"

// Common fixes:
// e -> event, error, element
// s -> state, string, source
// c -> context, controller, client
// r -> response, result, ref
```

#### avoid-returning-widgets

```dart
// BEFORE: Helper method
class MyScreen extends StatelessWidget {
  Widget _buildTitle() => Text('Title');

  @override
  Widget build(BuildContext context) {
    return Column(children: [_buildTitle()]);
  }
}

// AFTER: Extracted widget
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => const Text('Title');
}

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(children: [_Title()]);
  }
}
```

### Stage 4 Checklist

- [ ] `dcm_options.yaml` updated with Stage 4 rules
- [ ] All `prefer-first` and `prefer-last` auto-fixed
- [ ] Short identifiers reviewed and renamed
- [ ] Widget helper methods converted to classes (as appropriate)
- [ ] All tests pass

---

## Stage 5: Architectural Rules (Errors)

**Duration:** Ongoing
**Risk:** High (enforced)
**Blocking:** Yes

Enforce architectural boundaries. Violations fail CI.

### What This Stage Does

- Tightens metric thresholds
- Adds import boundary rules
- Violations become **errors** (fail CI)

### Rules Explained

| Rule | What It Enforces | From MAINTENANCE.md |
|------|------------------|---------------------|
| `avoid-banned-imports` (providers) | No `flutter_riverpod` in providers | Rule 6: The Ref Rule |
| `avoid-banned-imports` (client) | No Flutter in `soliplex_client` | Keep client pure Dart |
| `prefer-extracting-callbacks` | Short inline callbacks | Rule 7: No Fat UI |

### File: dcm_options.yaml (Replace)

```yaml
# =============================================================================
# DCM Configuration - Stage 5: Architectural Enforcement
# =============================================================================
# BLOCKING: Violations fail CI. Metric thresholds tightened.
# =============================================================================

dart_code_metrics:
  # ---------------------------------------------------------------------------
  # Tightened Metrics (Stage 5)
  # ---------------------------------------------------------------------------
  metrics:
    cyclomatic-complexity: 15    # Was 20
    lines-of-code: 50            # Was 100
    number-of-parameters: 5      # Was 7
    maximum-nesting-level: 4     # Was 5

  metrics-exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"
    - "packages/soliplex_client/lib/src/schema/**"

  rules:
    # =========================================================================
    # Stage 3 Rules
    # =========================================================================
    - prefer-immediate-return
    - avoid-redundant-async
    - avoid-unnecessary-type-assertions
    - prefer-trailing-comma

    # =========================================================================
    # Stage 4 Rules
    # =========================================================================
    - prefer-correct-identifier-length:
        exceptions: [i, j, k, x, y, id, db, io]
        min-identifier-length: 2
        max-identifier-length: 40
    - prefer-first
    - prefer-last
    - avoid-unnecessary-setstate
    - avoid-returning-widgets

    # =========================================================================
    # Stage 5 Rules: Architectural Boundaries
    # =========================================================================

    # -------------------------------------------------------------------------
    # avoid-banned-imports: Provider Layer Isolation
    # -------------------------------------------------------------------------
    # MAINTENANCE.md Rule 6: The Ref Rule
    #
    # Providers must accept `Ref`, not `WidgetRef`. This rule enforces that
    # by banning flutter_riverpod imports in the provider layer.
    #
    # BAD (in lib/core/providers/*.dart):
    #   import 'package:flutter_riverpod/flutter_riverpod.dart';
    #   void doThing(WidgetRef ref) { ... }
    #
    # GOOD:
    #   import 'package:riverpod/riverpod.dart';
    #   void doThing(Ref ref) { ... }
    # -------------------------------------------------------------------------
    - avoid-banned-imports:
        severity: error
        entries:
          - paths:
              - "lib/core/providers/**"
            deny:
              - "package:flutter_riverpod/flutter_riverpod.dart"
            message: |
              Providers must use Ref, not WidgetRef.
              Import 'package:riverpod/riverpod.dart' instead.
              See MAINTENANCE.md Rule 6.

    # -------------------------------------------------------------------------
    # avoid-banned-imports: Pure Dart Client
    # -------------------------------------------------------------------------
    # The soliplex_client package must have zero Flutter dependencies.
    # This ensures it can be used in CLI tools, servers, etc.
    #
    # BAD (in packages/soliplex_client/**):
    #   import 'package:flutter/foundation.dart';
    #
    # GOOD:
    #   import 'package:meta/meta.dart';  // Pure Dart alternative
    # -------------------------------------------------------------------------
    - avoid-banned-imports:
        severity: error
        entries:
          - paths:
              - "packages/soliplex_client/**"
            deny:
              - "package:flutter/foundation.dart"
              - "package:flutter/material.dart"
              - "package:flutter/widgets.dart"
              - "package:flutter/cupertino.dart"
              - "package:flutter/services.dart"
            message: |
              soliplex_client must be pure Dart with no Flutter dependencies.
              Use 'package:meta/meta.dart' for annotations.

    # -------------------------------------------------------------------------
    # prefer-extracting-callbacks
    # -------------------------------------------------------------------------
    # MAINTENANCE.md Rule 7: No Fat UI
    #
    # Inline callbacks should be short. Long callbacks indicate business
    # logic that belongs in a provider/controller.
    #
    # BAD:
    #   ElevatedButton(
    #     onPressed: () {
    #       // 20 lines of logic
    #     },
    #   )
    #
    # GOOD:
    #   ElevatedButton(
    #     onPressed: () => ref.read(controller).handlePress(),
    #   )
    # -------------------------------------------------------------------------
    - prefer-extracting-callbacks:
        allowed-line-count: 3
```

### File: .github/workflows/flutter.yaml (Update DCM Step)

Replace the DCM step with blocking enforcement:

```yaml
      # =========================================================================
      # DCM Analysis - Stage 5: Blocking Enforcement
      # =========================================================================
      # Violations now FAIL the build. All architectural rules enforced.
      # =========================================================================
      - name: DCM Analysis
        run: |
          echo "::group::Installing DCM"
          dart pub global activate dcm_cli
          echo "::endgroup::"

          echo "::group::Running DCM Analysis"
          dcm check lib \
            --fatal-style \
            --fatal-performance \
            --fatal-warnings
          echo "::endgroup::"
```

### Remediation Before Enabling Stage 5

Before switching to blocking mode, fix all known violations:

```bash
# List all violations that would fail CI
dcm check lib --fatal-style --fatal-performance --fatal-warnings

# Common fixes needed (from MAINTENANCE.md):
# 1. threads_provider.dart - Change WidgetRef to Ref
# 2. chat_panel.dart - Extract _handleSend to ChatController
# 3. room_screen.dart - Extract _initializeThreadSelection
```

### Stage 5 Checklist

- [ ] All Stage 3-4 violations fixed
- [ ] `threads_provider.dart` uses `Ref` not `WidgetRef`
- [ ] `soliplex_client` has no Flutter imports
- [ ] Long callbacks extracted to controllers
- [ ] `dcm check lib --fatal-warnings` passes locally
- [ ] CI updated to blocking mode
- [ ] Team notified of enforcement

---

## Stage 6: Full Enforcement

**Duration:** Permanent
**Risk:** None (team is trained)
**Blocking:** Yes

Production configuration. All rules active, strictest thresholds.

### File: dcm_options.yaml (Final)

```yaml
# =============================================================================
# DCM Configuration - Production
# =============================================================================
# Full enforcement. All rules active. Strictest thresholds.
# This is the final configuration after completing Stage 5 remediation.
# =============================================================================

dart_code_metrics:
  metrics:
    cyclomatic-complexity: 15
    lines-of-code: 50
    number-of-parameters: 5
    maximum-nesting-level: 4

  metrics-exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"
    - "packages/soliplex_client/lib/src/schema/**"

  rules:
    # Style (Stage 3)
    - prefer-immediate-return
    - avoid-redundant-async
    - avoid-unnecessary-type-assertions
    - prefer-trailing-comma

    # Structure (Stage 4)
    - prefer-correct-identifier-length:
        exceptions: [i, j, k, x, y, id, db, io]
        min-identifier-length: 2
        max-identifier-length: 40
    - prefer-first
    - prefer-last
    - avoid-unnecessary-setstate
    - avoid-returning-widgets

    # Architecture (Stage 5)
    - avoid-banned-imports:
        severity: error
        entries:
          - paths: ["lib/core/providers/**"]
            deny: ["package:flutter_riverpod/flutter_riverpod.dart"]
            message: "Providers must use Ref, not WidgetRef. See MAINTENANCE.md Rule 6."
          - paths: ["packages/soliplex_client/**"]
            deny:
              - "package:flutter/foundation.dart"
              - "package:flutter/material.dart"
              - "package:flutter/widgets.dart"
              - "package:flutter/cupertino.dart"
              - "package:flutter/services.dart"
            message: "soliplex_client must be pure Dart."
    - prefer-extracting-callbacks:
        allowed-line-count: 3
```

### File: .github/workflows/flutter.yaml (Final DCM Step)

```yaml
      - name: DCM Analysis
        run: |
          dart pub global activate dcm_cli
          dcm check lib \
            --fatal-style \
            --fatal-performance \
            --fatal-warnings
```

### Stage 6 Checklist

- [ ] All violations from baseline resolved
- [ ] CI has been blocking for 2+ weeks without issues
- [ ] Team comfortable with DCM workflow
- [ ] Documentation updated to reference DCM

---

## Quick Reference

### Commands

| Command | Purpose |
|---------|---------|
| `dcm check lib` | Analyze lib/ directory |
| `dcm check lib --reporter=console` | Human-readable output |
| `dcm check lib --reporter=json` | Machine-readable output |
| `dcm check lib --reporter=html --output-file=report.html` | HTML report |
| `dcm fix lib` | Auto-fix violations |
| `dcm fix lib --dry-run` | Preview fixes |
| `dcm check lib --fatal-warnings` | Exit 1 on any warning |
| `dcm check lib --fatal-style` | Exit 1 on style violations |

### Severity Levels

| Level | CI Impact | When to Use |
|-------|-----------|-------------|
| `warning` | Non-blocking | Stages 1-4 |
| `error` | Fails build | Stage 5+ |

### File Locations

| File | Purpose |
|------|---------|
| `dcm_options.yaml` | DCM configuration (project root) |
| `analysis_options.yaml` | Dart analyzer config (unchanged) |
| `.github/workflows/flutter.yaml` | CI workflow with DCM step |

---

## Troubleshooting

### DCM not found after install

```bash
# Check if installed
dart pub global list | grep dcm

# Add to PATH
export PATH="$PATH:$HOME/.pub-cache/bin"

# Permanent fix (add to shell config)
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
```

### Plugin not loading in IDE

1. Ensure `dcm_options.yaml` exists in project root
2. Restart IDE completely (not just reload)
3. Check IDE console for DCM errors

### Too many violations

This is expected when first enabling DCM. Follow the staged approach:

1. Stage 1: Observe and document violations
2. Stage 3: Fix auto-fixable rules first (`dcm fix lib`)
3. Stage 4: Manual refactoring for structural rules
4. Stage 5: Enforce only after remediation complete

### CI fails after enabling enforcement

```bash
# Temporarily revert to non-blocking
# In .github/workflows/flutter.yaml, add:
continue-on-error: true

# Fix violations locally
dcm check lib --fatal-warnings

# Remove continue-on-error after fixes merged
```

### Specific rule causing problems

Temporarily disable a rule while fixing:

```yaml
# In dcm_options.yaml
rules:
  # - avoid-returning-widgets  # Temporarily disabled - see issue #123
```

---

## Rollout Timeline Summary

| Stage | Week | Blocking | Key Action |
|-------|------|----------|------------|
| 0 | 0 | No | Installation guide published |
| 1 | 1-2 | No | Baseline metrics collected |
| 2 | 3 | No | CI reports (non-blocking) |
| 3 | 4-5 | No | Auto-fix style rules |
| 4 | 6-8 | No | Manual structural fixes |
| 5 | 9+ | **Yes** | Architectural enforcement |
| 6 | Permanent | **Yes** | Full production config |

---

## Related Documents

- [MAINTENANCE.md](./MAINTENANCE.md) - Architectural rules that DCM enforces
- [flutter_rules.md](../rules/flutter_rules.md) - Flutter coding standards
- [DCM Documentation](https://dcm.dev/docs/) - Official DCM docs
