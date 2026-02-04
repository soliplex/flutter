# 14 - Client: HTTP Layer

## Overview

Pure Dart networking stack built around composable Decorator pattern. Features
like authentication, observability, and token refreshing are layered onto the
underlying platform client. Provides automatic serialization, error mapping,
and cancellation support.

## Files

| File | Purpose |
|------|---------|
| `packages/soliplex_client/lib/soliplex_client.dart` | Package barrel export |
| `packages/soliplex_client/lib/src/http/authenticated_http_client.dart` | Auth header injection |
| `packages/soliplex_client/lib/src/http/dart_http_client.dart` | Base implementation |
| `packages/soliplex_client/lib/src/http/http.dart` | HTTP barrel export |
| `packages/soliplex_client/lib/src/http/http_client_adapter.dart` | Standard http.Client adapter |
| `packages/soliplex_client/lib/src/http/http_observer.dart` | Traffic observation interface |
| `packages/soliplex_client/lib/src/http/http_redactor.dart` | Sensitive data redaction |
| `packages/soliplex_client/lib/src/http/http_response.dart` | Response data class |
| `packages/soliplex_client/lib/src/http/http_transport.dart` | High-level facade |
| `packages/soliplex_client/lib/src/http/observable_http_client.dart` | Event emission decorator |
| `packages/soliplex_client/lib/src/http/refreshing_http_client.dart` | 401 retry decorator |
| `packages/soliplex_client/lib/src/http/soliplex_http_client.dart` | Base interface |
| `packages/soliplex_client/lib/src/http/token_refresher.dart` | Refresh interface |

## Public API

### Core Abstractions

**`SoliplexHttpClient`** (interface) - Base HTTP contract

- `request` - Standard HTTP requests → `Future<HttpResponse>`
- `requestStream` - Streaming (SSE) → `Stream<List<int>>`
- `close` - Release resources

**`HttpTransport`** (facade) - Application entry point

- JSON serialization/deserialization
- Error mapping (401→AuthException, 404→NotFoundException, etc.)
- CancelToken support

### Decorators (Layered)

1. **`DartHttpClient`** - Base using `package:http`
2. **`ObservableHttpClient`** - Event emission with redaction
3. **`AuthenticatedHttpClient`** - Bearer token injection
4. **`RefreshingHttpClient`** - 401 handling with retry

### Utilities

- **`HttpObserver`** - Traffic observation interface
- **`HttpRedactor`** - Sensitive data scrubbing
- **`HttpResponse`** - Immutable response container
- **`TokenRefresher`** - Refresh interface (dependency inversion)
- **`HttpClientAdapter`** - Adapts to standard `http.BaseClient`

## Dependencies

### External Packages

- `http` - Core networking
- `meta` - `@immutable` annotations

### Internal

- `src/errors` - Exception types
- `src/utils` - CancelToken

## Initialization Chain

```dart
// 1. Base
var client = DartHttpClient();

// 2. Observability (Redaction happens here)
client = ObservableHttpClient(client: client, observers: [Logger()]);

// 3. Auth Injection
client = AuthenticatedHttpClient(client, () => authStore.token);

// 4. Refresh Logic (Retries 401s)
client = RefreshingHttpClient(inner: client, refresher: authStore);

// 5. Application Interface
final transport = HttpTransport(client: client);
```

## Request/Response Lifecycle

### Request Flow

```text
Transport → Refreshing → Authenticated → Observable → DartHttp
   │            │             │              │            │
   │            │             │              │            └─ Execute network
   │            │             │              └─ Redact + emit event
   │            │             └─ Inject Bearer header
   │            └─ Check token expiry
   └─ Serialize body, check cancel
```

### Response Flow

```text
DartHttp → Observable → Authenticated → Refreshing → Transport
   │           │             │              │            │
   │           │             │              │            └─ Decode JSON
   │           │             │              └─ On 401: refresh + retry
   │           │             └─ Pass-through
   │           └─ Emit response event
   └─ Return raw bytes/status
```

## Architectural Patterns

### Decorator Pattern

Primary architecture for separating concerns (logging, auth, network).

### Adapter Pattern

`HttpClientAdapter` bridges Soliplex interfaces to standard Dart interfaces.

### Dependency Inversion

`RefreshingHttpClient` depends on `TokenRefresher` interface, not concrete auth.

### Facade

`HttpTransport` hides raw client complexity, provides typed API.

## Cross-Component Dependencies

### Depends On

- **17 - Utilities**: Exception definitions and request cancellation tokens

### Used By

- **02 - Authentication**: Client-side OIDC and token refresh services
- **15 - API Endpoints**: Network transport for all backend requests

## Contribution Guidelines

### DO

- **Keep it Pure Dart:** This package (`soliplex_client`) must **never** import `flutter`. Use `dart:io` or `dart:async` only.
- **Use Constructor Injection:** Dependencies (like `TokenRefresher` or `HttpObserver`) must be injected via constructor interfaces, not hardcoded.
- **Follow Decorator Pattern:** New HTTP behaviors (caching, metrics) must implement `SoliplexHttpClient` and wrap an `inner` client.
- **Handle Cancellation:** Always pass and respect `CancelToken`. Check `token.isCancelled` before starting expensive serialization or network calls.
- **Use Immutable Configuration:** Configuration objects passed to clients should be `@immutable`.

### DON'T

- **No Side Effects in Getters:** Properties of the client should be read-only. State changes happen via method calls that return new Futures.
- **Don't Swallow Exceptions:** Catch specific errors, wrap them in `SoliplexException` subtypes (from Component 17), and rethrow. Never fail silently.
- **Avoid Static State:** Do not use global static variables for auth tokens or configuration.
- **Don't Break Encapsulation:** Do not expose the underlying `http.Client` or platform-specific objects outside the adapter layer.
- **No Print Statements:** Use the `HttpObserver` interface for logging.

### Extending This Component

- **New Middleware:** Create a class implementing `SoliplexHttpClient` that accepts an `inner` client.
- **Interface Changes:** If modifying `SoliplexHttpClient`, you must update all decorators and the `HttpClientAdapter`.
- **Versioning:** This is a shared package. Breaking changes require a semver major bump.
