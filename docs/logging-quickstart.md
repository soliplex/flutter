# Logging Quickstart

This guide covers how to use the logging system in the Soliplex Flutter app.

## Overview

The logging system consists of:

1. **soliplex_logging package** - Pure Dart logging primitives
2. **Loggers class** - Type-safe static accessors for app-wide loggers
3. **LogConfig** - Persistent configuration via SharedPreferences
4. **consoleSinkProvider** - Riverpod provider managing sink lifecycle

## Using Type-Safe Loggers

Always use the `Loggers` class for logging in the app:

```dart
import 'package:soliplex_frontend/core/logging/loggers.dart';

// Simple logging
Loggers.auth.info('User logged in');
Loggers.http.debug('GET /api/users');
Loggers.chat.warning('Message retry');

// Error logging with context
try {
  await api.call();
} catch (e, stackTrace) {
  Loggers.activeRun.error('API call failed', error: e, stackTrace: stackTrace);
}
```

## Available Loggers

| Logger | Use For |
|--------|---------|
| `Loggers.auth` | Authentication events (login, logout, token refresh) |
| `Loggers.http` | HTTP request/response logging |
| `Loggers.activeRun` | AG-UI run processing events |
| `Loggers.chat` | Chat feature events |
| `Loggers.room` | Room feature events |
| `Loggers.router` | Navigation/routing events |
| `Loggers.quiz` | Quiz feature events |
| `Loggers.config` | Configuration changes |
| `Loggers.ui` | General UI events |

## Adding a New Logger

1. Edit `lib/core/logging/loggers.dart`:

```dart
abstract final class Loggers {
  // ... existing loggers ...

  /// Description of what this logger is for.
  static final myFeature = LogManager.instance.getLogger('MyFeature');
}
```

1. Update this guide with the new logger.

## Log Level Guidelines

| Level | When to Use | Example |
|-------|-------------|---------|
| trace | Loop iterations, detailed flow | `Loggers.http.trace('Header: $key=$value')` |
| debug | State changes, request/response | `Loggers.http.debug('GET $url')` |
| info | User actions, lifecycle events | `Loggers.auth.info('User logged in')` |
| warning | Recoverable issues, deprecations | `Loggers.config.warning('Using fallback')` |
| error | Failures that affect functionality | `Loggers.chat.error('Send failed', error: e)` |
| fatal | Unrecoverable, app must restart | `Loggers.config.fatal('Corrupt state')` |

### Guidelines

- **trace/debug**: Use liberally during development; these are filtered in
  production
- **info**: Use for events that would be useful in production logs
- **warning**: Use when something unexpected happened but the app can continue
- **error**: Always include the `error` and `stackTrace` parameters
- **fatal**: Rare; only for truly unrecoverable situations

## Span Context (Future)

The logging system supports span IDs for future telemetry integration:

```dart
// When telemetry is implemented, you'll be able to correlate logs with traces
Loggers.http.info(
  'Request started',
  spanId: currentSpan.id,
  traceId: currentTrace.id,
);
```

For now, these fields are optional and can be omitted.

## Changing Log Level

The log level can be changed via the Settings screen (coming in M04) or
programmatically:

```dart
// Via provider
ref.read(logConfigProvider.notifier).setMinimumLevel(LogLevel.debug);

// Directly (for testing)
LogManager.instance.minimumLevel = LogLevel.trace;
```

## Troubleshooting

### Logs not appearing

1. Check that `consoleSinkProvider` is being read somewhere in the widget tree
2. Verify the minimum level allows your log (default is `info`)
3. Check that console logging is enabled in LogConfig

### Duplicate logs

This shouldn't happen if using `consoleSinkProvider` as the single source of
truth. If you see duplicates, check that no code is manually adding sinks.

### Performance concerns

- Use `trace`/`debug` for high-frequency logs
- These levels are filtered in production
- Log messages are not formatted if below minimum level
