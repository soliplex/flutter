# Milestone 03: OIDC Auth Flow (Keycloak)

**Status:** pending
**Depends on:** 02-test-infrastructure

## Objective

Implement a Patrol test that drives the full Keycloak OIDC login flow using
Patrol's `$.native` API to interact with the system browser that
`flutter_appauth` opens. After this milestone, authenticated Patrol tests are
possible against a Keycloak-protected backend.

## Background

### How Auth Works in Soliplex

1. App fetches auth providers from `GET /api/login` — returns Keycloak config
   (`serverUrl`, `clientId`, `scope`)
2. User taps "Sign In" — app calls `flutter_appauth`'s
   `authorizeAndExchangeCode()` with PKCE
3. System browser opens Keycloak login page (ephemeral WebAuthenticationSession)
4. User enters credentials and submits
5. Keycloak redirects back to app via `oauthRedirectScheme://callback`
6. App receives tokens, transitions to `Authenticated` state
7. Rooms and chat become accessible

### Why Patrol

Standard `integration_test` cannot interact with the system browser. Patrol's
`$.native` API can tap buttons and enter text in native UI outside the Flutter
widget tree — exactly what is needed for the Keycloak login form.

## Pre-flight Checklist

- [ ] Confirm M02 complete (test infrastructure passing)
- [ ] Verify Keycloak test realm has a test user provisioned
- [ ] Verify backend `GET /api/login` returns at least one Keycloak provider
- [ ] Review Keycloak login page for accessibility labels (username/password
  field labels, submit button text) — use macOS Accessibility Inspector
- [ ] Confirm `oauthRedirectScheme` in test config matches platform URL scheme
  (macOS `Info.plist` CFBundleURLSchemes)
- [ ] **Keycloak ROPC grant:** Verify the Keycloak client has "Direct Access
  Grants" enabled (required for the fallback token exchange approach).
  In Keycloak admin: Clients → (client) → Settings → "Direct Access Grants
  Enabled" = ON. This is often disabled by default.

## Deliverables

1. **`integration_test/oidc_auth_test.dart`** — Keycloak login Patrol test
2. **OIDC helper in `patrol_test_base.dart`** — Reusable login function for
   subsequent milestones

## Files to Create/Modify

- [ ] `integration_test/oidc_auth_test.dart` (create)
- [ ] `integration_test/patrol_test_base.dart` (add `performKeycloakLogin`,
  `performKeycloakLoginViaMock`, `fetchOidcConfig`)
- [ ] `lib/core/auth/auth_notifier.dart` (add `@visibleForTesting`
  `injectTestTokens` method)

## Implementation Steps

### Step 1: Add reusable OIDC login helper

**File:** `integration_test/patrol_test_base.dart`

Add a shared function that subsequent tests (M04, M05) can call.

#### Primary approach: Patrol native with text-based selectors

```dart
/// Drives the Keycloak login flow via Patrol native interaction.
///
/// Uses text-based accessibility selectors (NOT resourceId, which maps to
/// Android native view IDs and does not work for web content).
Future<void> performKeycloakLogin(PatrolTester $) async {
  // 1. Tap the Keycloak sign-in button in the Flutter UI
  await $.tap(find.textContaining('Keycloak'));

  // 2. System browser opens — Patrol native interaction
  //    Use text/label selectors (accessibility tree), not resourceId
  await $.native.waitUntilVisible(Selector(text: 'Username'));

  // 3. Enter test credentials via accessibility labels
  await $.native.tap(Selector(text: 'Username'));
  await $.native.enterText(Selector(text: 'Username'), text: oidcUsername);
  await $.native.tap(Selector(text: 'Password'));
  await $.native.enterText(Selector(text: 'Password'), text: oidcPassword);

  // 4. Submit the form (Keycloak default button text)
  await $.native.tap(Selector(text: 'Sign In'));

  // 5. Wait for redirect back to the app and authenticated state
  await waitForCondition(
    $.tester,
    condition: () => find.byType(RoomListTile).evaluate().isNotEmpty,
    timeout: Duration(seconds: 20),
    failureMessage: 'App did not reach authenticated state after OIDC login',
  );
}
```

**Important: Text-based selectors** — `resourceId` maps to Android native view
IDs (`R.id.xyz`), NOT HTML DOM `id` attributes. Web content inside system
browsers is exposed via the Accessibility tree. Use `Selector(text: ...)` to
match form field labels and button text.

#### Fallback approach: flutter_appauth channel mock

**Risk:** On macOS, `flutter_appauth` uses `ASWebAuthenticationSession` — a
secure, isolated system window designed to prevent automation. Patrol's
`$.native` may not be able to interact with this window reliably.

If native interaction fails, implement a direct token exchange fallback.

#### Prerequisites for fallback

1. **Add `@visibleForTesting` method to `AuthNotifier`:**

```dart
// In lib/core/auth/auth_notifier.dart
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

2. **Add OIDC config fetcher to `patrol_test_base.dart`:**

```dart
/// Fetches OIDC provider config from backend's /api/login endpoint.
/// Returns the first provider's serverUrl, clientId, and scope.
Future<({String serverUrl, String clientId, String scope})>
    fetchOidcConfig(String backendUrl) async {
  final res = await http.get(Uri.parse('$backendUrl/api/login'))
      .timeout(const Duration(seconds: 8));
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final first = data.entries.first;
  final config = first.value as Map<String, dynamic>;
  return (
    serverUrl: config['server_url'] as String,
    clientId: config['client_id'] as String,
    scope: config['scope'] as String,
  );
}
```

#### Fallback implementation

```dart
/// Fallback: Direct ROPC token exchange with Keycloak, then inject tokens.
/// Requires "Direct Access Grants" enabled on the Keycloak client.
Future<void> performKeycloakLoginViaMock(PatrolTester $) async {
  // 1. Fetch OIDC config from backend (serverUrl, clientId, scope)
  final oidcConfig = await fetchOidcConfig(backendUrl);

  // 2. Exchange credentials via Keycloak ROPC grant
  final tokenUrl = '${oidcConfig.serverUrl}/protocol/openid-connect/token';
  final tokenRes = await http.post(
    Uri.parse(tokenUrl),
    body: {
      'grant_type': 'password',
      'client_id': oidcConfig.clientId,
      'username': oidcUsername,
      'password': oidcPassword,
      'scope': oidcConfig.scope,
    },
  ).timeout(const Duration(seconds: 10));

  final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;

  // 3. Inject tokens into AuthNotifier via test hook
  //    Use SoliplexApp (the actual root widget, not "App")
  final container = ProviderScope.containerOf(
    $.tester.element(find.byType(SoliplexApp)),
  );
  container.read(authProvider.notifier).injectTestTokens(
    accessToken: tokenData['access_token'] as String,
    refreshToken: tokenData['refresh_token'] as String,
    idToken: tokenData['id_token'] as String,
    expiresAt: DateTime.now().add(
      Duration(seconds: tokenData['expires_in'] as int),
    ),
    issuerId: 'keycloak',
    issuerDiscoveryUrl:
        '${oidcConfig.serverUrl}/.well-known/openid-configuration',
    clientId: oidcConfig.clientId,
  );

  // 4. Wait for authenticated state
  await waitForCondition(
    $.tester,
    condition: () => find.byType(RoomListTile).evaluate().isNotEmpty,
    timeout: Duration(seconds: 15),
    failureMessage: 'App did not reach authenticated state after mock login',
  );
}
```

**Decision tree during M03 implementation:**

1. Try primary approach (Patrol native + text selectors) first
2. If `ASWebAuthenticationSession` blocks automation → use fallback
3. Document which approach works in the test code for future reference
4. CI always uses fallback (TCC permissions unreliable on runners)

### Step 2: Create OIDC auth test

**File:** `integration_test/oidc_auth_test.dart`

```dart
import 'patrol_test_base.dart';

void main() {
  patrolTestWithScreenshot('live.oidc.keycloak_login', ($) async {
    // Preflight: verify backend and auth providers
    await verifyBackendOrFail(backendUrl);

    // Verify OIDC credentials are provided
    assert(
      oidcUsername.isNotEmpty && oidcPassword.isNotEmpty,
      'OIDC test credentials required: '
      '--dart-define SOLIPLEX_OIDC_USERNAME=... '
      '--dart-define SOLIPLEX_OIDC_PASSWORD=...',
    );

    // Build app in OIDC mode (no auth overrides)
    await $.pumpWidget(buildTestApp());
    ignoreKeyboardAssertions();

    // Wait for login screen to render
    await waitForCondition(
      $.tester,
      condition: () => find.textContaining('Sign In').evaluate().isNotEmpty ||
          find.textContaining('Keycloak').evaluate().isNotEmpty,
      timeout: Duration(seconds: 15),
      failureMessage: 'Login screen did not appear',
    );

    // Perform Keycloak OIDC login via native interaction
    await performKeycloakLogin($);

    // Verify authenticated state: rooms should be visible
    expect(find.byType(RoomListTile), findsAtLeast(1));
  });
}
```

### Step 3: Run and verify

- [ ] Start backend with Keycloak auth enabled (not `--no-auth-mode`)
- [ ] Run with OIDC credentials:

```bash
patrol test --target integration_test/oidc_auth_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=oidc \
  --dart-define SOLIPLEX_OIDC_USERNAME=testuser \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass
```

- [ ] Confirm the system browser opens, Keycloak form appears
- [ ] Confirm credentials are entered and form submitted
- [ ] Confirm app redirects back and shows authenticated state
- [ ] Screenshot generated on failure

### Step 4: Verify no-auth smoke still works

- [ ] Run smoke test to confirm dual-mode is not broken:

```bash
patrol test --target integration_test/smoke_test.dart \
  --dart-define SOLIPLEX_AUTH_MODE=no-auth
```

## Keycloak Selector Reference

Text-based accessibility selectors for Keycloak default theme:

| Element | Primary Selector | Fallback Selector | Notes |
|---------|-----------------|-------------------|-------|
| Username | `Selector(text: 'Username')` | `Selector(text: 'Username or email')` | Label varies by Keycloak version/theme |
| Password | `Selector(text: 'Password')` | `Selector(textContaining: 'assword')` | Case-insensitive partial match |
| Login button | `Selector(text: 'Sign In')` | `Selector(text: 'Log In')` | Varies by theme |
| Error | `Selector(text: 'Invalid username or password')` | — | Failed login |

**Selector strategy:** Try primary selector first, fall back if not found
within 5 seconds. Implement as a helper:

```dart
Future<void> nativeTapWithFallback(
  PatrolTester $,
  Selector primary,
  Selector fallback, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    await $.native.waitUntilVisible(primary, timeout: timeout);
    await $.native.tap(primary);
  } catch (_) {
    await $.native.tap(fallback);
  }
}
```

**Do NOT use `resourceId`** — it maps to Android native view IDs, not HTML DOM
`id` attributes. Web content in system browsers is accessed via Accessibility
tree labels.

If using a custom Keycloak theme, use macOS Accessibility Inspector to identify
the correct labels and update selectors in `performKeycloakLogin`.

## ASWebAuthenticationSession Risk (macOS)

On macOS, `flutter_appauth` uses `ExternalUserAgent.ephemeralAsWebAuthenticationSession`
which creates a secure, isolated system window. This window is designed to
prevent other processes from controlling the auth flow.

**Implications:**

- Patrol's `$.native` may not be able to find or interact with elements in
  the secure window
- macOS TCC (Transparency, Consent, and Control) permissions may block
  accessibility access
- CI runners (`macos-latest`) may not have required TCC permissions

**Mitigation:** The fallback approach (direct token exchange + mock injection)
bypasses the browser entirely while still validating the full authenticated
app flow against the real backend. See Step 1 fallback approach above.

## Out of Scope

- Token refresh testing (covered by unit tests in `auth_notifier_test.dart`)
- Logout flow (sign out and re-auth)
- Multiple OIDC providers (only Keycloak tested)
- Web BFF auth flow (Patrol native is for native platforms only)
- Custom Keycloak themes (uses default theme selectors)

## Validation Gate

### Automated Checks

- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] `patrol test --target integration_test/oidc_auth_test.dart` passes
  (with OIDC credentials)
- [ ] `patrol test --target integration_test/smoke_test.dart` still passes
  (no-auth mode)
- [ ] Existing `flutter test` suite unaffected

### Manual Verification

- [ ] System browser opens with Keycloak login form
- [ ] Credentials entered automatically by Patrol native
- [ ] App returns to authenticated state after login
- [ ] Screenshot captured on failure (e.g., wrong credentials)

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `integration_test/oidc_auth_test.dart`,
`integration_test/patrol_test_base.dart`,
`docs/planning/patrol/03-oidc-auth-flow.md`,
`docs/patrol-analysis.md`,
`lib/core/auth/auth_flow_native.dart`,
`lib/core/auth/auth_notifier.dart`,
`lib/core/auth/oidc_issuer.dart`

**Prompt:**

```text
Review the OIDC Patrol test against the spec in 03-oidc-auth-flow.md,
source analysis in patrol-analysis.md, and the actual auth implementation.

Check:
1. performKeycloakLogin uses $.native correctly for system browser interaction
2. Keycloak selectors match default theme (username, password, kc-login)
3. Credentials passed via --dart-define (not hardcoded)
4. Auth state verified after login (rooms visible = authenticated)
5. No pumpAndSettle (streaming-safe)
6. Aligns with flutter_appauth flow in auth_flow_native.dart
7. oauthRedirectScheme in test config matches platform URL scheme
8. performKeycloakLogin is reusable for M04/M05 tests

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] Keycloak login form driven by Patrol native interaction
- [ ] Credentials provided via `--dart-define` (never hardcoded)
- [ ] App reaches authenticated state after OIDC login
- [ ] `performKeycloakLogin` helper is reusable by M04/M05
- [ ] No-auth smoke test still passes
- [ ] Screenshot captured on failure
- [ ] Gemini critique: PASS
