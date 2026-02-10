---
name: patrol
description: Run Patrol E2E integration tests on macOS, iOS, Android, or Chrome. Use when writing, running, or debugging Patrol tests.
argument-hint: "[test-file|all]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Patrol E2E Test Skill

**PREREQUISITE:** If you are writing a NEW test or fixing a broken finder,
you MUST load the `debugging` skill first.

1. **Load:** `debugging` skill.
2. **Inspect:** Run `mcp__dart-tools__get_widget_tree` to see reality.
3. **Write:** Return here to write the Patrol test using the exact
   strings you found.

Run and manage Patrol integration tests for this Flutter project
(macOS, iOS, Android, and Chrome).

## Test Inventory

| File | Auth | Backend | Tests |
|------|------|---------|-------|
| `smoke_test.dart` | no-auth | localhost:8000 | App boot, log harness |
| `live_chat_test.dart` | no-auth | localhost:8000 | Rooms, chat send/receive |
| `settings_test.dart` | no-auth | localhost:8000 | Settings navigation, tiles |
| `oidc_test.dart` | OIDC | configurable | ROPC rooms+chat, settings auth |

## Running Tests

**CLI location:** `patrol`

Always use `--device` to avoid the interactive device selection prompt.

### macOS (default)

```bash
# Run a specific no-auth test
patrol test \
  --device macos \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000

# Run all no-auth tests
patrol test \
  --device macos \
  --target integration_test/smoke_test.dart

patrol test \
  --device macos \
  --target integration_test/live_chat_test.dart

patrol test \
  --device macos \
  --target integration_test/settings_test.dart
```

**First-time setup:** See [macOS Setup Guide](./setup/macos-setup.md) for entitlements and window constraints.

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

**First-time setup:** See [iOS Setup Guide](./setup/ios-setup.md) for RunnerUITests target and simulator OS matching.

### Android (emulator or device)

Requires a booted emulator or connected device. Use the name/serial from `adb devices`.

```bash
# Boot emulator (if not running)
export ANDROID_HOME=~/Library/Android/sdk
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
emulator -avd Patrol_Test_API_36 &

# Run on Android emulator
patrol test \
  --device emulator-5554 \
  --target integration_test/$ARGUMENTS \
  --dart-define SOLIPLEX_BACKEND_URL=http://10.0.2.2:8000
```

**Note:** Android emulators use `10.0.2.2` to reach the host's `localhost`.

**First-time setup:** See [Android Setup Guide](./setup/android-setup.md) for AVD creation, JDK, and Google APIs image requirement.

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

**First-time setup:** See [Web Setup Guide](./setup/web-setup.md) for Node.js, CORS, and viewport details.

### OIDC tests

```bash
patrol test \
  --device macos \
  --target integration_test/oidc_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=https://my.soliplex.com \
  --dart-define SOLIPLEX_OIDC_USERNAME=patrol \
  --dart-define SOLIPLEX_OIDC_PASSWORD=patrol \
  --dart-define SOLIPLEX_OIDC_ISSUER_ID=<issuer-key>
```

OIDC tests **require** all three credentials via `--dart-define`. Without
them the test calls `requireOidcCredentials()` and fails immediately.

If `$ARGUMENTS` is empty or "all", run against `integration_test/` (all no-auth tests).
If `$ARGUMENTS` is a filename like `smoke_test.dart`, run that specific file.
If `$ARGUMENTS` is `oidc_test.dart`, use the OIDC command above.

## Pre-flight Checks

Before running tests, verify:

1. **Backend is running** — localhost:8000 for no-auth, or the OIDC backend URL
2. **patrol CLI is installed**: `patrol --version`
3. **Code compiles**: Run `dart analyze integration_test/` first
4. **test_bundle.dart is current**: Patrol auto-generates this — if tests are missing from the bundle, delete it and let `patrol test` regenerate

## FORBIDDEN PATTERNS

Read this BEFORE writing any test code.

1. **The "Exact Match" Trap:**
   - FORBIDDEN: `find.widgetWithText(RoomListTile, 'Gemini')`
   - Why: Fails because the widget renders "Gemini 2.5 Flash".
   - REQUIRED: `findByTextContaining(RoomListTile, 'Gemini')`

2. **The "Blind Finder" Trap:**
   - FORBIDDEN: Writing `find.byType(MyWidget)` based on reading source.
   - Why: The runtime widget may be wrapped in `Semantics`, `Padding`,
     or `GestureDetector` that obscures the type.
   - REQUIRED: Run `mcp__dart-tools__get_widget_tree` and copy the
     exact `widgetRuntimeType`.

3. **The "Pump" Trap:**
   - FORBIDDEN: `await $.pumpAndSettle()`
   - Why: SSE streams keep the app "active" indefinitely.
   - REQUIRED: Use `harness.waitForLog(...)` or `waitForCondition(...)`.

4. **The "Semantics" Trap:**
   - FORBIDDEN: `find.bySemanticsLabel` for text entry targets.
   - Why: Resolves to the Semantics wrapper, not the TextField.
   - REQUIRED: Use `find.byType(TextField)`.

## Test Patterns

**Core Rule: Inspect Before You Write.** Before adding or changing any
finder, follow the debugging workflow below. Guessing finders from source
code is the most common cause of test failures.

### Never use pumpAndSettle

SSE streams prevent settling. Use these instead:

1. **`waitForCondition`** — polling-based, for UI states
2. **`harness.waitForLog`** — stream-based, for async events (preferred)
3. **`tester.pump(duration)`** — fixed delays, only for brief rendering pauses

### Standard no-auth test structure

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

### Authenticated (OIDC) test structure

```dart
patrolTest('oidc - description', ($) async {
  requireOidcCredentials();
  await verifyBackendOrFail(backendUrl);
  ignoreKeyboardAssertions();

  final harness = TestLogHarness();
  await harness.initialize();

  try {
    final tokens = await performRopcExchange(
      baseUrl: backendUrl,
      username: oidcUsername,
      password: oidcPassword,
      issuerId: oidcIssuerId,
    );
    await pumpAuthenticatedTestApp($, harness, tokens: tokens);
    // ... test body ...
  } catch (e) {
    harness.dumpLogs(last: 50);
    rethrow;
  } finally {
    harness.dispose();
  }
});
```

Key helpers for OIDC tests:

- **`requireOidcCredentials()`** — fails fast if `--dart-define` creds missing
- **`performRopcExchange()`** — HTTP POST `grant_type=password` to Keycloak
  token endpoint, returns `Authenticated` state
- **`pumpAuthenticatedTestApp()`** — boots app with
  `PreAuthenticatedNotifier` injecting real OIDC tokens

### Widget finders reference

| Target | Finder |
|--------|--------|
| Room list items | `find.byType(RoomListTile)` |
| Room by name (substring) | `findByTextContaining(RoomListTile, 'Gemini')` |
| Chat input | `find.byType(TextField)` |
| Send button | `find.byTooltip('Send message')` |
| Chat messages | `find.byType(ChatMessageWidget)` |
| Settings button | `find.byTooltip('Open settings')` |
| Room search field | `find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText?.contains('Search') == true)` |

**Text Matching Protocol:**

1. **DEFAULT** to `findByTextContaining(WidgetType, 'Substring')`.
   UI text often contains version numbers, status, or whitespace
   (e.g., "Gemini 2.5 Flash" vs "Gemini").
2. **ONLY** use exact matching if you have verified the `textPreview`
   in the widget tree is static and will not change.
3. `findByTextContaining` is defined in `patrol_test_config.dart`.

**ListView.builder gotcha:** Off-screen items are not in the widget tree.
Use the in-app search toolbar to filter items instead of scrolling.

### Log patterns for assertions

| Logger | Pattern | Meaning |
|--------|---------|---------|
| `Router` | `redirect called` | App booted, router active |
| `HTTP` | `/api/v1/rooms` | Rooms API called |
| `Room` | `Rooms loaded:` | Rooms parsed successfully |
| `ActiveRun` | `RUN_STARTED` | AG-UI SSE stream opened |
| `ActiveRun` | `TEXT_START:` | First text chunk received |
| `ActiveRun` | `RUN_FINISHED` | SSE stream completed |

### UI visibility pump pattern

Single `pump(Duration(seconds: 1))` renders only ONE frame. Use a loop
for actual UI painting:

```dart
for (var i = 0; i < 5; i++) {
  await $.tester.pump(const Duration(milliseconds: 200));
}
```

## Debugging: Two-Phase Workflow

### Phase 1: MANDATORY Discovery

**STOP. Do not write any finders yet.**

Use the `debugging` skill to launch the app and inspect the widget tree.

1. Run `mcp__dart-tools__launch_app` to start the app.
2. Run `mcp__dart-tools__connect_dart_tooling_daemon` with the DTD URI.
3. Run `mcp__dart-tools__get_widget_tree(summaryOnly: true)`.
4. **READ the `textPreview`** of the target widget — this is your
   source of truth for text finders.
5. **COPY the `widgetRuntimeType`** directly into your test code.
6. Run `mcp__dart-tools__get_app_logs` to see `[DEBUG]` log patterns
   for `harness.expectLog()` assertions.

For interactive debugging (tap, enter text, scroll), launch with
`target: "test_driver/app.dart"` which enables flutter_driver commands.
See the `debugging` skill for the full flutter_driver workflow.

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
| `command not found: patrol` | `~/.pub-cache/bin` not on PATH | Add to PATH or use full path |
| Test hangs on "Waiting for app" | Entitlements missing/wrong | See [macOS setup](./setup/macos-setup.md) |
| `0.0.0-unknown` version | GIT_DIR set in worktree | Use `scripts/flutter-analyze.sh` wrapper |
| "did not appear within 10s" | Widget in drawer, not body | See [macOS setup](./setup/macos-setup.md) |
| `Bad state: No element` on enterText | Finder matched Semantics, not TextField | Use `find.byType(TextField)` instead |
| Accessibility permission denied | Entitlements changed | Re-approve in System Settings > Privacy > Accessibility |
| iOS: xcodebuild exit code 70 | `OS=latest` doesn't match simulator | See [iOS setup](./setup/ios-setup.md) |
| iOS: "Device ... is not attached" | Wrong device ID format | Use UUID from `xcrun simctl list devices booted` |
| Android: "No connected devices" | Emulator not running or `adb` not on PATH | See [Android setup](./setup/android-setup.md) |
| Android: connection refused to localhost | Emulator can't reach host localhost | Use `10.0.2.2` instead of `localhost` |
| Android: Gmail login prompt on boot | AVD uses Google Play image | See [Android setup](./setup/android-setup.md) |
| Chrome: "Cannot find module playwright" | Node.js not installed | See [Web setup](./setup/web-setup.md) |
| Chrome: CORS error in test | Backend missing CORS headers | See [Web setup](./setup/web-setup.md) |
| Chrome: "Failed to fetch" on `verifyBackendOrFail` | Backend offline or CORS block | Start backend; check browser console |
| OIDC test fails immediately | Missing `--dart-define` creds | Add `SOLIPLEX_OIDC_USERNAME`, `SOLIPLEX_OIDC_PASSWORD`, `SOLIPLEX_OIDC_ISSUER_ID` |
| 401 on OIDC test | Wrong issuer selected | Check `--dart-define SOLIPLEX_OIDC_ISSUER_ID` matches backend |
| Room not found in list | ListView.builder — off-screen | Use room search toolbar instead of scrolling |
