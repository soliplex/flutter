---
name: patrol
description: Run Patrol E2E integration tests on macOS, iOS, or Chrome. Use when writing, running, or debugging Patrol tests.
argument-hint: "[test-file|all]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Patrol E2E Test Skill

Run and manage Patrol integration tests for this Flutter project (macOS, iOS, and Chrome).

## Running Tests

**CLI location:** `patrol`

Always use `--device` to avoid the interactive device selection prompt.

### macOS (default)

```bash
# Run a specific test file
patrol test \
  --device macos \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000

# Run all integration tests
patrol test \
  --device macos \
  --target integration_test/ \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

### iOS (simulator)

Use a booted simulator's device ID or name. The `--ios` flag specifies the OS
version (defaults to `latest` — must match the simulator's OS).

```bash
# Run on a specific iOS simulator
patrol test \
  --device <DEVICE_ID> \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000

# If simulator OS != latest SDK, specify explicitly
patrol test \
  --device <DEVICE_ID> \
  --ios=18.6 \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

Use `xcrun simctl list devices booted` to find the device ID and OS version.

### Chrome (web)

Requires Node.js >= 18 (Playwright auto-installs on first run).

```bash
# Run a specific test in Chrome
patrol test \
  --device chrome \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000

# Run headless (for CI or no-GUI environments)
patrol test \
  --device chrome \
  --web-headless true \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000

# Custom viewport (default is browser-dependent)
patrol test \
  --device chrome \
  --web-viewport "1280x720" \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

If `$ARGUMENTS` is empty or "all", run against `integration_test/` (all tests).
If `$ARGUMENTS` is a filename like `smoke_test.dart`, run that specific file.

## Pre-flight Checks

Before running tests, verify:

1. **Backend is running** in `--no-auth-mode` at the URL above
2. **patrol CLI is installed**: `patrol --version`
3. **Code compiles**: Run `dart analyze integration_test/` first
4. **test_bundle.dart is current**: Patrol auto-generates this — if tests are missing from the bundle, delete it and let `patrol test` regenerate

## macOS-Specific Constraints

### Window size is fixed (~800x600)

The macOS test window runs BELOW the 840px desktop breakpoint (`SoliplexBreakpoints.desktop`). This means:

- **HistoryPanel renders in the drawer**, not as an inline sidebar
- `WidgetTester.setSurfaceSize()` does NOT work in integration tests (real macOS window, not test binding)
- To access drawer content, tap the hamburger menu icon first
- After tapping a button inside a drawer, the drawer does NOT auto-close

**Strategy:** Avoid drawer interactions when possible. The ChatPanel body renders regardless of drawer state, and threads auto-select when entering a room.

### Entitlements

Both the app AND the test runner need their own entitlements:

| Binary | Entitlements file | Required keys |
|--------|-------------------|---------------|
| Runner (app) | `macos/Runner/DebugProfile.entitlements` | `network.client`, `network.server` |
| RunnerUITests | `macos/RunnerUITests/RunnerUITests.entitlements` | `network.client`, `network.server`, `app-sandbox` |

**Debugging:** `codesign -d --entitlements :- <path-to-binary>` shows actual signed entitlements.

**After changing entitlements**, re-approve Accessibility permissions in System Settings.

### Keyboard assertions

macOS has a Flutter keyboard assertion bug. All tests must call `ignoreKeyboardAssertions()` early. On web, the function is a no-op (`kIsWeb` guard).

## iOS Constraints

### RunnerUITests target required

The iOS Xcode project needs a `RunnerUITests` UI test bundle target
(same pattern as macOS). The target, scheme entry, and Podfile entry
are already configured in this repo.

### Simulator OS version must match

Patrol uses `--ios=<version>` (defaults to `latest`). If the booted
simulator runs an older iOS than the latest installed SDK, pass the
version explicitly: `--ios=18.6`.

### Keyboard assertions

`ignoreKeyboardAssertions()` applies on iOS too (same Flutter bug as
macOS). No changes needed — the function works on both platforms.

## Chrome (Web) Constraints

### Viewport is controllable

Unlike macOS (fixed ~800x600), Chrome viewport can be set with `--web-viewport "1280x720"`. A viewport >= 840px wide puts the app above the desktop breakpoint, so the HistoryPanel renders inline instead of in a drawer.

### No entitlements required

Web does not require macOS entitlements or Accessibility permissions.

### CORS

The backend must return proper CORS headers for the test origin. Default dev server config at `localhost:8000` typically handles this.

### Node.js required

Patrol uses Playwright for Chrome automation. Playwright requires Node.js >= 18. It auto-installs browser binaries on first `patrol test --device chrome` run.

## Test Patterns

### Never use pumpAndSettle

SSE streams prevent settling. Use these instead:

1. **`waitForCondition`** — polling-based, for UI states
2. **`harness.waitForLog`** — stream-based, for async events (preferred)
3. **`tester.pump(duration)`** — fixed delays, only for brief rendering pauses

### Standard test structure

```dart
patrolTest('description', ($) async {
  await verifyBackendOrFail(backendUrl);
  ignoreKeyboardAssertions();

  final harness = TestLogHarness();
  await harness.initialize();

  try {
    await pumpTestApp($, harness);
    // ... test body ...
  } catch (e) {
    harness.dumpLogs(last: 50);
    rethrow;
  } finally {
    harness.dispose();
  }
});
```

### Widget finders reference

| Target | Finder |
|--------|--------|
| Room list items | `find.byType(RoomListTile)` |
| Chat input | `find.byType(TextField)` |
| Send button | `find.byTooltip('Send message')` |
| Chat messages | `find.byType(ChatMessageWidget)` |
| Settings icon | `find.byIcon(Icons.settings)` |

**Avoid** `find.bySemanticsLabel` for text entry — it can resolve to the Semantics wrapper instead of the TextField, causing `enterText` to fail.

### Log patterns for assertions

| Logger | Pattern | Meaning |
|--------|---------|---------|
| `Router` | `redirect called` | App booted, router active |
| `HTTP` | `/api/v1/rooms` | Rooms API called |
| `Room` | `Rooms loaded:` | Rooms parsed successfully |
| `ActiveRun` | `RUN_STARTED` | AG-UI SSE stream opened |
| `ActiveRun` | `TEXT_START:` | First text chunk received |
| `ActiveRun` | `RUN_FINISHED` | SSE stream completed |

## Debugging: Two-Phase Workflow

### Phase 1: Discover (dart MCP — `flutter run`)

Use `mcp__dart-tools__launch_app` to start the app, then inspect the live
widget tree and logs to find the right finders and log patterns for your test.

```text
mcp__dart-tools__launch_app   → starts app, returns DTD URI
mcp__dart-tools__connect_dart_tooling_daemon → connect to running app
mcp__dart-tools__get_widget_tree(summaryOnly: true) → see real widget hierarchy
mcp__dart-tools__get_app_logs(pid, maxLines: 50)    → see stdout log output
mcp__dart-tools__get_runtime_errors                  → check for exceptions
```

Stdout logs appear as `[DEBUG] Router: redirect called for /` — use these
to identify the logger name and message pattern for `harness.expectLog()`.

The widget tree shows actual `widgetRuntimeType` values — use these for
`find.byType()` finders.

### Phase 2: Assert (TestLogHarness — patrol run)

Patrol launches the app through xcodebuild, which does **not** expose a
DTD URI. The dart MCP tools cannot connect during a patrol test run.

Instead, all test assertions use **`TestLogHarness`** which captures logs
in-process via `MemorySink`:

- `harness.expectLog('Router', 'redirect called')` — synchronous check
- `harness.waitForLog('ActiveRun', 'RUN_FINISHED')` — stream-based wait
- `harness.dumpLogs(last: 50)` — dump to console on failure

The harness sees the same `[DEBUG]` logs that appear in `get_app_logs`,
but accessed in-process rather than via stdout.

## Git Worktree Caveat

This repo is a git worktree. Pre-commit hooks that invoke `flutter`/`dart` must `unset GIT_DIR` first, otherwise Flutter reports version `0.0.0-unknown`. Wrapper scripts in `scripts/` handle this.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Multiple devices found" prompt | Missing `--device` flag | Add `--device macos` |
| `command not found: patrol` | Not on PATH | Use full path `patrol` |
| Test hangs on "Waiting for app" | Entitlements missing/wrong | Check both Runner and RunnerUITests entitlements |
| `0.0.0-unknown` version | GIT_DIR set in worktree | Use `scripts/flutter-analyze.sh` wrapper |
| "did not appear within 10s" | Widget in drawer, not body | Check if window < 840px breakpoint |
| `Bad state: No element` on enterText | Finder matched Semantics, not TextField | Use `find.byType(TextField)` instead |
| Accessibility permission denied | Entitlements changed | Re-approve in System Settings > Privacy > Accessibility |
| Chrome: "Cannot find module playwright" | Node.js not installed | Install Node.js >= 18, then rerun |
| Chrome: CORS error in test | Backend missing CORS headers | Configure backend `Access-Control-Allow-Origin` for test origin |
| Chrome: "Failed to fetch" on `verifyBackendOrFail` | Backend offline or CORS block | Start backend; check browser console for CORS errors |
| `command not found: patrol` | `~/.pub-cache/bin` not on PATH | Add to PATH or use full path `~/.pub-cache/bin/patrol` |
| iOS: xcodebuild exit code 70 | `OS=latest` doesn't match simulator | Use `--ios=18.6` (match simulator OS) |
| iOS: "Device ... is not attached" | Wrong device ID format | Use UUID from `xcrun simctl list devices booted` |
