# soliplex_logging

Central logging package for Soliplex applications. Provides a structured,
level-based logging system with span support for future telemetry integration.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  soliplex_logging:
    path: packages/soliplex_logging
```

## Quick Start

```dart
import 'package:soliplex_logging/soliplex_logging.dart';

// Initialize (typically done once in main.dart)
LogManager.instance.addSink(ConsoleSink());

// Get a logger (raw API)
final log = LogManager.instance.getLogger('MyClass');

// Log messages
log.info('Application started');
log.debug('Processing item');
log.error('Failed to connect', error: e, stackTrace: s);

// With span context (for future telemetry)
log.info('Processing request', spanId: span.id, traceId: trace.id);
```

### Type-Safe Usage in Applications

In the Soliplex app, prefer the type-safe `Loggers` class:

```dart
import 'package:soliplex_frontend/core/logging/loggers.dart';

Loggers.auth.info('User logged in');
Loggers.http.debug('GET /api/users');
Loggers.activeRun.error('Failed', error: e, stackTrace: s);
```

See [logging-quickstart.md](../../docs/logging-quickstart.md) for app-specific
usage.

## Log Levels

| Level   | Value | Usage                        |
|---------|-------|------------------------------|
| trace   | 0     | Very detailed debugging      |
| debug   | 100   | Development debugging        |
| info    | 200   | Normal operations            |
| warning | 300   | Recoverable issues           |
| error   | 400   | Errors affecting functionality |
| fatal   | 500   | Unrecoverable errors         |

## API Reference

### LogLevel

Enum representing log severity levels with numeric values for comparison.

```dart
if (LogLevel.warning >= LogLevel.info) {
  // warning is more severe than info
}
```

### LogRecord

Immutable data class containing log event information:

- `level` - Severity level
- `message` - Log message
- `timestamp` - When the log was created
- `loggerName` - Name of the logger
- `error` - Optional error object
- `stackTrace` - Optional stack trace
- `spanId` - Optional span ID for telemetry
- `traceId` - Optional trace ID for telemetry

### LogSink

Interface for log output destinations:

```dart
abstract interface class LogSink {
  void write(LogRecord record);
  Future<void> flush();
  Future<void> close();
}
```

### ConsoleSink

Log sink that outputs to the console via `dart:developer`.

```dart
final sink = ConsoleSink(enabled: true);
LogManager.instance.addSink(sink);
```

### Logger

Facade for emitting log records. Obtained via `LogManager.instance.getLogger()`.

Methods: `trace()`, `debug()`, `info()`, `warning()`, `error()`, `fatal()`

All methods accept optional parameters:

- `error` - Associated error object
- `stackTrace` - Stack trace for errors
- `spanId` - Span ID for telemetry
- `traceId` - Trace ID for telemetry

### LogManager

Singleton manager for log configuration and sink management.

```dart
// Set minimum level (logs below this are filtered)
LogManager.instance.minimumLevel = LogLevel.debug;

// Add/remove sinks
LogManager.instance.addSink(mySink);
LogManager.instance.removeSink(mySink);

// Flush all sinks
await LogManager.instance.flush();

// Close all sinks
await LogManager.instance.close();
```
