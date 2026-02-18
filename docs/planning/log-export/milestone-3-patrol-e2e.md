# Milestone 3: Patrol E2E Test for Log Export

**Branch**: `test/log-export-e2e`
**PR title**: `test(log-viewer): add Patrol E2E test for export button`
**Depends on**: Milestone 2 merged

## Goal

Add Patrol integration test coverage for the export button. This milestone
is separate because it modifies `patrol_helpers.dart` (which affects ALL
existing Patrol tests via `pumpTestApp`) and requires a live backend to run.

## Rationale for Separate PR

- `patrol_helpers.dart` changes (`logFileSaverProvider` override) affect
  every existing E2E test — `smoke_test.dart`, `live_chat_test.dart`,
  `oidc_test.dart`, `settings_test.dart`
- If the new override breaks something, it's easier to isolate and revert
- E2E test needs a live no-auth backend; separating lets M2 land while
  this is validated against CI

## Changes

### 1. Add `logFileSaverProvider` override to `pumpTestApp`

**File**: `integration_test/patrol_helpers.dart`

Add a no-op fake saver and include the provider override in both
`pumpTestApp` and `pumpAuthenticatedTestApp`:

```dart
import 'package:soliplex_frontend/features/log_viewer/log_file_saver.dart';

/// No-op file saver that prevents OS share sheet / browser download
/// from opening during Patrol tests.
class NoOpLogFileSaver implements LogFileSaver {
  @override
  Future<void> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async {}
}
```

Add to existing overrides list in `pumpTestApp`:

```dart
overrides: [
  preloadedPrefsProvider.overrideWithValue(harness.prefs),
  memorySinkProvider.overrideWithValue(harness.sink),
  shellConfigProvider.overrideWithValue(...),
  preloadedBaseUrlProvider.overrideWithValue(backendUrl),
  authProvider.overrideWith(NoAuthNotifier.new),
  logFileSaverProvider.overrideWithValue(NoOpLogFileSaver()),  // NEW
],
```

Same addition to `pumpAuthenticatedTestApp`.

### 2. Add dart pub global run patrol_cli test

**File**: `integration_test/settings_test.dart` (append)

```dart
patrolTest('settings - log viewer export button (no-auth)', ($) async {
  await verifyBackendOrFail(backendUrl);
  ignoreKeyboardAssertions();

  harness = TestLogHarness();
  await harness.initialize();

  try {
    await pumpTestApp($, harness);

    // Wait for app to boot.
    final settingsButton = find.byTooltip('Open settings');
    await waitForCondition(
      $.tester,
      condition: () => $.tester.any(settingsButton),
      timeout: const Duration(seconds: 10),
      failureMessage: 'Settings button did not appear',
    );
    await $.tester.tap(settingsButton);
    await $.tester.pump(const Duration(milliseconds: 500));

    // Navigate to Log Viewer (adjust finder to match actual tile).
    await $.tester.tap(find.text('View Logs'));
    await $.tester.pump(const Duration(milliseconds: 500));

    // Export button should be enabled (boot logs exist).
    final downloadButton = find.ancestor(
      of: find.byIcon(Icons.download),
      matching: find.byType(IconButton),
    );
    expect(downloadButton, findsOneWidget);
    expect(
      $.tester.widget<IconButton>(downloadButton).onPressed,
      isNotNull,
      reason: 'Export should be enabled — boot generated logs',
    );

    // Clear logs → export button should disable.
    await $.tester.tap(find.byTooltip('Clear all logs'));
    await $.tester.pump(const Duration(milliseconds: 500));

    expect(
      $.tester.widget<IconButton>(downloadButton).onPressed,
      isNull,
      reason: 'Export should be disabled after clearing logs',
    );
  } catch (e) {
    harness.dumpLogs(last: 50);
    rethrow;
  } finally {
    harness
      ..expectNoErrors()
      ..dispose();
  }
});
```

**Design decisions:**
- Does **not** tap the export button — avoids OS share sheet hang (finding #2)
- Serialization correctness is covered by M1 unit tests
- Platform saver is behind `NoOpLogFileSaver` — safe even if accidentally tapped
- Only verifies button state transitions (enabled → disabled after clear)
- `expectNoErrors()` in finally block catches any silent exceptions

### What the E2E test covers vs. manual

| Covered by E2E | Must remain manual |
|----------------|--------------------|
| Button enabled when logs exist | OS share sheet appears (native) |
| Button disabled after clearing logs | Browser download triggers (web) |
| Button discoverable in AppBar | Exported file content is valid JSONL |
| No exceptions during full app lifecycle | Share sheet anchored to button (iPad) |

## Files

| File | Action |
|------|--------|
| `integration_test/patrol_helpers.dart` | Edit — add `NoOpLogFileSaver` + provider override |
| `integration_test/settings_test.dart` | Edit — append dart pub global run patrol_cli test |

## Gates

1. `dart format .` — no changes
2. `flutter analyze --fatal-infos` — 0 issues
3. Existing Patrol tests still pass (smoke, settings, live_chat):
   - `dart pub global run patrol_cli test -t "smoke"` — passes
   - `dart pub global run patrol_cli test -t "settings - navigate"` — passes
   - `dart pub global run patrol_cli test -t "settings - network"` — passes
4. New test passes:
   - `dart pub global run patrol_cli test -t "log viewer export"` — passes (no-auth backend)
5. `flutter test` — full unit/widget suite passes (no regressions)
