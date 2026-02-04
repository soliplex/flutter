# 01 - App Shell & Entry

## Overview

The App Shell layer handles application bootstrap, initialization sequencing, and the
connection flow for establishing backend communication. It manages the critical startup
sequence including OAuth parameter capture, auth state resolution, and URL persistence.

## Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Default entry point; configures `SoliplexConfig` |
| `lib/run_soliplex_app.dart` | Bootstrap logic; captures OAuth, initializes providers |
| `lib/app.dart` | Root widget; auth gating before router mounts |
| `lib/soliplex_frontend.dart` | Library barrel file for external usage |
| `lib/version.dart` | Version constant (`soliplexVersion`) |
| `lib/features/home/home_screen.dart` | Backend URL entry UI; orchestrates connection |
| `lib/features/home/connection_flow.dart` | Pure connection state transition logic |
| `lib/features/settings/settings_screen.dart` | Version info, auth controls, network logs entry |

## Public API

### Entry & Initialization

**`main.dart`**

- `main()` - Application entry point. Configures `SoliplexConfig` with branding (logos,
  name) and invokes `runSoliplexApp()`.

**`run_soliplex_app.dart`**

- `runSoliplexApp({required SoliplexConfig config})` - Application bootstrap function.
  Initializes widget bindings, captures OAuth parameters (Web), clears OAuth URL params
  after capture, cleans stale keychain tokens, loads saved base URL, and establishes
  root `ProviderScope` with provider overrides.

**`app.dart`**

- `SoliplexApp` - Root widget. Manages global theme and `MaterialApp`. Gates router
  initialization until `authProvider` resolves, preventing premature routing.

**`soliplex_frontend.dart`**

- Barrel export of: `SoliplexConfig`, `AppLogoConfig`, design tokens, and entry point
  runner (`runSoliplexApp`).

**`version.dart`**

- `soliplexVersion` - Constant string for version display.

### Connection Flow Types

**`connection_flow.dart`**

Enums:

- `PreConnectAction` - Actions before connecting: `none`, `signOut`, `exitNoAuthMode`.

Sealed classes:

- `PostConnectResult` - Base sealed class for post-connect navigation decisions.
  - `RequireLoginResult` - Navigate to login; includes `shouldExitNoAuthMode` flag.
  - `AuthenticatedResult` - Navigate directly to authenticated landing route.

Functions:

- `determinePreConnectAction(...)` - Decides if `signOut` or `exitNoAuthMode` needed
  before connecting to a new URL.
- `determinePostConnectResult(...)` - Decides navigation target (Login vs Rooms) based
  on backend auth capabilities.
- `normalizeUrl(...)` - Normalizes URLs to prevent duplicate connection attempts.

### Screens

**`home_screen.dart`**

- `HomeScreen` - UI for entering backend URL. Orchestrates the full connection
  sequence:
  - URL validation and normalization
  - Pre-connect cleanup (sign out / exit no-auth mode)
  - Fetch auth providers from backend
  - Error handling for auth, network, API, and URL persistence failures
  - Post-connect navigation via `authenticatedLandingRoute` or login route
  - OIDC issuer provider invalidation when routing to login

**`settings_screen.dart`**

- `SettingsScreen` - Settings display and actions:
  - Version info with clipboard copy
  - Backend URL display with clipboard copy
  - Backend version fetch with loading/error states
  - Network request count with navigation to logs
  - Sign Out button with confirmation dialog
  - Disconnect button (exits no-auth mode)

## Dependencies

### External Packages

- `flutter` - UI framework
- `flutter_riverpod` - Dependency injection and state management
- `go_router` - Navigation
- `soliplex_client` - Backend SDK

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Auth | `auth_provider`, `auth_state`, `auth_storage`, `web_auth_callback` |
| Core/Providers | `shell_config_provider`, `config_provider`, `api_provider`, `backend_version_provider`, `http_log_provider`, `oidc_issuers_provider` |
| Core/Router | `app_router` |
| Core/Models | `soliplex_config` |
| Design | `design.dart` (barrel), `theme`, `tokens`, `spacing`, `color_scheme_extensions`, `theme_extensions` |

## Initialization Flow

```text
1. Bootstrap (run_soliplex_app.dart)
   ├─ Capture OAuth URL params (Web only, BEFORE router initializes)
   ├─ Clear OAuth params from URL (prevent re-processing)
   ├─ Clean stale keychain tokens (security hygiene)
   ├─ Load savedBaseUrl from storage
   └─ Initialize ProviderScope with overrides:
       ├─ shellConfigProvider ← static config from main
       ├─ preloadedBaseUrlProvider ← URL from storage
       └─ capturedCallbackParamsProvider ← OAuth params (if captured)

2. App Start (app.dart)
   ├─ Watch authProvider
   ├─ Loading? → Render spinner (standalone MaterialApp)
   └─ Ready? → Switch to MaterialApp.router

3. Connection (home_screen.dart)
   ├─ User inputs URL
   ├─ Normalize URL (trailing slash handling)
   ├─ determinePreConnectAction → signOut/exitNoAuthMode if needed
   ├─ fetchAuthProviders from backend
   ├─ Error handling:
   │   ├─ AuthenticationError → "Authentication failed"
   │   ├─ NetworkError → "Network error"
   │   ├─ SoliplexApiException → Display API error message
   │   ├─ ConfigPersistenceError → "Failed to save URL"
   │   └─ Generic → "Unexpected error"
   └─ determinePostConnectResult:
       ├─ RequireLoginResult → invalidate oidcIssuersProvider, go to /login
       └─ AuthenticatedResult → go to authenticatedLandingRoute

4. Persistence
   └─ Save validated URL to configProvider (with error handling)
```

## Architectural Patterns

### Composition Root

`run_soliplex_app.dart` serves as the composition root, injecting configuration
dependencies via `ProviderScope.overrides`.

### Sealed Classes for State Transitions

`connection_flow.dart` uses sealed classes (`PostConnectResult`) and enums
(`PreConnectAction`) to strictly model the connection decision tree, ensuring
exhaustive handling of all states.

### Logic Extraction

`HomeScreen` handles UI while complex state transition logic is extracted to pure
functions in `connection_flow.dart` for testability.

### Auth Gating

The root `SoliplexApp` physically prevents the Router from mounting until Auth is
stable, preventing "flash of login screen" issues and race conditions.

## Cross-Component Dependencies

### Depends On

- **02 - Authentication**: Auth state monitoring and user session data
- **03 - State Core**: API and backend version providers
- **09 - Inspector**: HTTP log visualization access
- **10 - Configuration**: Application and shell configuration
- **11 - Design System**: Theme and layout styling
- **14 - HTTP Layer**: Soliplex client integration
- **19 - Router**: Application navigation configuration

### Used By

- **19 - Router**: Imports Home and Settings screens for route definition

## Contribution Guidelines

### DO

- **Gate the Router:** Ensure `SoliplexApp` checks `authProvider` state before returning `MaterialApp.router` to prevent flash-of-login issues.
- **Isolate Decision Logic:** Use pure functions returning sealed classes (like `connection_flow.dart`) for complex conditional flows instead of `if/else` chains inside Widgets.
- **Inject Config via Overrides:** Always pass runtime configuration (URLs, params) via `ProviderScope.overrides` in `run_soliplex_app.dart`, never via global singletons.
- **Normalize URLs:** Use `normalizeUrl` before comparison or storage to handle trailing slashes consistently.
- **Clean State on Boot:** Ensure `run_soliplex_app.dart` cleans sensitive data (OAuth params) from the URL immediately after capture.

### DON'T

- **No Fat UI Orchestration:** Do not put connection sequences (auth → persist → navigate) in `HomeScreen._connect`. Create a `ConnectionController` provider.
- **Don't Block the UI Thread:** Do not perform synchronous storage I/O in `main.dart`; use the `run_soliplex_app` bootstrap sequence.
- **Avoid Generic Exception Catches:** Do not catch `Exception` without checking for specific subtypes (`AuthException`, `NetworkException`) first.
- **No Hardcoded Routes:** Do not string-bash paths (e.g., `'/login'`). Use the `ShellConfig` route definitions.
- **Don't Leak OAuth Params:** Do not allow the Router to initialize while OAuth parameters are still visible in the browser URL bar.

### Extending This Component

- **New Connection States:** Add variants to `PostConnectResult` (e.g., `MaintenanceModeResult`) and update the switch in `HomeScreen`.
- **Startup Logic:** Add new initialization steps to `run_soliplex_app.dart` *before* `runApp` if they require generic Flutter bindings, or *inside* `ProviderScope` if they need Ref access.
- **Error Handling:** Extend `_setError` logic in `HomeScreen` to map new `SoliplexException` subtypes to user-friendly messages.
