# Phase A: Setup + Smoke Test

**Status:** pending
**Depends on:** none

## Objective

Install Patrol, configure the project, and create one smoke test that boots the
app against a `--no-auth-mode` backend and asserts a widget renders. After this
phase, `patrol test` is a valid command and produces a green test.

## Pre-flight Checklist

- [ ] Verify macOS bundle ID is `ai.soliplex.client` (in `macos/Runner.xcodeproj`)
- [ ] Check current Patrol version on [pub.dev](https://pub.dev/packages/patrol)
- [ ] Verify macOS entitlements include `com.apple.security.network.client`

## Deliverables

1. `pubspec.yaml` — Patrol deps + config section
2. `integration_test/patrol_test_config.dart` — Minimal shared helpers
3. `integration_test/smoke_test.dart` — One passing smoke test

## Implementation Steps

### Step 1: Add dependencies

**File:** `pubspec.yaml`

- [ ] Add `integration_test` SDK dependency to `dev_dependencies`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  patrol: ^4.3.0
  patrol_finders: ^3.0.0
```

- [ ] Add top-level `patrol:` configuration:

```yaml
patrol:
  app_name: Soliplex
  test_directory: integration_test
  macos:
    bundle_id: ai.soliplex.client
```

- [ ] Add `http` to `dev_dependencies` (for `verifyBackendOrFail`)
- [ ] Run `flutter pub get`

### Step 2: Install Patrol CLI

- [ ] Run `dart pub global activate patrol_cli`
- [ ] Verify `patrol --version` outputs version info
- [ ] Verify `patrol doctor` reports no blocking issues

### Step 3: Create integration_test directory and helpers

**File:** `integration_test/patrol_test_config.dart`

This file provides only what the smoke test needs — two helpers and one constant.
It is NOT a kitchen-sink shared harness. Grow it when real duplication appears.

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Backend URL from --dart-define.
const backendUrl = String.fromEnvironment(
  'SOLIPLEX_BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);

/// Fail fast if backend is unreachable.
Future<void> verifyBackendOrFail(String url) async {
  try {
    final res = await http
        .get(Uri.parse('$url/api/v1/rooms'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      fail('Backend returned ${res.statusCode} at $url/api/v1/rooms');
    }
  } catch (e) {
    fail('Backend unreachable at $url: $e');
  }
}

/// Streaming-safe alternative to pumpAndSettle.
Future<void> waitForCondition(
  WidgetTester tester, {
  required bool Function() condition,
  required Duration timeout,
  Duration step = const Duration(milliseconds: 200),
  String? failureMessage,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (condition()) return;
  }
  fail(failureMessage ?? 'Timed out after $timeout');
}

/// Workaround for Flutter macOS keyboard assertion bug.
void ignoreKeyboardAssertions() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('_pressedKeys.containsKey') ||
        msg.contains('KeyUpEvent is dispatched')) {
      return;
    }
    originalOnError?.call(details);
  };
}
```

### Step 4: Create smoke test

**File:** `integration_test/smoke_test.dart`

```dart
import 'package:patrol/patrol.dart';
import 'package:soliplex/core/models/soliplex_config.dart';
import 'package:soliplex/core/models/logo_config.dart';
// TODO: Import the actual app root widget and provider setup.
// Adjust these imports once we confirm the exact widget/provider names.

import 'patrol_test_config.dart';

void main() {
  patrolTest('smoke - backend reachable and app boots', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    // TODO: Pump the real app with no-auth provider overrides.
    // Use the existing ProviderScope.overrides pattern from test_helpers.dart.
    // Assert that at least one widget from the home/room screen renders.
  });
}
```

### Step 5: Verify

- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] `patrol --version` outputs version
- [ ] `patrol doctor` reports no blocking issues
- [ ] Existing `flutter test` suite still passes
- [ ] Smoke test passes:

```bash
patrol test --target integration_test/smoke_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

## Out of Scope

- Any auth flow (deferred to Phase C)
- Chat or room interaction tests (deferred to Phase B)
- Screenshot wrapper, dual-mode auth, dot-separated IDs
- Android/iOS configuration

## Review Gate

**Tool:** `mcp__gemini__read_files` with `gemini-3-pro-preview`

**Files:** `pubspec.yaml`, `integration_test/patrol_test_config.dart`,
`integration_test/smoke_test.dart`, `docs/planning/patrol/phase-a-setup-smoke.md`

**Prompt:**

```text
Review the Patrol setup and smoke test against the Phase A spec.

Check:
1. Patrol deps are current and correctly placed in dev_dependencies
2. integration_test SDK dependency is present
3. Patrol config has correct bundle ID and test_directory
4. verifyBackendOrFail fails fast with useful message
5. waitForCondition avoids pumpAndSettle for streaming safety
6. No unnecessary complexity (no dual-auth, no screenshot wrapper, no shared harness)
7. Smoke test is minimal — boots app, checks one widget

Report PASS or list specific issues.
```

## Success Criteria

- [ ] `patrol test` runs and produces a green test
- [ ] Backend preflight gives clear error when backend is down
- [ ] Zero analyzer issues
- [ ] Existing tests unaffected
