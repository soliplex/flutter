# T1 - Authentication Tests

## Overview

Comprehensive test coverage for authentication flow, state management, token handling,
and OIDC integration across app and client layers.

## Test Files (11)

| Location | File | Test Count |
|----------|------|------------|
| App | `test/core/auth/auth_flow_test.dart` | 5 |
| App | `test/core/auth/auth_notifier_test.dart` | 28 |
| App | `test/core/auth/auth_provider_test.dart` | 9 |
| App | `test/core/auth/auth_state_test.dart` | 6 |
| App | `test/core/auth/auth_storage_test.dart` | 5 |
| App | `test/core/auth/callback_params_test.dart` | 3 |
| App | `test/core/auth/oidc_issuer_test.dart` | 4 |
| App | `test/features/auth/auth_callback_screen_test.dart` | 5 |
| App | `test/features/login/login_screen_test.dart` | 10 |
| Client | `packages/soliplex_client/test/auth/oidc_discovery_test.dart` | 5 |
| Client | `packages/soliplex_client/test/auth/token_refresh_service_test.dart` | 8 |

## Test Utilities

| Utility | Purpose |
|---------|---------|
| `MockAuthStorage` | Simulates secure token storage |
| `MockTokenRefreshService` | Simulates token refresh responses |
| `MockSoliplexHttpClient` | HTTP client mock |
| `MockAuthFlow` | OAuth flow mock |
| `MockFlutterSecureStorage` | Secure storage mock |
| `TestData` | Factory for test fixtures |
| `waitForAuthRestore` | Async helper for session restoration |

## Test Coverage by Domain

### AuthResult / AuthException (`auth_flow_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| stores required accessToken | Mandatory token storage, optional fields null |
| stores all optional fields | Refresh/ID tokens and expiry stored correctly |
| AuthException stores message | Exception message persistence |
| AuthException.toString includes message | Human-readable error output |
| AuthRedirectInitiated.toString | Browser redirect event description |

### AuthNotifier (`auth_notifier_test.dart`)

**Session Restoration (Startup):**

| Test Case | Verifies |
|-----------|----------|
| attempts refresh before clearing state | Expired tokens trigger refresh |
| restores session when refresh succeeds | Successful refresh → Authenticated |
| clears state when refresh fails with invalidGrant | 400 response → logout |
| clears state when refresh fails with networkError | Network error → Unauthenticated |
| clears state when refresh throws exception | Generic exceptions → Unauthenticated |
| clears state when service reports noRefreshToken | Missing refresh token → logout |
| restores session without refresh attempt | Valid tokens loaded without network |
| transitions to Unauthenticated | No stored tokens → Unauthenticated |

**Runtime Token Refresh:**

| Test Case | Verifies |
|-----------|----------|
| preserves session on networkError (lenient) | Network errors don't logout |
| preserves session on noRefreshToken | Missing token preserves session |
| preserves session on unknownError (optimistic) | Unknown errors preserve session |
| clears state only on invalidGrant | Only explicit rejection logs out |
| updates tokens on success | New tokens update state |
| continues when storage save throws | Memory session survives storage failure |
| returns false when not authenticated | Skips refresh if not logged in |

**Web Auth Completion:**

| Test Case | Verifies |
|-----------|----------|
| creates Authenticated with issuer from pre-auth state | Callback merges with stored metadata |
| clears pre-auth state after reading | Cleanup of temporary state |
| throws AuthException when pre-auth state missing | Security check for unsolicited callbacks |
| uses fallback expiry when expiresIn null | Default token lifetime |
| saves tokens to storage | Login persists tokens |
| continues when storage save fails | Login works despite storage failure |
| fetches endSessionEndpoint from OIDC discovery | Dynamic logout endpoint resolution |
| stores null when discovery lacks endpoint | Handles IdPs without session management |
| completes when discovery fetch fails | Login proceeds despite discovery failure |

**Sign Out:**

| Test Case | Verifies |
|-----------|----------|
| clears tokens before calling endSession | Local wipe before remote |
| sets state to Unauthenticated before endSession | UI updates immediately |
| sets reason to explicitSignOut | Logout reason tracked |
| completes even when endSession throws | Local logout succeeds despite IdP failure |

**No-Auth Mode:**

| Test Case | Verifies |
|-----------|----------|
| enterNoAuthMode transitions to NoAuthRequired | Guest mode entry |
| clears tokens when from Authenticated | Session wiped entering guest mode |
| continues when clearTokens fails | Transition succeeds despite storage failure |
| exitNoAuthMode transitions to Unauthenticated | Guest mode exit |

### Auth Providers (`auth_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| hasAppAccessProvider returns true when Authenticated | Access granted for logged-in |
| returns true when NoAuthRequired | Access granted for guest |
| returns false when Unauthenticated/AuthLoading | Access denied otherwise |
| accessTokenProvider returns token when Authenticated | Token exposed |
| returns null when NoAuth/Unauthenticated | No token exposed |
| authStatusListenable notifies on state changes | Navigation listener triggers |
| does not notify when access unchanged | No redundant notifications |
| authFlowProvider throws when scheme null | Config validation |
| creates auth flow when scheme provided | Successful creation |

### AuthState (`auth_state_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| Unauthenticated default reason | Default sessionExpired reason |
| Unauthenticated equality | Same reason = equal |
| AuthLoading/NoAuth instances equal | Stateless equality |
| Authenticated equality | Deep equality on all fields |
| Authenticated.isExpired | Timestamp comparison logic |
| Authenticated.needsRefresh | Refresh trigger 1 min before expiry |

### AuthStorage (`auth_storage_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| saveTokens writes all fields | Full token persistence |
| does not write endSessionEndpoint | Discovery-based endpoint |
| loadTokens returns Authenticated | Successful hydration |
| returns null when field missing | Data integrity check |
| clearTokens deletes all keys | Secure cleanup |

### CallbackParams (`callback_params_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| WebCallbackParams.hasError | Success vs failure detection |
| toString masks token values | Log safety |
| NoCallbackParams default | Empty params behavior |

### OidcIssuer (`oidc_issuer_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| fields delegate to config | Wrapper correctness |
| discoveryUrl appends well-known path | OIDC URL construction |
| handles trailing slash | URL normalization |
| equality checks | Value equality |

### AuthCallbackScreen (`auth_callback_screen_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| shows error when OAuth error in params | Upstream error display |
| shows error code when no description | Fallback error display |
| shows error when access token missing | Token validation |
| calls completeWebAuth with tokens | Auth notifier invocation |
| shows error when completeWebAuth throws | Exception handling UI |

### LoginScreen (`login_screen_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| displays title and subtitle | Static UI elements |
| shows loading indicator | Async loading state |
| shows error message/retry | Error handling UI |
| shows message when empty | Empty state handling |
| shows sign in button for each issuer | Dynamic button generation |
| calls signIn with correct issuer | Auth flow trigger |
| shows error when AuthException thrown | Login failure UI |
| handles AuthRedirectInitiated gracefully | Browser redirect handling |
| change server button navigates | Navigation to config |

### OidcDiscovery (`oidc_discovery_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| fromJson returns document with endpoints | Parsing token/session endpoints |
| throws on scheme/host/port mismatch | SSRF protection |
| fetch returns document on success | HTTP integration |
| throws NetworkException/FormatException | Error handling |

### TokenRefreshService (`token_refresh_service_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| returns TokenRefreshSuccess | Successful refresh parsing |
| preserves original refresh token | Non-rotating token handling |
| uses fallback expiry | Default expiry calculation |
| returns noRefreshToken | Empty token early exit |
| returns invalidGrant failure | 400 Bad Request handling |
| returns networkError | Connectivity issue handling |
| returns unknownError on SSRF attempt | Security: origin validation |
| returns unknownError on missing access_token | Response validation |

## Security Tests

The auth test suite includes explicit security validations:

- **SSRF Protection**: OidcDiscovery and TokenRefreshService reject discovery docs
  pointing to different origins
- **Token Masking**: CallbackParams.toString masks actual token values
- **Unsolicited Callback Detection**: AuthNotifier throws on missing pre-auth state
- **Origin Validation**: Token refresh rejects responses from mismatched hosts/protocols
