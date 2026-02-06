# Milestone 02: Test Infrastructure

**Status:** pending
**Depends on:** 01-patrol-setup

## Objective

Create a shared test base module (`patrol_test_base.dart`) that provides backend
connectivity checks, streaming-safe pumping, screenshot-on-failure wrapping,
dual-mode auth support (no-auth + OIDC), and macOS keyboard workaround. Every
Patrol test imports this single file.

## Pre-flight Checklist

- [ ] Confirm M01 complete (Patrol dependencies installed)
- [ ] Review existing `test/helpers/test_helpers.dart` for reusable patterns
- [ ] Review existing `integration_test/tool_calling_test.dart` for provider setup
- [ ] Verify macOS entitlements include `com.apple.security.network.client`
- [ ] Verify `package:http` is available (or add to dev_dependencies)

## Deliverables

1. **`integration_test/patrol_test_base.dart`** — Shared test harness
2. **`integration_test/smoke_test.dart`** — Minimal no-auth smoke test

## Files to Create

- [ ] `integration_test/patrol_test_base.dart`
- [ ] `integration_test/smoke_test.dart`

## Implementation Steps

### Step 1: Add http dev dependency if missing

**File:** `pubspec.yaml`

- [ ] Ensure `http` package is in dev_dependencies (for `verifyBackendOrFail`)

### Step 2: Create patrol_test_base.dart

**File:** `integration_test/patrol_test_base.dart`

This file re-exports common test packages and provides all shared helpers.

#### Re-exports

```dart
export 'package:patrol/patrol.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:integration_test/integration_test.dart';

// App types needed by tests
export 'package:soliplex/core/models/soliplex_config.dart';
export 'package:soliplex/core/models/logo_config.dart';
```

#### Compile-time constants

```dart
const backendUrl = String.fromEnvironment(
  'SOLIPLEX_BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);

const authMode = String.fromEnvironment(
  'SOLIPLEX_AUTH_MODE',
  defaultValue: 'no-auth',
);

// OIDC test credentials (only used when authMode == 'oidc')
const oidcUsername = String.fromEnvironment('SOLIPLEX_OIDC_USERNAME');
const oidcPassword = String.fromEnvironment('SOLIPLEX_OIDC_PASSWORD');
```

#### Backend preflight check

- [ ] `verifyBackendOrFail(String url)` — verifies backend is reachable
- [ ] Uses `GET /api/login` (public endpoint, works regardless of auth mode)
- [ ] For OIDC mode: additionally verifies response contains at least one
  auth provider
- [ ] Accepts both 200 and 401 as "reachable" if using other endpoints
- [ ] Fails fast with clear error message including URL

#### Streaming-safe condition waiter

- [ ] `waitForCondition(WidgetTester tester, {condition, timeout, step})`
- [ ] Default step: 200ms
- [ ] Fails with descriptive message on timeout
- [ ] Replaces `pumpAndSettle()` for streaming scenarios

#### Screenshot-on-failure wrapper

- [ ] `patrolTestWithScreenshot(String id, body)` function
- [ ] Wraps `patrolTest` with try/catch
- [ ] Captures screenshot via Patrol's `$.takeScreenshot()` API (not raw
  `IntegrationTestWidgetsFlutterBinding`) to ensure artifacts land in
  `build/patrol/screenshots/` as expected by CI
- [ ] Screenshot named `FAIL__<sanitized_id>`

#### Dual-mode app builder

- [ ] `buildTestApp({SoliplexConfig? config})` helper
- [ ] When `authMode == 'no-auth'`: Overrides `authProvider` with
  `_NoAuthNotifier` that extends `AuthNotifier` and returns
  `const NoAuthRequired()` directly in its `build()` method (synchronous,
  no async restore)
- [ ] When `authMode == 'oidc'`: Overrides `authStorageProvider` with an
  **in-memory mock** that starts empty (prevents Keychain state leaks from
  previous runs causing auto-login). Does NOT override `authProvider` — the
  real `AuthNotifier` runs but finds no stored tokens, landing on the login
  screen. OIDC login handled by Patrol native in M03.
- [ ] Always overrides `shellConfigProvider` with test config pointing at
  `backendUrl`
- [ ] Constructs `SoliplexConfig` with all required fields including `logo`
  (use `LogoConfig.soliplex` default), `oauthRedirectScheme`, and
  `defaultBackendUrl`

#### Keyboard assertion workaround

- [ ] `ignoreKeyboardAssertions()` for macOS Flutter bug
- [ ] Filters `_pressedKeys.containsKey` and `KeyUpEvent is dispatched`

### Step 3: Create smoke test

**File:** `integration_test/smoke_test.dart`

- [ ] Import `patrol_test_base.dart` (single import for everything)
- [ ] Single test: `live.smoke.backend_reachable`
- [ ] Calls `verifyBackendOrFail(backendUrl)`
- [ ] Pumps test app in no-auth mode, verifies it renders without crashing
- [ ] Validates the entire harness works

### Step 4: Verify with patrol test

- [ ] Run with `--dart-define` flags:

```bash
patrol test --target integration_test/smoke_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=no-auth
```

- [ ] Confirm test passes against local backend in `--no-auth-mode`

## Out of Scope

- OIDC login flow (deferred to M03)
- Feature tests (deferred to M04-M05)
- Test data factories (tests create their own data via API)

## Validation Gate

### Automated Checks

- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] `patrol test --target integration_test/smoke_test.dart` passes
- [ ] Existing `flutter test` suite unaffected

### Manual Verification

- [ ] Screenshot is generated when smoke test is forced to fail
- [ ] Backend preflight gives clear error when backend is down

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `integration_test/patrol_test_base.dart`,
`integration_test/smoke_test.dart`,
`docs/planning/patrol/02-test-infrastructure.md`,
`docs/patrol-analysis.md`, `test/helpers/test_helpers.dart`,
`lib/core/auth/auth_notifier.dart`,
`lib/core/models/soliplex_config.dart`

**Prompt:**

```text
Review the Patrol test infrastructure against the spec in
02-test-infrastructure.md and source analysis in patrol-analysis.md.

Check:
1. Re-exports patrol, flutter_test, integration_test for single-import
2. waitForCondition avoids pumpAndSettle for streaming
3. patrolTestWithScreenshot correctly wraps and captures on failure
4. verifyBackendOrFail fails fast with useful message
5. Dual-mode auth: no-auth uses _NoAuthNotifier, oidc leaves auth real
6. SoliplexConfig constructed with correct fields (oauthRedirectScheme, defaultBackendUrl)
7. --dart-define used correctly for String.fromEnvironment constants
8. ignoreKeyboardAssertions included for macOS

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] `patrol_test_base.dart` compiles with zero issues
- [ ] Single import provides all test dependencies
- [ ] Smoke test passes against live backend (no-auth mode)
- [ ] Screenshot captured when test fails
- [ ] Backend preflight gives clear error when backend is down
- [ ] Dual-mode auth scaffold ready for M03
- [ ] Gemini critique: PASS
