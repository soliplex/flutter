# 03 - State Management Core

## Overview

Core provider infrastructure for API communication, HTTP client management, backend
health monitoring, and system lifecycle management. Acts as the bridge between
configuration/auth layers and data consumption layers.

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/api_provider.dart` | HTTP client stack and API instance |
| `lib/core/providers/backend_health_provider.dart` | Backend reachability check |
| `lib/core/providers/backend_version_provider.dart` | Server version info |
| `lib/core/providers/infrastructure_providers.dart` | Wake lock and lifecycle |
| `lib/features/settings/backend_versions_screen.dart` | Version display UI |

## Public API

### API & HTTP Infrastructure (api_provider.dart)

HTTP client stack using **Decorator Pattern** for layered concerns:

| Provider | Type | Purpose |
|----------|------|---------|
| `baseHttpClientProvider` | `Provider<SoliplexHttpClient>` | Base observable client (no auth) |
| `authenticatedClientProvider` | `Provider<SoliplexHttpClient>` | Adds Authorization header, 401 retry/refresh |
| `httpTransportProvider` | `Provider<HttpTransport>` | Transport layer with JSON encoding |
| `urlBuilderProvider` | `Provider<UrlBuilder>` | API URL construction from config |
| `apiProvider` | `Provider<SoliplexApi>` | Primary API service instance |
| `soliplexHttpClientProvider` | `Provider<SoliplexHttpClient>` | Authenticated client for SSE streaming |
| `httpClientProvider` | `Provider<http.Client>` | Adapter to standard Dart http.Client |
| `agUiClientProvider` | `Provider<AgUiClient>` | AG-UI client with non-closing wrapper |

### Backend Status

| Provider | Type | Purpose |
|----------|------|---------|
| `backendHealthProvider` | `FutureProvider<bool>` | Checks `/api/ok` (5s timeout) |
| `backendVersionInfoProvider` | `FutureProvider<BackendVersionInfo>` | Fetches server version details |

### Infrastructure (infrastructure_providers.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `screenWakeLockProvider` | `Provider<ScreenWakeLock>` | Platform wake lock adapter |
| `runLifecycleProvider` | `Provider<RunLifecycle>` | Run state management (stop/start/pause) |

### UI (backend_versions_screen.dart)

- `BackendVersionsScreen` - Search and view backend package versions

## Dependencies

### External Packages

- `flutter_riverpod` - State management and DI
- `http` - Base HTTP networking types
- `soliplex_client` - Core API client (`SoliplexApi`, `BackendVersionInfo`)
- `soliplex_client_native` - Platform HTTP implementations

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Auth | `auth_provider` (token injection) |
| Core/Providers | `config_provider`, `http_log_provider` |
| Core/Application | Lifecycle implementation |
| Core/Infrastructure | Platform adapters (WakeLock) |
| Design | UI components |

## HTTP Client Stack

The HTTP stack uses nested decorators to separate concerns:

```text
1. Platform Client (native http.Client)
   ↓
2. Observable Client (wraps Platform, notifies httpLogProvider)
   ↓
3. Authenticated Client (wraps Observable, adds Authorization header)
   ↓
4. Refreshing Client (wraps Authenticated, intercepts 401s, retries after refresh)
```

## API Instance Construction

```text
configProvider ──→ urlBuilderProvider ──┐
                                        ├──→ apiProvider
authProvider ──→ authenticatedClientProvider ──→ httpTransportProvider ──┘
```

## Resource Ownership Strategy

Problem: External libraries like `AgUiClient` call `.close()` on HTTP dependencies.

Solution: `agUiClientProvider` wraps the shared client in `_NonClosingHttpClient`.

Result: The wrapper ignores `.close()` calls, keeping shared connection alive.

## Architectural Patterns

### Decorator Pattern

Heavily used in `api_provider.dart` to layer behaviors (logging, auth, refresh)
onto the HTTP client without modifying the base class.

### Provider Pattern

All dependencies lazy-loaded and scoped via Riverpod.

### Proxy/Adapter Pattern

- `_NonClosingHttpClient` - Protective proxy preventing premature closure
- `httpClientProvider` - Adapts internal client to standard `http` package interface

## Cross-Component Dependencies

### Depends On

- **02 - Authentication**: User tokens for API calls
- **04 - Active Run**: Application logic and run context
- **09 - Inspector**: Logging HTTP interactions for debugging
- **10 - Configuration**: Backend endpoints and global settings
- **14 - HTTP Layer**: Base HTTP client functionality
- **18 - Native Platform**: Infrastructure implementations and native bridges

### Used By

- **01 - App Shell**: Global state access for home and settings
- **02 - Authentication**: Backend connectivity for auth operations
- **04 - Active Run**: Backend interaction for active run state
- **05 - Threads**: Data providers for message history
- **06 - Rooms**: Data providers for room management
- **07 - Documents**: Data providers for document retrieval
- **08 - Chat UI**: State management for chat interactions
- **20 - Quiz**: State management for quiz features

## Contribution Guidelines

### DO

- **Follow Provider Naming:** Use the pattern `<domain><Type>Provider` (e.g., `apiProvider`, `backendHealthProvider`).
- **Enforce the Ref Rule:** Business logic functions must accept `Ref`, never `WidgetRef`. Logic relying on `WidgetRef` cannot be composed or tested easily.
- **Separate Responsibilities:** Ensure providers do one thing. If a provider fetches Rooms, it should not also fetch Threads. Use `ref.watch` to combine states if necessary.
- **Use Family Providers:** Use `.family` modifiers for parameterized data (e.g., fetching data by `roomId`) rather than reading a selected ID from another provider.
- **Protect Shared Resources:** If a provider exposes a shared resource (like an HTTP client) to a consumer that might close it, wrap it in a protective proxy (see `_NonClosingHttpClient` pattern).

### DON'T

- **No Fat Providers:** Do not overload `infrastructure_providers.dart` with unrelated global state. Create a new file if the domain differs.
- **Avoid `flutter_riverpod` in Domain Logic:** While this component bridges Flutter, logic inside Notifiers should not depend on UI types like `BuildContext` or `WidgetRef`.
- **No UI in Core:** Do not add Widget files to this component's directory structure. Move them to a feature directory.
- **Don't Break the Decorator Chain:** When modifying HTTP clients, ensure the order remains: Platform → Observable → Authenticated → Refreshing.
- **Avoid `.read` in Build:** Do not use `ref.read` inside the body of a provider; use `ref.watch` to ensure reactivity.

### Extending This Component

- **Adding a New Client Feature:** Implement it as a decorator in the `soliplex_client` package first, then inject it via `api_provider.dart`.
- **New Global State:** If adding system-wide state (e.g., a new sensor), prefer `NotifierProvider` over `StateProvider` to encapsulate the modification logic.
- **Documentation:** Update the "Public API" table in this document and register the new provider in the architectural docs.
