# Phase C: OIDC Authentication + CI Pipeline

**Status:** pending
**Depends on:** Phase B

## Objective

Add OIDC authentication via Keycloak ROPC token seeding, then create a GitHub
Actions workflow. After this phase, tests can run authenticated against a
Keycloak-protected backend both locally and in CI.

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

## Deliverables

1. **`lib/core/auth/auth_notifier.dart`** — Add `@visibleForTesting`
   `injectTestTokens` method
2. **`integration_test/patrol_test_config.dart`** — Add OIDC helpers
3. **`integration_test/authenticated_test.dart`** — Authenticated rooms test
4. **`.github/workflows/patrol-integration.yml`** — CI workflow

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

### Step 2: Add OIDC helpers to test config

**File:** `integration_test/patrol_test_config.dart`

- [ ] Add compile-time constants for OIDC credentials:

```dart
const oidcUsername = String.fromEnvironment('SOLIPLEX_OIDC_USERNAME');
const oidcPassword = String.fromEnvironment('SOLIPLEX_OIDC_PASSWORD');
```

- [ ] Add `fetchOidcConfig(String backendUrl)` — fetches provider config from
  `GET /api/login`
- [ ] Add `seedAuthTokens(PatrolTester $)` — performs ROPC token exchange with
  Keycloak and injects tokens into `AuthNotifier` via `injectTestTokens`

### Step 3: Create authenticated test

**File:** `integration_test/authenticated_test.dart`

- [ ] `patrolTest('authenticated rooms load', ...)`
- [ ] Call `verifyBackendOrFail(backendUrl)`
- [ ] Pump app with **in-memory auth storage** override (prevents Keychain
  state leaks from stale tokens)
- [ ] Call `seedAuthTokens($)` to obtain and inject ROPC tokens
- [ ] Use `waitForCondition` to wait for rooms to render
- [ ] Assert at least one room is present

### Step 4: Create CI workflow

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
            --dart-define SOLIPLEX_OIDC_PASSWORD=${{ secrets.OIDC_TEST_PASSWORD }}

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: patrol-screenshots
          path: build/patrol/screenshots/
          retention-days: 7
```

### Step 5: Document required GitHub secrets

| Secret | Description |
|--------|-------------|
| `STAGING_BACKEND_URL` | Backend URL with Keycloak auth enabled |
| `OIDC_TEST_USERNAME` | Keycloak test user username |
| `OIDC_TEST_PASSWORD` | Keycloak test user password |

### Step 6: Run and verify

```bash
# Local (authenticated)
patrol test --target integration_test/authenticated_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_OIDC_USERNAME=patrol-test \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass

# Verify no-auth tests still pass
patrol test --target integration_test/smoke_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

## Out of Scope

- `$.native` browser automation (deferred to hardening phase)
- Tool calling tests (add after auth is stable)
- Screenshot-on-failure wrapper (add as needed)
- Token refresh testing (unit-tested separately)
- Logout/re-auth flow
- iOS/Android CI runners

## Review Gate

**Tool:** `mcp__gemini__read_files` with `gemini-3-pro-preview`

**Files:** `lib/core/auth/auth_notifier.dart`,
`integration_test/patrol_test_config.dart`,
`integration_test/authenticated_test.dart`,
`.github/workflows/patrol-integration.yml`,
`docs/planning/patrol/phase-c-oidc-ci.md`

**Prompt:**

```text
Review the OIDC token seeding and CI pipeline against the Phase C spec.

Check:
1. injectTestTokens uses @visibleForTesting correctly
2. ROPC token exchange hits the correct Keycloak endpoint
3. Credentials passed via --dart-define (not hardcoded)
4. CI workflow uses secrets for all sensitive values
5. Backend health check runs before expensive tests
6. $HOME/.pub-cache/bin added to GITHUB_PATH
7. Screenshot artifacts uploaded only on failure
8. No pumpAndSettle used

Report PASS or list specific issues.
```

## Success Criteria

- [ ] Authenticated test passes against Keycloak-protected backend
- [ ] ROPC token exchange works with "Direct Access Grants" enabled
- [ ] No-auth tests still pass (no regressions)
- [ ] CI workflow syntax is valid
- [ ] Zero analyzer issues
