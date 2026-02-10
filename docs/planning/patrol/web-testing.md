# Patrol Web (Chrome) E2E Testing

## Goal

Run existing Patrol E2E tests on Chrome via Playwright, in addition to macOS.
No new test files — the same no-auth tests (smoke, live_chat, settings) run on
both platforms.

## Background

Patrol 4.1.x added web testing support backed by Playwright. The CLI flags are:

| Flag | Purpose |
|------|---------|
| `--device chrome` | Target Chrome browser |
| `--web-headless true` | Headless mode for CI |
| `--web-viewport "1280x720"` | Set browser viewport |

Playwright is auto-installed by `patrol_cli` on first run. Requires Node.js
(>=18) on the host.

## Compatibility Analysis

### Tests use only Flutter-level finders

All no-auth tests use `$.tester.*` (Flutter finders), not `$.native.*` (native
APIs). Native APIs are unavailable on web, but we don't use them:

| Test | Native API usage | Web-compatible |
|------|-----------------|----------------|
| `smoke_test.dart` | None | Yes |
| `live_chat_test.dart` | None | Yes |
| `settings_test.dart` | None | Yes |
| `oidc_test.dart` | None (ROPC is HTTP) | Yes |

### Shared helpers

| Helper | Web concern | Resolution |
|--------|------------|------------|
| `verifyBackendOrFail` | Uses `package:http` | Works on web (XHR) |
| `waitForCondition` | Pure Flutter | Works |
| `ignoreKeyboardAssertions` | macOS-only bug | Guard with `kIsWeb` |
| `TestLogHarness` | Pure Dart, no `dart:io` | Works |
| `pumpTestApp` / `pumpAuthenticatedTestApp` | Riverpod + Flutter | Works |

### `ignoreKeyboardAssertions()` platform guard

The function suppresses a macOS-only Flutter keyboard assertion bug
(`_pressedKeys.containsKey` / `KeyUpEvent is dispatched`). On web, this bug
does not occur. The handler is harmless on web (it would just pass through all
errors), but adding an early return on `kIsWeb` is cleaner and documents intent.

```dart
void ignoreKeyboardAssertions() {
  // macOS-only Flutter keyboard assertion bug — skip on web.
  if (kIsWeb) return;

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exception.toString();
    if (msg.contains('_pressedKeys.containsKey') ||
        msg.contains('KeyUpEvent is dispatched')) {
      return;
    }
    originalOnError?.call(details);
  };
}
```

`kIsWeb` from `package:flutter/foundation.dart` (already imported) is preferred
over `dart:io` `Platform` because `dart:io` is not available on web.

## Web-specific constraints

### Window size is controllable

Unlike macOS (fixed ~800x600), Chrome viewport can be set with
`--web-viewport "1280x720"`. This may put the app above the 840px desktop
breakpoint, making drawer interactions unnecessary.

### No entitlements

Web does not require macOS entitlements or Accessibility permissions.

### CORS

Tests hit the backend via `package:http`. On web, the browser enforces CORS.
Patrol serves the test app on an ephemeral port (e.g. `http://localhost:54321`),
so the backend must accept requests from dynamic origins. The simplest approach
is `Access-Control-Allow-Origin: *` on the dev backend. If the backend requires
strict origin whitelisting, configure it to accept `http://localhost:*`.

## Changes required

1. **`integration_test/patrol_test_config.dart`** — Add `kIsWeb` guard to
   `ignoreKeyboardAssertions()`
2. **`.claude/skills/patrol/SKILL.md`** — Add web test commands, Node.js
   prerequisite, web-specific constraints section

## CI considerations (future PR)

- Add Chrome job to `.github/workflows/patrol-e2e.yaml`
- Use `--web-headless true` for headless execution
- Add Node.js setup step (actions/setup-node)
- CORS must be configured on the CI backend

## Verification

1. `patrol test --device chrome --target integration_test/smoke_test.dart`
   passes (or fails at backend check if backend offline — same as macOS)
2. `dart analyze integration_test/` — 0 issues
3. Existing macOS tests still pass (no regression)

### Validated locally

Chrome smoke test ran end-to-end through the Playwright pipeline:

- Flutter web app built and served on ephemeral port
- Playwright installed Node.js deps + browser binaries automatically
- Test executed, hit `verifyBackendOrFail` (backend offline — expected)
- Error was `ClientException: Failed to fetch` (browser fetch API, not
  `dart:io` — confirms web runtime)
- No keyboard assertion errors (confirms `kIsWeb` guard works)

The failure at `verifyBackendOrFail` is identical in behavior to macOS when
the backend is offline. With a running backend, the test would proceed past
the health check into the app boot sequence.
