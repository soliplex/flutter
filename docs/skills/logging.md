# Logging Guide

## Log Levels

- `fatal`: Unhandled platform error. App crashed.
- `error`: Caught exception; operation failed.
- `warning`: Degraded but continuing (retries exhausted, fallback used).
- `info`: User action milestone (login, navigate, create).
- `debug`: Code flow tracing, provider init, method entry.
- `trace`: Fine detail; minor callbacks, per-item UI events.

## Writing Logs

### Logger Selection

Use the typed logger from `lib/core/logging/loggers.dart`. If none
fit, add a new static field to `Loggers`.

- `Loggers.auth`: Login, logout, token refresh
- `Loggers.http`: HTTP client lifecycle
- `Loggers.activeRun`: AG-UI run lifecycle, events
- `Loggers.chat`: Thread creation, message send/cancel
- `Loggers.room`: Room init, thread selection
- `Loggers.router`: Redirects, initial location
- `Loggers.quiz`: Quiz lifecycle
- `Loggers.config`: URL resolution, settings
- `Loggers.ui`: General UI, home screen

### Message Style and Stack Traces

Messages state **what happened** and **to what**. Always use
`catch (e, s)` and pass both to the logger.

```dart
// Good
Loggers.chat.info('Thread created: $threadId');
catch (e, s) {
  Loggers.chat.error('Failed to send', error: e, stackTrace: s);
}

// Bad: vague message, lost stack trace
Loggers.chat.info('done');
catch (e) { Loggers.chat.error('Failed: $e'); }
```

### Where and What NOT to Log

Log at decision points: method entry, async results, fallback
branches, catch blocks, provider init (`debug`).

Do NOT log in widget `build` methods, getters, tight loops, or
anything containing tokens/PII/request bodies.

## Reading Logs

Find the `error`/`fatal` entry, then read the **preceding 20-30
entries**. Use `info` to trace user actions, `debug` to trace code
paths. Filter by `loggerName` to isolate a feature.

### MemorySink

Circular buffer (2000 records) via `memorySinkProvider`. Oldest
records evicted when full.
