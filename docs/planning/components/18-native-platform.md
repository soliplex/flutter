# 18 - Native Platform

## Overview

Platform-specific implementations for iOS/macOS/Android including HTTP clients
and device capabilities. Uses conditional imports and factory patterns to
abstract platform differences while optimizing for native capabilities.

## Files

| File | Purpose |
|------|---------|
| `lib/core/domain/interfaces/screen_wake_lock.dart` | Wake lock interface |
| `lib/core/infrastructure/platform/wakelock_plus_adapter.dart` | Wake lock implementation |
| `lib/shared/utils/platform_resolver.dart` | Platform detection |
| `packages/soliplex_client_native/lib/soliplex_client_native.dart` | Package barrel |
| `packages/soliplex_client_native/lib/src/clients/clients.dart` | Clients barrel |
| `packages/soliplex_client_native/lib/src/clients/cupertino_http_client.dart` | Apple NSURLSession |
| `packages/soliplex_client_native/lib/src/clients/cupertino_http_client_stub.dart` | Web stub |
| `packages/soliplex_client_native/lib/src/platform/create_platform_client.dart` | Client factory |
| `packages/soliplex_client_native/lib/src/platform/create_platform_client_io.dart` | IO impl |
| `packages/soliplex_client_native/lib/src/platform/create_platform_client_stub.dart` | Web stub |
| `packages/soliplex_client_native/lib/src/platform/platform.dart` | Platform barrel |

## Public API

### Wake Lock

**`ScreenWakeLock`** (interface) - Device sleep control

- `enable()` - Prevent sleep
- `disable()` - Allow sleep
- `isEnabled` - Current state

**`WakelockPlusAdapter`** - Implementation using `wakelock_plus`

### Platform Detection

**`isCupertino(BuildContext)`** - Check iOS/macOS platform

### HTTP Client Factory

**`createPlatformClient(defaultTimeout)`** - Returns optimal client:

- iOS/macOS → `CupertinoHttpClient` (NSURLSession)
- Android/Windows/Linux/Web → `DartHttpClient`

### CupertinoHttpClient

Apple-optimized HTTP client with HTTP/3, VPN support, battery efficiency.

- `request(method, uri, ...)` - One-off requests
- `requestStream(...)` - Streaming responses
- `close()` - Cleanup

## Dependencies

### External Packages

- `wakelock_plus` - Device power management
- `cupertino_http` - Apple NSURLSession bindings
- `http` - Core Dart HTTP

### Internal

- `soliplex_client` - `SoliplexHttpClient` interface

## Platform Client Initialization

```text
createPlatformClient(timeout):
├─ Web → Stub → DartHttpClient
└─ IO:
    ├─ macOS/iOS → Try CupertinoHttpClient
    │              └─ Fallback → DartHttpClient (test harness)
    └─ Android/Linux/Win → DartHttpClient
```

## Architectural Patterns

### Adapter Pattern

`WakelockPlusAdapter` adapts static plugin API to injectable interface.

### Factory Pattern

`createPlatformClient` abstracts platform-specific instantiation.

### Conditional Imports

`if (dart.library.io)` supports Web and Native compilation.

### Stubbing

Stubs ensure library compiles on Web without native dependencies.

### Interface Segregation

Native client depends on abstract `SoliplexHttpClient`, not concrete types.

## Cross-Component Dependencies

### Depends On

- **14 - HTTP Layer**: Network primitives required by native implementations

### Used By

- **03 - State Core**: Infrastructure provider injection
- **04 - Active Run**: Managing native run lifecycles (wake lock)

## Contribution Guidelines

### DO

- **Conditional Imports:** Use `if (dart.library.io)` and `if (dart.library.html)` to ensure web compatibility.
- **Interface Segregation:** Implementations must depend on abstract interfaces (like `ScreenWakeLock`), not concrete classes.
- **Factory Pattern:** Use factory functions (e.g., `createPlatformClient`) to encapsulate platform detection logic.
- **Clean Up:** Native resources (sockets, wake locks) must have explicit disposal/release methods.
- **Stubbing:** Always provide a stub implementation for platforms that don't support the native feature (e.g., Web).

### DON'T

- **No Logic in Stubs:** Stubs should throw `UnsupportedError` or return a no-op safe default, not contain business logic.
- **Don't Leak Platform Types:** Do not return `CupertinoHttpClient` directly. Return `SoliplexHttpClient`.
- **Avoid UI Dependencies:** Keep this layer focused on infrastructure (HTTP, Sensors). UI Platform adaptations belong in Design System.
- **No Hard Dependencies:** Do not make the core app depend on `dart:io` directly; always go through this abstraction layer.
- **Don't Ignore Web:** Every native feature added must have a strategy for Web (even if that strategy is "throw UnsupportedError").

### Extending This Component

- **New Native Feature:** Define the interface in `core/domain/interfaces`, then implement the adapter in `infrastructure/platform`.
- **New Platform Support:** Add the detection logic to `platform_resolver.dart` and the specific factory instantiation.
- **New Dependency:** If adding a native plugin (e.g., specific to Windows), add it to `soliplex_client_native` `pubspec.yaml`, not the main app.
