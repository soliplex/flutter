# Phase A: Setup + Smoke Test

**Status:** pending
**Depends on:** none
**Logging level:** 1 (free observation + failure diagnostics)

## Objective

Install Patrol, configure the project, create `TestLogHarness`, and produce one
green smoke test that boots the app with full logging against a `--no-auth-mode`
backend. On failure, the harness automatically dumps the last 2000 log records.

## Pre-flight Checklist

- [ ] Verify macOS bundle ID is `ai.soliplex.client` (in `macos/Runner.xcodeproj`)
- [ ] Check current Patrol version on [pub.dev](https://pub.dev/packages/patrol)
- [ ] Verify macOS entitlements include `com.apple.security.network.client`
- [ ] Read `lib/core/logging/logging_provider.dart` to confirm required overrides
  (`preloadedPrefsProvider`, `shellConfigProvider`)
- [ ] Read `test/helpers/test_helpers.dart` for existing provider override patterns

## Deliverables

1. `pubspec.yaml` — Patrol deps + config section
2. `integration_test/test_log_harness.dart` — Logging-aware test harness
3. `integration_test/patrol_test_config.dart` — Shared helpers and constants
4. `integration_test/smoke_test.dart` — One passing smoke test

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

- [ ] Run `flutter pub get`
- [ ] Note: `http` is already in `dependencies`, no need to add to `dev_dependencies`

### Step 2: Install Patrol CLI

- [ ] Run `dart pub global activate patrol_cli`
- [ ] Verify `patrol --version` outputs version info
- [ ] Verify `patrol doctor` reports no blocking issues

### Step 3: Create TestLogHarness

**File:** `integration_test/test_log_harness.dart`

The harness wraps `MemorySink` and `LogManager` for test use. It provides:

- Provider overrides needed to boot the app with logging
- `waitForLog()` — stream-based wait for internal events
- `expectLog()` — synchronous assertion on past log records
- `dumpLogs()` — dump MemorySink contents on failure

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

// Import the actual providers from the app
import 'package:soliplex/core/logging/logging_provider.dart';

class TestLogHarness {
  late final MemorySink sink;

  /// Initialize logging and return provider overrides.
  /// Caller adds these to ProviderScope.overrides.
  Future<List<Override>> initialize() async {
    SharedPreferences.setMockInitialValues({
      'log_level': 0, // LogLevel.trace
      'console_logging': true,
      'backend_logging': false, // No backend shipping in Phase A/B
    });
    final prefs = await SharedPreferences.getInstance();

    sink = MemorySink(maxRecords: 5000);
    LogManager.instance.addSink(sink);
    LogManager.instance.minimumLevel = LogLevel.trace;

    return [
      preloadedPrefsProvider.overrideWithValue(prefs),
      memorySinkProvider.overrideWithValue(sink),
    ];
  }

  /// Wait for a specific log to appear (stream-based, replaces polling).
  Future<void> waitForLog(
    String loggerName,
    String messagePattern, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Check existing records first
    final found = sink.records.any(
      (r) => r.loggerName == loggerName &&
             r.message.contains(messagePattern),
    );
    if (found) return;

    // Wait for future record
    try {
      await sink.onRecord
          .firstWhere(
            (r) => r.loggerName == loggerName &&
                   r.message.contains(messagePattern),
          )
          .timeout(timeout);
    } on TimeoutException {
      dumpLogs(last: 50);
      fail('Timed out waiting for [$loggerName] "$messagePattern"');
    }
  }

  /// Assert a log record already exists in the buffer.
  void expectLog(String loggerName, String messagePattern) {
    final found = sink.records.any(
      (r) => r.loggerName == loggerName &&
             r.message.contains(messagePattern),
    );
    if (!found) {
      dumpLogs(last: 30);
      fail('Log not found: [$loggerName] containing "$messagePattern"');
    }
  }

  /// Dump recent logs to console (for failure diagnostics).
  void dumpLogs({int last = 100}) {
    final records = sink.records;
    final start = records.length > last ? records.length - last : 0;
    print('\n=== TEST LOG DUMP (last $last of ${records.length}) ===');
    for (var i = start; i < records.length; i++) {
      print(records[i].toString());
    }
    print('=== END LOG DUMP ===\n');
  }

  /// Clean up after test.
  void dispose() {
    LogManager.instance.removeSink(sink);
    sink.close();
  }
}
```

### Step 4: Create shared helpers

**File:** `integration_test/patrol_test_config.dart`

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
/// Uses /api/login which works in both no-auth and OIDC modes.
Future<void> verifyBackendOrFail(String url) async {
  try {
    final res = await http
        .get(Uri.parse('$url/api/login'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      fail('Backend returned ${res.statusCode} at $url/api/login');
    }
  } catch (e) {
    fail('Backend unreachable at $url: $e');
  }
}

/// Streaming-safe alternative to pumpAndSettle.
/// Phase B upgrades to harness.waitForLog() where possible.
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

### Step 5: Create smoke test

**File:** `integration_test/smoke_test.dart`

```dart
import 'package:patrol/patrol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'patrol_test_config.dart';
import 'test_log_harness.dart';

// TODO: Import app root widget, shellConfigProvider, authProvider.
// Confirm exact names from lib/core/providers/ and lib/main.dart.

void main() {
  late TestLogHarness harness;

  patrolTest('smoke - backend reachable and app boots', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    // Initialize logging harness
    harness = TestLogHarness();
    final loggingOverrides = await harness.initialize();

    try {
      // TODO: Pump the real app with required provider overrides:
      // - loggingOverrides (from harness)
      // - shellConfigProvider.overrideWithValue(testConfig)
      // - authProvider.overrideWith(_NoAuthNotifier.new)
      //
      // Confirm exact provider names and SoliplexConfig construction
      // by reading lib/core/providers/ and lib/main.dart.

      // TODO: Assert that a widget from the home/rooms screen renders.
      // This proves the full boot sequence works with logging.

    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness.dispose();
    }
  });
}
```

### Step 6: Verify

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

## Required Provider Overrides

These must be resolved during implementation (read the source to confirm):

| Provider | Why | Override With |
|----------|-----|---------------|
| `preloadedPrefsProvider` | App crashes without it | `SharedPreferences` mock (from harness) |
| `memorySinkProvider` | Test needs access to MemorySink | Test-scoped instance (from harness) |
| `shellConfigProvider` | App crashes without it | Test `SoliplexConfig` pointing at `backendUrl` |
| `authProvider` | Must skip real auth in no-auth mode | `_NoAuthNotifier` (returns `NoAuthRequired`) |

## Out of Scope

- Any auth flow (deferred to Phase C)
- Chat or room interaction tests (deferred to Phase B)
- Logfire correlation, testRunId injection (deferred to Phase C)
- Structured event vocabulary (deferred to Phase B)
- Android/iOS configuration

## Review Gate

**Tool:** `mcp__gemini__read_files` with `gemini-3-pro-preview`

**Files:** `pubspec.yaml`, `integration_test/test_log_harness.dart`,
`integration_test/patrol_test_config.dart`,
`integration_test/smoke_test.dart`,
`lib/core/logging/logging_provider.dart`,
`docs/planning/patrol/phase-a-setup-smoke.md`

**Prompt:**

```text
Review the Patrol setup, TestLogHarness, and smoke test against Phase A spec.

Check:
1. Patrol deps are current and correctly placed in dev_dependencies
2. integration_test SDK dependency is present
3. TestLogHarness correctly initializes MemorySink and LogManager
4. Provider overrides include preloadedPrefsProvider and memorySinkProvider
5. verifyBackendOrFail uses /api/login (works in both auth modes)
6. dumpLogs() called on failure for automatic diagnostics
7. waitForLog() checks existing records before subscribing to stream
8. Smoke test is minimal — boots app, checks one widget, dumps on failure

Report PASS or list specific issues.
```

## Success Criteria

- [ ] `patrol test` runs and produces a green test
- [ ] TestLogHarness initializes logging with MemorySink
- [ ] Failure automatically dumps last N log records to console
- [ ] Backend preflight gives clear error when backend is down
- [ ] Zero analyzer issues
- [ ] Existing tests unaffected
