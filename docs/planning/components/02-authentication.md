# 02 - Authentication Flow

## Overview

The Authentication system provides OIDC-based authentication with platform-specific
implementations for Native (iOS/Android/macOS) and Web. It uses a Backend-for-Frontend
(BFF) pattern on Web to delegate OAuth complexity to the server, while Native platforms
use direct OIDC flows via `flutter_appauth`.

## Files

| File | Purpose |
|------|---------|
| `lib/core/auth/auth_flow.dart` | Abstract `AuthFlow` interface |
| `lib/core/auth/auth_flow_native.dart` | Native implementation using flutter_appauth |
| `lib/core/auth/auth_flow_web.dart` | Web BFF implementation (redirect to backend) |
| `lib/core/auth/auth_notifier.dart` | Central Riverpod notifier for auth state |
| `lib/core/auth/auth_provider.dart` | Riverpod providers for DI |
| `lib/core/auth/auth_state.dart` | Sealed auth state classes |
| `lib/core/auth/auth_storage.dart` | Abstract secure storage interface |
| `lib/core/auth/auth_storage_native.dart` | Native storage (Keychain/Keystore) |
| `lib/core/auth/auth_storage_web.dart` | Web storage (localStorage) |
| `lib/core/auth/callback_params.dart` | OAuth callback parameter parsing |
| `lib/core/auth/oidc_issuer.dart` | OIDC issuer configuration wrapper |
| `lib/core/auth/web_auth_callback.dart` | Web callback handling interface |
| `lib/core/auth/web_auth_callback_native.dart` | Native stub (no-op) |
| `lib/core/auth/web_auth_callback_web.dart` | Web URL parameter capture |
| `lib/features/auth/auth_callback_screen.dart` | OAuth callback UI (Web) |
| `lib/features/login/login_screen.dart` | Login UI with issuer selection |
| `packages/soliplex_client/.../auth.dart` | Auth provider config model |
| `packages/soliplex_client/.../oidc_discovery.dart` | OIDC discovery document fetching |
| `packages/soliplex_client/.../token_refresh_service.dart` | Token refresh logic |

## Public API

### Core Abstractions

**`auth_flow.dart`**

- `AuthFlow` (abstract) - OIDC authentication contract
  - `authenticate(OidcIssuer)` - Initiates login
  - `endSession(...)` - Handles logout/redirects
- `createAuthFlow(...)` - Factory function returning platform-specific implementation
- `isWeb` - Platform detection getter
- `AuthResult` - DTO with `accessToken`, `idToken`, `refreshToken`, expiry
- `AuthException` - Authentication failure
- `AuthRedirectInitiated` - Control-flow exception for Web redirects

**`auth_state.dart`**

Sealed class hierarchy:

- `AuthState` (sealed)
  - `AuthLoading` - Initial restoration state
  - `Unauthenticated` - Logged out (includes `reason`)
  - `Authenticated` - Valid tokens; has `isExpired`, `needsRefresh`, `endSessionEndpoint`
  - `NoAuthRequired` - Backend doesn't require auth

**`auth_notifier.dart`**

- `AuthNotifier` - Central Riverpod notifier
  - `build()` - Initializes storage/refresh, triggers session restoration
  - `signIn(OidcIssuer)` - Orchestrates login flow
  - `completeWebAuth(...)` - Finalizes Web login from callback tokens
  - `signOut()` - Clears tokens, calls IdP logout
  - `tryRefresh()` - Runtime token refresh
  - `refreshIfExpiringSoon()` - Proactive refresh before expiry
  - `accessToken` - Current access token getter
  - `needsRefresh` - Check if refresh needed
  - `enterNoAuthMode()` / `exitNoAuthMode()` - No-auth backend support

**`auth_storage.dart`**

- `AuthStorage` (abstract) - Secure storage interface
  - `saveTokens`, `loadTokens`, `clearTokens`
  - `savePreAuthState`, `loadPreAuthState` - Web redirect state persistence
- `AuthStorageKeys` - Storage key constants
- `PreAuthState` - Web redirect state with `clientId`, `createdAt`, `maxAge`, `isExpired`
- `createAuthStorage()` - Factory for platform-specific storage
- `clearAuthStorageOnReinstall()` - iOS keychain cleanup helper

### Platform Implementations

**`auth_flow_native.dart`**

- `NativeAuthFlow` - Uses `flutter_appauth` for system browser flow

**`auth_flow_web.dart`**

- `WebAuthFlow` - BFF pattern; redirects to backend `/api/login`

**`auth_storage_native.dart`**

- `NativeAuthStorage` - Uses `flutter_secure_storage` (Keychain/Keystore)

**`auth_storage_web.dart`**

- `WebAuthStorage` - Uses `window.localStorage`

### Callback Handling

**`callback_params.dart`**

Sealed class:

- `CallbackParams` (sealed)
  - `WebCallbackParams` - Contains `token`, `accessToken`, `refreshToken`, `expiresIn`,
    `error`, `errorDescription`; has `hasError` getter
  - `NoCallbackParams` - Native stub

**`web_auth_callback.dart`**

- `CallbackParamsService` - Strategy interface for URL extraction
- `CallbackParamsCapture` - Static utility for `main()` token capture
- `UrlNavigator` / `WindowUrlNavigator` - URL manipulation abstractions (Web)

### Providers (auth_provider.dart)

- `authProvider` - Main `AuthNotifier` provider
- `authFlowProvider` - Platform-specific `AuthFlow`
- `authStorageProvider` - Platform-specific `AuthStorage`
- `tokenRefreshServiceProvider` - Token refresh service
- `capturedCallbackParamsProvider` - OAuth callback params from URL
- `callbackParamsServiceProvider` - Platform callback service
- `accessTokenProvider` - Current access token
- `oidcIssuersProvider` - Available OIDC issuers from backend
- `hasAppAccessProvider` - Boolean for routing (Authenticated OR NoAuthRequired)
- `authStatusListenableProvider` - Optimized listenable for GoRouter

### Client Package

**`oidc_discovery.dart`**

- `OidcDiscoveryDocument` - Validated OIDC provider configuration
  - `fromJson(Map, Uri)` - Factory with origin validation
- `fetchOidcDiscoveryDocument(...)` - HTTP fetch function

**`token_refresh_service.dart`**

- `TokenRefreshService` - Stateless token refresh service
  - `refresh(...)` - OIDC discovery -> POST refresh grant -> result
- `TokenRefreshResult` (sealed) - `Success` or `Failure`

### Screens

**`login_screen.dart`**

- `LoginScreen` - Displays OIDC issuers, initiates sign-in

**`auth_callback_screen.dart`**

- `AuthCallbackScreen` - Processes OAuth redirect callback (Web)

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `flutter_appauth` - Native OIDC (iOS/Android)
- `flutter_secure_storage` - Native secure storage
- `shared_preferences` - First-run detection (reinstall cleanup)
- `go_router` - Navigation
- `web` - JS interop (Web platform)
- `meta` - Annotations (@immutable, @protected)
- `soliplex_client` - Backend SDK

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `config_provider`, `shell_config_provider`, `api_provider` |
| Core/Auth | `web_auth_callback` (for callback handling) |
| Client Package | `TokenRefreshService`, `AuthProviderConfig`, `fetchAuthProviders` |
| Design | `theme`, `tokens/spacing` |
| Shared | `platform_adaptive_progress_indicator` |

## Authentication Flows

### Native Flow (iOS/Android/macOS)

```text
1. User taps "Sign In" on LoginScreen
2. AuthNotifier.signIn(issuer) called
3. NativeAuthFlow uses flutter_appauth
4. System browser opens -> User authenticates at IdP
5. AppAuth captures callback internally
6. Tokens returned to AuthNotifier
7. AuthNotifier saves to NativeAuthStorage (Keychain)
8. State -> Authenticated
9. Router navigates to authenticatedLandingRoute
```

### Web Flow (BFF Pattern)

```text
1. User taps "Sign In" on LoginScreen
2. AuthNotifier.signIn(issuer) called
3. AuthNotifier saves PreAuthState (issuer ID, discovery URL, clientId, createdAt)
4. WebAuthFlow constructs backend URL: /api/login/{issuer}?return_to=...
5. Browser redirects (throws AuthRedirectInitiated)

--- Browser leaves app, user authenticates at IdP ---

6. Backend handles OAuth, redirects to /#/auth/callback with params:
   - token (or access_token), refresh_token, expires_in
   - OR error, error_description
7. main() calls CallbackParamsCapture.captureNow() BEFORE router
8. Params stored in capturedCallbackParamsProvider as WebCallbackParams
9. AuthCallbackScreen reads params, checks hasError
10. AuthNotifier.completeWebAuth validates PreAuthState (checks isExpired) + tokens
11. State -> Authenticated
12. Router navigates to authenticatedLandingRoute
```

### Session Restoration (Startup)

```text
1. AuthNotifier.build() initializes
2. _restoreSession() calls storage.loadTokens()
3. If valid tokens: State -> Authenticated
4. If expired: Attempt _tryRefreshStoredTokens
5. If refresh succeeds: State -> Authenticated
6. If no tokens/failed: State -> Unauthenticated
```

### Token Refresh

```text
1. TokenRefreshService.refresh called
2. Fetch OidcDiscoveryDocument (validates origin)
3. POST to token_endpoint with refresh_token grant
4. Return TokenRefreshSuccess or TokenRefreshFailure
```

## Architectural Patterns

### Conditional Imports (Platform Abstraction)

Uses `if (dart.library.js_interop)` imports to switch between Native and Web
implementations while maintaining a clean interface.

### Sealed Classes

`AuthState`, `CallbackParams`, `TokenRefreshResult` use sealed classes for
exhaustive pattern matching.

### BFF (Backend for Frontend)

Web delegates OAuth complexity (PKCE, client secrets) to the backend. The app
only handles redirect initiation and token reception.

### Strategy Pattern

`AuthFlow` and `AuthStorage` interfaces allow swapping platform implementations.

### Initialization Capture

`CallbackParamsCapture` solves GoRouter "eating" URL parameters by capturing
them in `main()` before router initialization.

### Control Flow Exception

`AuthRedirectInitiated` satisfies `Future<AuthResult>` return type when the
operation intentionally terminates the local session (browser redirect).

### Security Validation

`OidcDiscoveryDocument` validates that `token_endpoint` origin matches discovery
URL origin to prevent SSRF/redirect attacks.

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: API provider for making authenticated network requests
- **10 - Configuration**: Access to environment URLs and shell configuration
- **11 - Design System**: UI styling and tokens for login screens
- **12 - Shared Widgets**: Reusable UI components used in auth flows
- **14 - HTTP Layer**: Network clients for communicating with auth backends
- **17 - Utilities**: Exception definitions for handling auth failures

### Used By

- **01 - App Shell**: Initialization, settings management, and UI integration
- **03 - State Core**: Token injection into API providers
- **19 - Router**: Route guarding based on authentication state

## Contribution Guidelines

### DO

- **Isolate Platform Dependencies:** Use conditional imports (`if (dart.library.js_interop)`) in factory files to keep platform-specific packages out of the core domain layer.
- **Enforce Exhaustive Matching:** Keep `AuthState` and `CallbackParams` as `sealed` classes. When handling state in widgets or notifiers, use `switch` statements to ensure compilation fails if a new state is added.
- **Handle Web Redirects Explicitly:** When implementing web auth flows that require leaving the SPA, throw `AuthRedirectInitiated` instead of returning a never-completing Future.
- **Validate Security Origins:** When fetching OIDC discovery documents, always validate that the `token_endpoint` origin matches the discovery URL origin to prevent SSRF/redirect attacks.
- **Persist Pre-Auth State (Web):** Before redirecting to the BFF login endpoint, save `PreAuthState` (issuer ID, client ID) with a timestamp. Validate this upon callback to prevent state injection or replay attacks.

### DON'T

- **No Secrets on Web:** Never implement OIDC client logic (client secrets, direct token exchange) in `auth_flow_web.dart`. Always use the BFF pattern to keep secrets on the server.
- **Don't Couple Notifiers to UI:** Never pass `BuildContext` or `WidgetRef` to `AuthNotifier` methods. Navigation should happen in the UI layer by listening to state changes.
- **Don't Discard `id_token`:** Do not ignore the `id_token` during token refresh. It is required for the `id_token_hint` parameter in `endSession` for proper RP-initiated logout.
- **Don't Crash on Storage Failure:** Do not let `AuthStorage.saveTokens` failures crash the app. Catch exceptions and allow the session to exist in memory for the current run.
- **No Hardcoded Redirect Schemes:** Never hardcode the callback scheme in `NativeAuthFlow`. Inject it via `ShellConfig` to support different environments and platforms.

### Extending This Component

- **Adding a New Platform:** Implement `AuthFlow` and `AuthStorage` interfaces, then add a new conditional import line in `createAuthFlow` and `createAuthStorage`.
- **Modifying State:** If adding a field to `Authenticated` (e.g., `scope`), update `AuthStorageKeys`, `NativeAuthStorage`, and `WebAuthStorage` to ensure persistence survives app restarts.
- **Customizing Refresh Logic:** Modify `TokenRefreshService` in `packages/soliplex_client`. Keep this class pure Dart to ensure it can be unit tested independently of the UI.
