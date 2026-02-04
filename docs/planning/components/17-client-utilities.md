# 17 - Client: Utilities

## Overview

Shared utilities including error handling, cancellation tokens, URL building,
and formatting functions. Provides consistent error hierarchy and request
management across the client package.

## Files

| File | Purpose |
|------|---------|
| `lib/shared/utils/date_formatter.dart` | Date/time formatting |
| `lib/shared/utils/format_utils.dart` | General formatting utilities |
| `packages/soliplex_client/lib/src/errors/errors.dart` | Error barrel |
| `packages/soliplex_client/lib/src/errors/exceptions.dart` | Exception hierarchy |
| `packages/soliplex_client/lib/src/utils/cancel_token.dart` | Request cancellation |
| `packages/soliplex_client/lib/src/utils/url_builder.dart` | API URL construction |
| `packages/soliplex_client/lib/src/utils/utils.dart` | Utils barrel |

## Public API

### Error Hierarchy (exceptions.dart)

**`SoliplexException`** (base) - All client exceptions

- `NetworkException` - Connection/timeout failures
- `AuthException` - Authentication failures (401)
- `NotFoundException` - Resource not found (404)
- `ApiException` - Backend API errors (4xx/5xx)
- `CancelledException` - Request cancelled by user

### Cancellation (cancel_token.dart)

**`CancelToken`** - Cooperative cancellation

- `cancel()` - Signal cancellation
- `isCancelled` - Check status
- `throwIfCancelled()` - Throw if cancelled

### URL Building (url_builder.dart)

**`UrlBuilder`** - API endpoint construction

- `build(path, {queryParams})` - Construct full URL
- Base URL from configuration

### Formatting (date_formatter.dart, format_utils.dart)

- `formatRelativeTime(DateTime)` - "2 hours ago" style
- `formatDuration(Duration)` - Human-readable duration
- `formatBytes(int)` - File size formatting

## Dependencies

### External Packages

- `meta` - Annotations
- `intl` - Date/number formatting

### Internal

- Cross-package utility sharing

## Error Handling Pattern

```text
HTTP Layer:
├─ Connection failure → NetworkException
├─ 401 response → AuthException
├─ 404 response → NotFoundException
├─ 4xx/5xx → ApiException(statusCode, message)
└─ CancelToken triggered → CancelledException

UI Layer:
└─ ErrorDisplay maps exceptions to user messages
```

## Architectural Patterns

### Exception Hierarchy

Typed exceptions enable specific error handling at UI layer.

### Cooperative Cancellation

`CancelToken` allows request cancellation without thread interruption.

### URL Abstraction

`UrlBuilder` centralizes endpoint construction from configuration.

## Cross-Component Dependencies

### Depends On

- **None**: Foundational shared logic with no external component dependencies

### Used By

- **02 - Authentication**: Authentication helpers and error handling
- **05 - Threads**: Date formatting for thread list display
- **09 - Inspector**: HTTP status display and formatting
- **11 - Design System**: Platform detection for typography
- **12 - Shared Widgets**: Platform-adaptive UI helpers
- **14 - HTTP Layer**: CancelToken and exception types
- **15 - API Endpoints**: URL building and error handling

## Contribution Guidelines

### DO

- **Strict Error Hierarchy:** When adding exceptions, extend `SoliplexException` or one of its specific subclasses.
- **Pure Functions:** Formatters and utilities should be static pure functions where possible.
- **Universal Compatibility:** Ensure utilities work on Web, macOS, Windows, and Linux (no `dart:io` specific imports without checks).
- **Test Coverage:** Utility functions have high reuse; maintain 100% unit test coverage here.
- **Centralize Constants:** If a formatting string or magic number is used twice, move it here.

### DON'T

- **No UI Code:** Never import `package:flutter/material.dart` or similar. These are data utilities, not widgets.
- **Avoid Circular Dependencies:** Utilities should be the leaf nodes of the dependency graph. Do not import Domain or API layers.
- **Don't Print:** Do not use `print()`. If logging is needed, accept a logger callback or throw an exception.
- **No Global State:** Utilities should not store state.
- **Don't Swallow Stack Traces:** When wrapping errors in `SoliplexException`, pass the original `stackTrace` to the constructor.

### Extending This Component

- **New Utility:** Verify it doesn't already exist in standard Dart libraries.
- **Breaking Changes:** Be extremely cautious. Changes here ripple through every other component.
- **New Error Type:** Add it to `exceptions.dart` and update `HttpTransport` to map the relevant status code to this new error.
