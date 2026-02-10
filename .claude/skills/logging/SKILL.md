---
name: logging
description: Logging conventions for this codebase. Use when writing log statements, adding catch blocks, creating providers, investigating errors, or reading MemorySink contents.
user-invocable: false
---

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

Your log message MUST state **what happened** and **to what entity**.
When logging an error, you MUST use a `catch (e, s)` block and pass
both the `error` and `stackTrace` objects to the logger. Losing the
stack trace is a critical error.

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

## Usage in Patrol E2E Tests

Patrol tests **cannot** see internal app state. They rely entirely on
logs captured by the `TestLogHarness` via `MemorySink`.

- **Assert:** `harness.expectLog('ActiveRun', 'RUN_FINISHED')` verifies
  an operation happened.
- **Wait:** `harness.waitForLog('ActiveRun', 'RUN_FINISHED')` blocks
  until an async process completes.
- **Debug:** `harness.dumpLogs(last: 50)` dumps recent logs on failure.

**Workflow for discovering log patterns:**

1. Run the app manually (via `debugging` skill).
2. Perform the action you want to test.
3. Call `mcp__dart-tools__get_app_logs` to see the `[DEBUG]` output.
4. Copy the exact logger name and message pattern into your
   `harness.expectLog` or `harness.waitForLog` call.

**Write clear, unique, and predictable log messages to create stable,
non-flaky tests.** Vague messages like `'done'` make test assertions
impossible to write.
