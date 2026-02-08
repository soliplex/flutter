# Phase C: OIDC Authentication + CI Pipeline

**Status:** pending
**Depends on:** Phase B
**Logging level:** 4-5 (Logfire correlation + CI failure artifacts)

## Objective

Add OIDC authentication via Keycloak ROPC token seeding, create a GitHub Actions
workflow, and enable Logfire correlation so every test run is queryable
server-side. On CI failure, automatically produce a diagnostic artifact bundle.

## Auth Strategy: Token Seeding (Not $.native)

We use **direct Keycloak ROPC (Resource Owner Password Credentials) token
exchange** to obtain tokens, then inject them into the app's `AuthNotifier`
via a `@visibleForTesting` method. This approach:

- Bypasses `ASWebAuthenticationSession` (resists automation on macOS)
- Works reliably in CI (no TCC permissions needed)
- Tests the real authenticated app flow against the real backend
- Does NOT test the login UI flow (deferred to future `$.native` hardening)

## Keycloak Configuration

The Keycloak client used for testing **must** have "Direct Access Grants"
enabled:

1. Open Keycloak Admin Console
2. Navigate to: Clients → (your client) → Settings
3. Set **"Direct Access Grants Enabled"** = ON
4. Save

This is often **disabled by default**. Without it, the ROPC token exchange
returns a 400 error.

### Test User Setup

Provision a dedicated test user in Keycloak:

1. Navigate to: Users → Add User
2. Username: `patrol-test` (or similar)
3. Set a password (disable "Temporary")
4. Assign the user to a group/role that has access to at least one room

## Pre-flight Checklist

- [ ] Confirm Phase B complete (no-auth chat tests passing)
- [ ] Keycloak "Direct Access Grants" enabled on test client
- [ ] Keycloak test user provisioned with room access
- [ ] Backend running with Keycloak auth (not `--no-auth-mode`)
- [ ] `GET /api/login` returns at least one auth provider config
- [ ] Review `lib/core/auth/auth_notifier.dart` for state injection point
- [ ] Verify `AuthNotifier.build()` calls `_restoreSession()` async — injection
  must wait until restore completes to avoid race condition

## Deliverables

1. `lib/core/auth/auth_notifier.dart` — Add `@visibleForTesting`
   `injectTestTokens` method
2. `integration_test/test_log_harness.dart` — Add Logfire correlation
3. `integration_test/patrol_test_config.dart` — Add OIDC helpers
4. `integration_test/authenticated_test.dart` — Authenticated rooms test
5. `.github/workflows/patrol-integration.yml` — CI workflow

## Implementation Steps

### Step 1: Add test token injection to AuthNotifier

**File:** `lib/core/auth/auth_notifier.dart`

- [ ] Add a `@visibleForTesting` method that sets state to `Authenticated`:

```dart
@visibleForTesting
void injectTestTokens({
  required String accessToken,
  required String refreshToken,
  required String idToken,
  required DateTime expiresAt,
  required String issuerId,
  required String issuerDiscoveryUrl,
  required String clientId,
}) {
  state = Authenticated(
    accessToken: accessToken,
    refreshToken: refreshToken,
    idToken: idToken,
    expiresAt: expiresAt,
    issuerId: issuerId,
    issuerDiscoveryUrl: issuerDiscoveryUrl,
    clientId: clientId,
  );
}
```

- [ ] **Race condition guard:** Ensure `_restoreSession()` has completed before
  calling `injectTestTokens`. Options:
  - Wait for auth state to leave `AuthLoading` before injection
  - Add a `Completer` that signals when `build()` finishes

### Step 2: Add Logfire correlation to TestLogHarness

**File:** `integration_test/test_log_harness.dart`

- [ ] Generate a `testRunId` (UUID) per test invocation
- [ ] Wrap `LogManager.instance.sanitizer` to inject `testRunId` into every
  `LogRecord.attributes` via `record.copyWith(attributes: {...})`:

```dart
class _TestCorrelationSanitizer implements LogSanitizer {
  final String testRunId;
  final LogSanitizer? inner;

  _TestCorrelationSanitizer(this.testRunId, {this.inner});

  @override
  LogRecord sanitize(LogRecord record) {
    var processed = inner?.sanitize(record) ?? record;
    return processed.copyWith(attributes: {
      ...processed.attributes,
      'testRunId': testRunId,
    });
  }
}
```

- [ ] Enable `BackendLogSink` when `--dart-define SOLIPLEX_SHIP_LOGS=true`
- [ ] Add `dumpArtifactBundle(String testName)` method that writes:
  - `logs.jsonl` — all MemorySink records as JSON
  - `breadcrumbs.json` — last 20 records before failure
  - `metadata.json` — testRunId, device, timestamps, test name

### Step 3: Add OIDC helpers to test config

**File:** `integration_test/patrol_test_config.dart`

- [ ] Add compile-time constants for OIDC credentials:

```dart
const oidcUsername = String.fromEnvironment('SOLIPLEX_OIDC_USERNAME');
const oidcPassword = String.fromEnvironment('SOLIPLEX_OIDC_PASSWORD');
const shipLogs = bool.fromEnvironment('SOLIPLEX_SHIP_LOGS');
```

- [ ] Add `fetchOidcConfig(String backendUrl)` — fetches provider config from
  `GET /api/login`, returns `serverUrl`, `clientId`, `scope`
- [ ] Add `seedAuthTokens(PatrolTester $)` — performs ROPC token exchange with
  Keycloak and injects tokens into `AuthNotifier` via `injectTestTokens`
- [ ] Derive token endpoint from OIDC discovery
  (`serverUrl/.well-known/openid-configuration`) rather than hardcoding
  Keycloak-specific paths

### Step 4: Create authenticated test

**File:** `integration_test/authenticated_test.dart`

- [ ] `patrolTest('authenticated rooms load', ...)`
- [ ] Initialize `TestLogHarness` with `testRunId` for Logfire correlation
- [ ] Call `verifyBackendOrFail(backendUrl)`
- [ ] Pump app with **in-memory auth storage** override (prevents Keychain
  state leaks from stale tokens)
- [ ] Wait for auth state to leave `AuthLoading` (restore completes)
- [ ] Call `seedAuthTokens($)` to obtain and inject ROPC tokens
- [ ] Use `harness.waitForLog('HTTP', 'GET /rooms')` to detect room load
- [ ] Assert at least one room is present
- [ ] **White-box:** `harness.expectLog('Auth', 'Authenticated')` to verify
  token injection worked
- [ ] On failure: `harness.dumpArtifactBundle('authenticated_rooms_load')`

### Step 5: Create CI workflow

**File:** `.github/workflows/patrol-integration.yml`

```yaml
name: Patrol Integration Tests

on:
  push:
    branches: [main, feat/patrol-integration]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  integration-test:
    runs-on: macos-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install Patrol CLI
        run: |
          dart pub global activate patrol_cli
          echo "$HOME/.pub-cache/bin" >> $GITHUB_PATH

      - name: Install dependencies
        run: flutter pub get

      - name: Install CocoaPods
        run: pod install --project-directory=macos

      - name: Backend health check
        env:
          BACKEND_URL: ${{ secrets.STAGING_BACKEND_URL }}
        run: |
          curl -f -s --connect-timeout 10 \
            "$BACKEND_URL/api/login" || \
            (echo "::error::Backend unreachable at $BACKEND_URL" && exit 1)

      - name: Run Patrol tests
        run: |
          patrol test \
            --target integration_test/ \
            --dart-define SOLIPLEX_BACKEND_URL=${{ secrets.STAGING_BACKEND_URL }} \
            --dart-define SOLIPLEX_OIDC_USERNAME=${{ secrets.OIDC_TEST_USERNAME }} \
            --dart-define SOLIPLEX_OIDC_PASSWORD=${{ secrets.OIDC_TEST_PASSWORD }} \
            --dart-define SOLIPLEX_SHIP_LOGS=true

      - name: Upload failure artifacts
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: patrol-failure-bundle
          path: |
            build/patrol/screenshots/
            build/patrol/logs/
          retention-days: 7
```

### Step 6: Document required GitHub secrets

| Secret | Description |
|--------|-------------|
| `STAGING_BACKEND_URL` | Backend URL with Keycloak auth enabled |
| `OIDC_TEST_USERNAME` | Keycloak test user username |
| `OIDC_TEST_PASSWORD` | Keycloak test user password |

### Step 7: Run and verify

```bash
# Local (authenticated, with Logfire shipping)
patrol test --target integration_test/authenticated_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_OIDC_USERNAME=patrol-test \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass \
  --dart-define SOLIPLEX_SHIP_LOGS=true

# Verify no-auth tests still pass
patrol test --target integration_test/smoke_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000

# Verify testRunId appears in Logfire
# Search: testRunId="<uuid from test output>"
```

## Logfire Correlation

When `SOLIPLEX_SHIP_LOGS=true`:

1. `TestLogHarness` generates a `testRunId` (UUID) and prints it to console
2. Every `LogRecord` gets `testRunId` injected via sanitizer
3. `BackendLogSink` ships records to backend → Logfire
4. In Logfire, query `testRunId="<uuid>"` to see:
   - All client-side logs (HTTP, auth, router, activeRun)
   - All server-side logs (if backend also tags with the ID via HTTP header)
   - Full distributed timeline of the test run

## Out of Scope

- `$.native` browser automation (deferred to hardening phase)
- Tool calling tests (add after auth is stable)
- Token refresh testing (unit-tested separately)
- Logout/re-auth flow
- iOS/Android CI runners
- `runStep()` instrumentation (deferred to future)
- Performance regression detection (deferred to future)

## Review Gate

**Tool:** `mcp__gemini__read_files` with `gemini-3-pro-preview`

**Files:** `lib/core/auth/auth_notifier.dart`,
`integration_test/test_log_harness.dart`,
`integration_test/patrol_test_config.dart`,
`integration_test/authenticated_test.dart`,
`.github/workflows/patrol-integration.yml`,
`lib/core/logging/logging_provider.dart`,
`docs/planning/patrol/phase-c-oidc-ci.md`

**Prompt:**

```text
Review the OIDC token seeding, Logfire correlation, and CI pipeline
against the Phase C spec.

Check:
1. injectTestTokens uses @visibleForTesting correctly
2. Race condition with _restoreSession() is addressed
3. TestCorrelationSanitizer injects testRunId into LogRecord.attributes
4. testRunId flows through BackendLogSink to Logfire
5. ROPC token endpoint derived from OIDC discovery (not hardcoded)
6. CI workflow includes CocoaPods install step
7. CI uploads both screenshots and log artifacts on failure
8. SOLIPLEX_SHIP_LOGS flag controls BackendLogSink in tests
9. Credentials passed via --dart-define (not hardcoded)

Report PASS or list specific issues.
```

## Success Criteria

- [ ] Authenticated test passes against Keycloak-protected backend
- [ ] ROPC token exchange works with "Direct Access Grants" enabled
- [ ] `testRunId` appears in Logfire when `SOLIPLEX_SHIP_LOGS=true`
- [ ] Failure artifact bundle produced (logs.jsonl, breadcrumbs, metadata)
- [ ] No-auth tests still pass (no regressions)
- [ ] CI workflow syntax is valid
- [ ] Zero analyzer issues
