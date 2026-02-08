---
name: patrol
description: Run Patrol E2E integration tests on macOS. Use when writing, running, or debugging Patrol tests.
argument-hint: "[test-file|all]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Patrol E2E Test Skill

Run and manage Patrol integration tests for this Flutter macOS project.

## Test Inventory

| File | Auth | Backend | Tests |
|------|------|---------|-------|
| `smoke_test.dart` | no-auth | localhost:8000 | App boot, log harness |
| `live_chat_test.dart` | no-auth | localhost:8000 | Rooms, chat send/receive |
| `settings_test.dart` | no-auth | localhost:8000 | Settings navigation, tiles |
| `oidc_test.dart` | OIDC | rag.enfoldsystems.net | ROPC rooms+chat, settings auth |

## Running Tests

**CLI location:** `/Users/runyaga/.pub-cache/bin/patrol`

Always use `--device macos` to avoid the interactive device selection prompt.

### No-auth tests (against localhost:8000)

```bash
# Run a specific no-auth test
/Users/runyaga/.pub-cache/bin/patrol test \
  --device macos \
  --target integration_test/$ARGUMENTS

# Run all no-auth tests (smoke, live_chat, settings)
/Users/runyaga/.pub-cache/bin/patrol test \
  --device macos \
  --target integration_test/smoke_test.dart

/Users/runyaga/.pub-cache/bin/patrol test \
  --device macos \
  --target integration_test/live_chat_test.dart

/Users/runyaga/.pub-cache/bin/patrol test \
  --device macos \
  --target integration_test/settings_test.dart
```

No-auth tests default to `http://localhost:8000` (no `--dart-define` needed).

### OIDC tests (against rag.enfoldsystems.net)

```bash
/Users/runyaga/.pub-cache/bin/patrol test \
  --device macos \
  --target integration_test/oidc_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=https://rag.enfoldsystems.net \
  --dart-define SOLIPLEX_OIDC_USERNAME=patrol \
  --dart-define SOLIPLEX_OIDC_PASSWORD=patrol
```

OIDC tests **require** credentials via `--dart-define`. Without them the test
calls `requireOidcCredentials()` and fails immediately.

Optional: `--dart-define SOLIPLEX_OIDC_ISSUER_ID=pydio` (defaults to `pydio`).

If `$ARGUMENTS` is empty or "all", run the no-auth tests only.
If `$ARGUMENTS` is a filename like `smoke_test.dart`, run that specific file.
If `$ARGUMENTS` is `oidc_test.dart`, use the OIDC command above.

## Pre-flight Checks

Before running tests, verify:

1. **Backend is running** — localhost:8000 for no-auth, rag.enfoldsystems.net for OIDC
2. **patrol CLI is installed**: `/Users/runyaga/.pub-cache/bin/patrol --version`
3. **Code compiles**: Run `flutter analyze integration_test/` first
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

macOS has a Flutter keyboard assertion bug. All tests must call `ignoreKeyboardAssertions()` early.

## Test Patterns

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
- **`performRopcExchange()`** — HTTP POST `grant_type=password` to Keycloak token endpoint, returns `Authenticated` state
- **`pumpAuthenticatedTestApp()`** — boots app with `PreAuthenticatedNotifier` injecting real OIDC tokens

### Widget finders reference

| Target | Finder |
|--------|--------|
| Room list items | `find.byType(RoomListTile)` |
| Chat input | `find.byType(TextField)` |
| Send button | `find.byTooltip('Send message')` |
| Chat messages | `find.byType(ChatMessageWidget)` |
| Settings button | `find.byTooltip('Open settings')` |
| Room search field | `find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText?.contains('Search') == true)` |

**Avoid** `find.bySemanticsLabel` for text entry — it can resolve to the Semantics wrapper instead of the TextField, causing `enterText` to fail.

**ListView.builder gotcha:** Off-screen items are not in the widget tree. Use the in-app search toolbar to filter items instead of scrolling.

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

Single `pump(Duration(seconds: 1))` renders only ONE frame. Use a loop for actual UI painting:

```dart
for (var i = 0; i < 5; i++) {
  await $.tester.pump(const Duration(milliseconds: 200));
}
```

## Interactive Debugging with dart-tools MCP

Instead of writing blind Patrol tests, you can launch the app and interact
with it in real time — seeing screenshots, inspecting the widget tree, and
tapping/typing via `flutter_driver`.

### When to use

- **Debugging a failing Patrol test** — see what's actually on screen at the
  point of failure
- **Exploring UI for new test coverage** — discover widget types, tooltips,
  and text before writing finders
- **Rapid prototyping** — try a click sequence interactively before coding it

### Setup: driver-enabled entry point

The app needs `flutter_driver` extension enabled. Use `test_driver/app.dart`:

```dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:soliplex_frontend/soliplex_frontend.dart';

Future<void> main() async {
  enableFlutterDriverExtension();
  await runSoliplexApp(
    config: const SoliplexConfig(
      logo: LogoConfig.soliplex,
      oauthRedirectScheme: 'ai.soliplex.client',
    ),
  );
}
```

`flutter_driver` is already in `dev_dependencies`.

### Workflow

**1. Launch the app:**

```text
mcp__dart-tools__launch_app(root: "...", device: "macos", target: "test_driver/app.dart")
```

Returns `dtdUri` and `pid`.

**2. Connect to the Dart Tooling Daemon:**

```text
mcp__dart-tools__connect_dart_tooling_daemon(uri: <dtdUri>)
```

**3. Health check (confirms driver is active):**

```text
mcp__dart-tools__flutter_driver(command: "get_health")
```

**4. See the screen:**

```text
mcp__dart-tools__flutter_driver(command: "screenshot")
```

Returns a visual screenshot of the running app.

**5. Inspect the widget tree:**

```text
mcp__dart-tools__get_widget_tree(summaryOnly: true)
```

Shows the full widget hierarchy with types, text content, and structure.

**6. Interact — tap, type, wait:**

```bash
# Tap by text
flutter_driver(command: "tap", finderType: "ByText", text: "Connect")

# Tap by tooltip
flutter_driver(command: "tap", finderType: "ByTooltipMessage", text: "Open settings")

# Tap by widget type
flutter_driver(command: "tap", finderType: "ByType", type: "TextFormField")

# Enter text (tap the field first)
flutter_driver(command: "enter_text", text: "http://localhost:8000")

# Wait for a widget to appear
flutter_driver(command: "waitFor", finderType: "ByText", text: "Rooms")

# Get text from a widget
flutter_driver(command: "get_text", finderType: "ByType", type: "Text")
```

**7. Stop the app:**

```text
mcp__dart-tools__stop_app(pid: <pid>)
```

### Available finder types

| Finder | Required params |
|--------|----------------|
| `ByText` | `text` |
| `ByTooltipMessage` | `text` |
| `ByType` | `type` (widget runtime type) |
| `ByValueKey` | `keyValueString`, `keyValueType` |
| `BySemanticsLabel` | `label` |
| `PageBack` | (none) |
| `Ancestor` | `of`, `matching`, `matchRoot`, `firstMatchOnly` |
| `Descendant` | `of`, `matching`, `matchRoot`, `firstMatchOnly` |

### Capabilities vs limitations

| Feature | Works | Notes |
|---------|-------|-------|
| Screenshot | Yes | Visual image of app state |
| Widget tree | Yes | Full hierarchy via DTD |
| Tap | Yes | By text, tooltip, type, key |
| Enter text | Yes | Tap field first, then enter_text |
| Wait for widget | Yes | `waitFor` / `waitForAbsent` |
| Scroll | Yes | `scroll` with dx/dy/duration |
| Hot reload | Yes | `mcp__dart-tools__hot_reload` |
| Hot restart | Yes | `mcp__dart-tools__hot_restart` |
| Widget selection | Yes | `set_widget_selection_mode` + `get_selected_widget` |
| Multiple apps | No | One DTD connection at a time |

### Example: diagnosing a test failure

This workflow diagnosed the clear button bug in the network log viewer test:

1. Launched app with driver entry point
2. Screenshot showed the Rooms screen after connecting
3. Tapped settings, screenshot confirmed Settings page
4. Tapped "Network Requests", screenshot showed **wide master-detail layout**
5. Confirmed the clear button (trash icon) was visible in the AppBar
6. Realized the Patrol test's `find.byTooltip('Back')` was matching the
   inspector-to-settings back button (not a detail page back), navigating
   away from the inspector entirely

## Git Worktree Caveat

This repo is a git worktree. Pre-commit hooks that invoke `flutter`/`dart` must `unset GIT_DIR` first, otherwise Flutter reports version `0.0.0-unknown`. Wrapper scripts in `scripts/` handle this.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Multiple devices found" prompt | Missing `--device` flag | Add `--device macos` |
| `command not found: patrol` | Not on PATH | Use full path `/Users/runyaga/.pub-cache/bin/patrol` |
| Test hangs on "Waiting for app" | Entitlements missing/wrong | Check both Runner and RunnerUITests entitlements |
| `0.0.0-unknown` version | GIT_DIR set in worktree | Use `scripts/flutter-analyze.sh` wrapper |
| "did not appear within 10s" | Widget in drawer, not body | Check if window < 840px breakpoint |
| `Bad state: No element` on enterText | Finder matched Semantics, not TextField | Use `find.byType(TextField)` instead |
| Accessibility permission denied | Entitlements changed | Re-approve in System Settings > Privacy > Accessibility |
| OIDC test fails immediately | Missing `--dart-define` creds | Add `SOLIPLEX_OIDC_USERNAME` and `SOLIPLEX_OIDC_PASSWORD` |
| 401 on OIDC test | Wrong issuer selected | Add `--dart-define SOLIPLEX_OIDC_ISSUER_ID=pydio` |
| Room not found in list | ListView.builder — off-screen | Use room search toolbar instead of scrolling |
