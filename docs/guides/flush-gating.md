# ActiveRun-Aware Log Flush Gating

## Overview

During an AI agent run (`RunningState`), `BackendLogSink` holds periodic
log flushes to avoid sending partial run logs mid-stream. Logs accumulate
on disk and flush as a batch when the run completes. A safety valve ensures
logs are never held indefinitely, and ERROR-level logs always bypass the
gate for real-time observability.

## How It Works

### Flush Gate Callback

`BackendLogSink` accepts an optional `flushGate` callback (`bool Function()?`):

- **`null`** (default) — flush proceeds normally (backwards compatible)
- **Returns `true`** — flush proceeds normally
- **Returns `false`** — flush is held (gated)

This follows the same pure-Dart callback pattern as `networkChecker` and
`jwtProvider`.

### Safety Valve

When the gate is closed, a `_gatedSince` timestamp records when gating
began. If the gate remains closed longer than `maxFlushHoldDuration`
(default: 5 minutes), the flush proceeds anyway. This prevents log loss
from hung or abandoned runs.

The timer resets when the gate opens, so a new run gets a fresh 5-minute
window.

### Force Flush

`flush(force: true)` bypasses the gate entirely. This is used by:

- **ERROR/FATAL writes** — time-sensitive for observability
- **`close()`** — ensures all logs ship on app shutdown
- **Run completion listener** — flushes held logs immediately when
  `RunningState` transitions to `CompletedState`

## Architecture

### Pure Dart Layer (`soliplex_logging`)

```text
BackendLogSink
  +-- flushGate: bool Function()?     // null = always allow
  +-- maxFlushHoldDuration: Duration   // default 5 min
  +-- _gatedSince: DateTime?          // tracks gate-closed start

flush({bool force = false})
  1. [existing checks: closed, JWT, disabled, network, backoff]
  2. if !force && gate closed:
       - start timer (_gatedSince ??= now)
       - if under maxFlushHoldDuration → return (hold)
       - else → safety valve, proceed to flush
  3. if gate open → reset _gatedSince
  4. [existing: drain, POST, handle response]
```

### Flutter Layer (`logging_provider.dart`)

**`backendLogSinkProvider`** wires the gate to ActiveRun state:

```dart
flushGate: () {
  try {
    final runState = ref.read(activeRunNotifierProvider);
    return runState is! RunningState;
  } catch (_) {
    return true;  // fail-open on provider errors
  }
},
```

**`logConfigControllerProvider`** listens for run completion:

```dart
ref.listen<ActiveRunState>(
  activeRunNotifierProvider,
  (previous, next) {
    if (previous is RunningState && next is CompletedState) {
      ref.read(backendLogSinkProvider.future).then((sink) {
        if (sink != null) unawaited(sink.flush(force: true));
      });
    }
  },
);
```

## Test Coverage

Seven tests in `backend_log_sink_test.dart` under the `flushGate` group:

| Test | Verifies |
|------|----------|
| blocks flush when false | No HTTP request when gate closed |
| allows flush when true | Normal flush when gate open |
| null defaults to allow | Backwards compatibility |
| safety valve flushes after max hold | 1ms duration, verify flush proceeds |
| force: true bypasses flushGate | Direct `flush(force: true)` sends |
| error-level logs bypass gate | Write ERROR, verify force flush fires |
| gatedSince resets when gate opens | Close/open/close cycle gets fresh timer |

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `flushGate` | `null` | Callback returning `true` to allow flush |
| `maxFlushHoldDuration` | 5 minutes | Safety valve timeout |

## Behavior Matrix

| Scenario | Periodic Flush | ERROR Write | close() |
|----------|---------------|-------------|---------|
| No gate (null) | Sends | Sends | Sends |
| Gate open (true) | Sends | Sends | Sends |
| Gate closed (false) | Held | **Sends** (force) | **Sends** (force) |
| Gate closed > 5 min | **Sends** (safety) | **Sends** (force) | **Sends** (force) |
| Run completes | **Sends** (forced) | N/A | N/A |
