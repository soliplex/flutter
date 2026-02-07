# OpenTelemetry Integration - Execution Plan (Option B)

## How to Use This Plan

Each sub-milestone is a single PR. Phase 1 milestones are sequential
(12.1→12.2→12.3, with 12.4 parallel to 12.3). Phase 2 and 3 milestones
can be worked independently once their dependencies are met.

## Resumption Context

- **Branch:** `feat/otel`
- **Base:** `main`
- **Spec:** `docs/planning/logging/12-opentelemetry-integration.md`
- **Logfire:** Account ready, write token available via `LOGFIRE_TOKEN` env var
- **Backend repo:** `~/dev/soliplex` (for Python ingest endpoint in 12.4)
- **Constraint:** DoD — no commercial SaaS. Self-hosted/open-source only.

---

## Phase 1 — Core (P0)

### 12.1 — LogRecord Attributes

**Status:** Pending

**Goal:** Add structured attributes to `LogRecord` so log export can carry
contextual key-value pairs (e.g. `user_id`, `http_status`, `view_name`).

#### Changes

**`packages/soliplex_logging/lib/src/log_record.dart`:**

- Add `final Map<String, Object> attributes` field with default `const {}`
- Non-breaking: existing constructor call sites compile unchanged

**`packages/soliplex_logging/lib/src/logger.dart`:**

- Add optional `Map<String, Object>? attributes` parameter to `info()`,
  `debug()`, `warning()`, `error()`, `fatal()`, `trace()`
- Pass through to `LogRecord` constructor

**`packages/soliplex_logging/lib/src/log_record.dart` (toString):**

- Include non-empty attributes in `toString()` output for debug visibility

#### Unit Tests

- `test/log_record_test.dart` — attributes stored, default empty, included
  in `toString()`
- `test/logger_test.dart` — attributes passed through to `LogRecord`

#### Integration Tests

- `test/integration/attributes_through_sink_test.dart` — Log a message
  with attributes via `Logger`, verify the `LogRecord` captured by
  `MemorySink` carries the attributes intact. Confirms the full path:
  `Logger.info(attributes:) → LogManager → LogSink.write() → LogRecord`

#### Acceptance Criteria

- [ ] `LogRecord` has `attributes` field, default `const {}`
- [ ] All `Logger` methods accept optional `attributes`
- [ ] Existing call sites compile without changes
- [ ] Integration: attributes survive Logger → LogManager → sink pipeline
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

### 12.2 — BackendLogSink

**Status:** Pending (blocked by 12.1)

**Goal:** A "dumb" sink that persists logs to disk and periodically POSTs
them as JSON to the Soliplex backend. No OTLP mapping — the backend
handles conversion to OTel format. Includes crash hooks, session
correlation, log sanitizer, and disk-backed queue.

#### Architecture

```text
BackendLogSink (LogSink)
├── LogSanitizer (PII redaction — runs first)
├── DiskQueue (JSONL write-ahead log)
│   ├── write() → append to file
│   ├── drain() → read + delete confirmed lines
│   └── Survives crashes, OS kills, restarts
├── BatchUploader (periodic HTTP POST)
│   ├── Timer-based flush (30s)
│   ├── Severity-triggered flush (immediate on ERROR/FATAL)
│   ├── Lifecycle flush (app pause/hidden)
│   └── Basic retry (backoff on 5xx/429, disable on 401)
└── SessionContext (injected into every payload)
    ├── sessionId (UUID, generated on app start)
    └── userId (from auth state)
```

#### Changes

**`packages/soliplex_logging/lib/src/sinks/log_sanitizer.dart` (new):**

- `LogSanitizer` class with configurable rules
- **Key redaction:** blocklist of sensitive keys (`password`, `token`,
  `auth`, `authorization`, `secret`, `ssn`, `credential`). Values
  replaced with `[REDACTED]`
- **Pattern scrubbing:** regex patterns for emails, SSNs, bearer tokens,
  IP addresses in message strings
- **Stack trace trimming:** strip absolute file paths to relative
- Runs on `LogRecord` before it reaches any sink
- Configurable: additional keys/patterns can be added at construction

**`packages/soliplex_logging/lib/src/sinks/disk_queue.dart` (new):**

- Write-ahead log backed by a JSONL file (one JSON object per line)
- `append(Map<String, Object> json)` — appends serialized record to file
- `drain(int count) → List<Map>` — reads up to N records from head
- `confirm(int count)` — removes confirmed records from file (rewrite
  remaining or use offset tracking)
- `pendingCount` — number of unsent records
- Constructor takes a `String directoryPath` (app layer resolves via
  `path_provider` and injects — keeps `soliplex_logging` pure Dart)
- **Web platform:** falls back to in-memory queue (no filesystem). Accept
  that web logs may be lost on tab close (same as before).
- File rotation: cap at 10 MB, drop oldest on overflow

**`packages/soliplex_logging/lib/src/sinks/backend_log_sink.dart` (new):**

- Implements `LogSink`
- Constructor takes:
  - `endpoint` (URL string, e.g. `/api/v1/logs`)
  - `http.Client` (injected by app layer)
  - `sessionId` (String)
  - `userId` (String?, nullable for pre-auth)
  - `resourceAttributes` (Map — service.name, version, os, device)
  - `LogSanitizer` (injected)
  - `DiskQueue` (injected)
  - Optional `batchSize` (default 100), `flushInterval` (default 30s)
  - Optional `networkChecker` (`bool Function()?`)

**`write(LogRecord)`:**

1. Run record through `LogSanitizer`
2. Serialize to JSON map:

   ```json
   {
     "timestamp": "2026-02-06T12:00:00.000Z",
     "level": "info",
     "logger": "Auth",
     "message": "User logged in",
     "attributes": {"user_id": "abc123"},
     "error": null,
     "stackTrace": null,
     "spanId": null,
     "traceId": null,
     "sessionId": "uuid-here",
     "userId": "user-abc"
   }
   ```

3. Append to `DiskQueue`
4. If ERROR/FATAL → trigger immediate flush

**`flush()`:**

1. If `networkChecker` provided and returns false → skip, keep buffered
2. Drain up to `batchSize` records from `DiskQueue`
3. POST JSON array to endpoint with `Authorization: Bearer <jwt>`
4. On 200 → confirm records in queue
5. On 429/5xx → exponential backoff (1s, 2s, 4s, max 60s), records
   stay in queue for next attempt
6. On 401/403 → stop retrying, surface via `onError` callback

**`close()`:**

- Final flush attempt, cancel timer

**Payload format:**

```json
{
  "logs": [ ...array of log objects... ],
  "resource": {
    "service.name": "soliplex-flutter",
    "service.version": "1.0.0",
    "os.name": "android",
    "device.model": "Pixel 7"
  }
}
```

**Dart crash hooks (in sink or app-layer setup):**

```dart
PlatformDispatcher.instance.onError = (error, stack) {
  logger.fatal('Uncaught async error', error: error, stackTrace: stack);
  return true;
};

FlutterError.onError = (details) {
  logger.fatal('Flutter framework error',
    error: details.exception, stackTrace: details.stack);
};
```

**`packages/soliplex_logging/pubspec.yaml`:**

- Add `http: ^1.2.0`
- NO `path_provider` — directory path injected by app layer (pure Dart)

**`packages/soliplex_logging/lib/soliplex_logging.dart`:**

- Export `backend_log_sink.dart`, `disk_queue.dart`, `log_sanitizer.dart`

#### Layering Note

`BackendLogSink` and `DiskQueue` are **pure Dart**. All platform
concerns are injected by the app layer: `http.Client`, `directoryPath`
(from `path_provider`), `sessionId`, `userId`, `networkChecker`, and
`resourceAttributes`.

#### Unit Tests

- `test/sinks/log_sanitizer_test.dart`:
  - Key redaction (password, token, auth → `[REDACTED]`)
  - Pattern scrubbing (emails, SSNs, bearer tokens in messages)
  - Stack trace path trimming
  - Custom additional keys/patterns
  - Does not modify safe records
- `test/sinks/disk_queue_test.dart`:
  - Append + drain round-trip
  - Confirm removes records
  - Survives simulated "crash" (create new instance, read pending)
  - File rotation at size limit
  - `pendingCount` accuracy
- `test/sinks/backend_log_sink_test.dart`:
  - Timer-based flush (advance fake timer)
  - Severity-triggered flush (ERROR → immediate)
  - Records serialized with sessionId/userId
  - Sanitizer runs before serialization
  - NetworkChecker false → skip flush
  - HTTP 200 → records confirmed
  - HTTP 429/5xx → records stay in queue, backoff
  - HTTP 401 → onError callback, stop retrying
  - `close()` attempts final flush

#### Integration Tests

- `test/integration/backend_sink_pipeline_test.dart` — Logger.info() →
  LogManager → BackendLogSink → mock HTTP client. Verify JSON payload
  includes sessionId, resource attributes, sanitized message.
- `test/integration/backend_sink_crash_recovery_test.dart` — Write
  records to DiskQueue, destroy sink (simulating crash), create new sink
  instance, verify pending records are sent on first flush.
- `test/integration/backend_sink_sanitizer_test.dart` — Log a message
  containing an email and a password attribute. Verify the HTTP payload
  has `[REDACTED]` values and scrubbed message.

#### Acceptance Criteria

- [ ] `LogSanitizer` redacts sensitive keys and patterns
- [ ] `DiskQueue` persists records to JSONL file
- [ ] Records survive app crash (new instance reads pending)
- [ ] `BackendLogSink` serializes `LogRecord` to simple JSON
- [ ] SessionId and userId injected into every payload
- [ ] Timer-based and severity-triggered flush
- [ ] HTTP 200 confirms records, 429/5xx retries with backoff
- [ ] HTTP 401 disables export, fires `onError`
- [ ] NetworkChecker skips flush when offline
- [ ] `close()` drains remaining queue
- [ ] Dart crash hooks capture uncaught exceptions as fatal logs
- [ ] Integration: crash recovery round-trip
- [ ] Integration: sanitizer scrubs PII from payload
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

### 12.3 — App Integration

**Status:** Pending (blocked by 12.2)

**Goal:** Wire `BackendLogSink` into the Flutter app via Riverpod
providers. Add Telemetry screen for enable/disable. All platforms use
the same endpoint.

#### Changes

**`lib/core/logging/log_config.dart`:**

- Add `backendLoggingEnabled` (bool, default false)
- Add `backendEndpoint` (String, default `/api/v1/logs`)

**`lib/core/logging/logging_provider.dart`:**

- Add `backendLogSinkProvider` — creates `BackendLogSink` with:
  - Endpoint from config
  - `http.Client` from platform client provider
  - `sessionId` from new `sessionIdProvider` (UUID, generated once)
  - `userId` from auth state provider
  - `resourceAttributes` from `package_info_plus` + `device_info_plus`
  - `networkChecker` from `connectivity_plus`
  - `LogSanitizer` with default DoD-appropriate rules
  - `DiskQueue` with path from `path_provider`
- Register with `LogManager`, `ref.onDispose → close`
- Sink disabled when `backendLoggingEnabled` is false

**Lifecycle flush:**

- **Mobile:** `AppLifecycleListener` → `flush()` on `paused`
- **Desktop:** `AppLifecycleListener` → `flush()` on `hidden`/`detached`
- **Web:** `visibilitychange` → `flush()` when `document.hidden`

**Dart crash hooks:**

- Set up `PlatformDispatcher.instance.onError` and
  `FlutterError.onError` in app initialization (before `runApp`)

**`lib/features/settings/telemetry_screen.dart` (new):**

- Enable/disable toggle
- Endpoint field (pre-filled, editable)
- Connection status indicator
- No token field needed (backend holds Logfire token)

**`lib/core/router/`:**

- Add route for Telemetry screen

#### Dependencies (App Layer Only)

- `connectivity_plus` — `NetworkStatusChecker` callback
- `package_info_plus` — `service.version` resource attribute
- `device_info_plus` — `device.model`, `os.version` resource attributes
- `path_provider` — `DiskQueue` file location
- `uuid` — session ID generation
- `flutter_secure_storage` — already in pubspec (not needed for token
  in Option B, but available for future use)

#### Unit Tests

- `test/core/logging/logging_provider_test.dart`:
  - BackendLogSink created when enabled
  - Sink not created when disabled
  - SessionId persists across provider rebuilds (same session)
  - UserId updates when auth state changes
  - Disposed on ref dispose

#### Widget Tests

- `test/features/settings/telemetry_screen_test.dart`:
  - Toggle enables/disables export
  - Connection status reflects sink state
  - Endpoint field editable

#### Integration Tests

- `test/integration/backend_toggle_flow_test.dart` — Toggle backend
  logging off → sink unregistered. Toggle on → re-registered. Verify
  logs stop/start flowing.
- `test/integration/backend_lifecycle_flush_test.dart` — Write records,
  simulate `AppLifecycleState.paused`, verify flush called.

#### Acceptance Criteria

- [ ] `backendLogSinkProvider` creates sink with all injected deps
- [ ] SessionId generated on startup, injected into every payload
- [ ] UserId from auth state, nullable for pre-auth logs
- [ ] Config toggle enables/disables at runtime
- [ ] Lifecycle flush on all platforms
- [ ] Dart crash hooks wired before `runApp`
- [ ] Telemetry screen with toggle, endpoint, status
- [ ] `connectivity_plus` integration
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

### 12.4 — Backend Ingest Endpoint

**Status:** Pending (can parallelize with 12.3)

**Goal:** Python endpoint that receives log JSON from Flutter clients and
forwards to Logfire via the Python OTel SDK.

#### Backend (~/dev/soliplex)

**`POST /api/v1/logs`:**

- Validate session JWT from `Authorization: Bearer <jwt>` header
- Accept JSON body: `{"logs": [...], "resource": {...}}`
- Map each log to OTel `LogRecord` using Python `opentelemetry-sdk`:
  - `level` → `SeverityNumber`
  - `timestamp` → `observedTimestamp`
  - `logger` → `InstrumentationScope`
  - `attributes` → OTel attributes (typed correctly by Python SDK)
  - `error`/`stackTrace` → exception semantic conventions
  - `sessionId`/`userId` → resource or record attributes
- Forward to Logfire via `OTLPLogExporter` (Python SDK handles batching,
  retry, compression, OTLP compliance)
- Rate limit: per-user/per-session caps
- Reject payloads > 1 MB (413)

#### Response Codes

- **200** — accepted
- **401** — invalid/expired session
- **413** — payload too large
- **429** — rate limited
- **502** — Logfire upstream error

#### Unit Tests (Python)

- Payload parsed correctly
- OTel mapping produces valid LogRecords
- Auth validation (reject invalid JWT)
- Rate limiting
- Oversized payload rejection

#### Acceptance Criteria

- [ ] Endpoint accepts Flutter log JSON
- [ ] Maps to OTel LogRecords via Python SDK
- [ ] Forwards to Logfire (verified in staging)
- [ ] Auth, rate limiting, size limits enforced
- [ ] Tests pass

---

## Phase 2 — Enhanced Context (P1)

### 12.5 — Breadcrumbs

**Status:** Pending (blocked by 12.2)

**Goal:** When a crash or error occurs, attach the last N log records as
contextual breadcrumbs to help reconstruct what happened.

#### Changes

- On ERROR/FATAL, `BackendLogSink` reads last 20 records from
  `MemorySink.records` (ring buffer already exists)
- Attaches as `"breadcrumbs": [...]` array in the crash payload
- Breadcrumb records are lightweight: timestamp, level, logger, message
  (no full attributes/stacktraces)

#### Acceptance Criteria

- [ ] Crash payloads include last 20 breadcrumb records
- [ ] Breadcrumbs come from existing MemorySink (no duplication)
- [ ] Tests verify breadcrumb attachment on fatal log

---

### 12.6 — Remote Log Level Control

**Status:** Pending (blocked by 12.3)

**Goal:** Allow the backend to control the app's minimum log level
without pushing an app update.

#### Changes

**Backend:** `GET /api/v1/config/logging`

```json
{
  "min_level": "debug",
  "modules": {"http": "trace", "auth": "debug"}
}
```

**Flutter:** On startup and every 10 minutes, fetch config. Update
`LogManager.minimumLevel` and per-logger overrides via Riverpod.

#### Acceptance Criteria

- [ ] App fetches log config on startup
- [ ] Log level changes without app restart
- [ ] Per-module overrides supported
- [ ] Graceful fallback if endpoint unreachable

---

### 12.7 — Error Fingerprinting (Backend)

**Status:** Pending (blocked by 12.4)

**Goal:** Group identical errors on the backend so operators see "Top 5
errors" rather than thousands of individual log entries.

#### Changes (Python)

- Hash: `sha256(exception_type + top_3_stack_frames)` → fingerprint
- Store fingerprint + count in database
- Logfire attributes include fingerprint for grouping
- Optional: alerting when error count exceeds threshold

#### Acceptance Criteria

- [ ] Errors grouped by fingerprint
- [ ] Count tracked per fingerprint per time window
- [ ] Fingerprint visible in Logfire attributes

---

## Phase 3 — Diagnostics (P2)

### 12.8 — RUM / Performance Metrics

**Status:** Pending (blocked by 12.2)

**Goal:** Capture basic performance metrics for the Flutter app.

#### Changes

- **Cold start:** Measure `main()` to first frame via
  `WidgetsBinding.instance.addPostFrameCallback`
- **Slow frames:** `SchedulerBinding.instance.addTimingsCallback` to
  detect frames exceeding 16ms
- **Route transitions:** `NavigatorObserver` logs timestamps on
  `didPush`/`didPop`
- **HTTP latency:** Already have `HttpObserver` — log request duration
  as attributes

All metrics logged as `info` with `{"metric": "cold_start", "ms": 1200}`
style attributes. Backend/Logfire aggregates.

#### Acceptance Criteria

- [ ] Cold start time captured and logged
- [ ] Slow frames detected and logged (with threshold)
- [ ] Route transition timing logged
- [ ] HTTP latency logged as structured attributes

---

### 12.9 — Screenshot on Error

**Status:** Pending (blocked by 12.2)

**Goal:** Capture a screenshot when an error occurs for visual debugging.

#### Changes

- Wrap `MaterialApp` in `RepaintBoundary` with `GlobalKey`
- On ERROR/FATAL, capture via `toImage()` → PNG bytes → base64
- Attach as attribute or separate upload (base64 in JSON is large)
- Consider: upload screenshot separately, reference by ID in log

#### Acceptance Criteria

- [ ] Screenshot captured on error
- [ ] Image attached to or referenced from error log
- [ ] Does not crash if RepaintBoundary unavailable

---

## Observability Gap Analysis

Comprehensive assessment of what the logging solution covers after all
phases, evaluated for a DoD Flutter app.

### Coverage After Phase 1 (Core)

| Capability | Status | Notes |
|------------|--------|-------|
| Structured logging | Covered | LogRecord + attributes |
| Remote log export | Covered | BackendLogSink → Logfire |
| Dart crash capture | Covered | FlutterError + PlatformDispatcher hooks |
| Offline persistence | Covered | DiskQueue (JSONL write-ahead) |
| PII/classified redaction | Covered | LogSanitizer (P0 for DoD) |
| Session correlation | Covered | UUID sessionId + userId |
| In-app log viewer | Covered | MemorySink + existing UI |
| Cross-platform support | Covered | Same endpoint all platforms |
| Lifecycle-aware flush | Covered | paused/hidden/visibilitychange |

### Coverage After Phase 2 (Enhanced Context)

| Capability | Status | Notes |
|------------|--------|-------|
| Breadcrumbs / event trail | Covered | Last N logs attached to crashes |
| Remote log level control | Covered | Backend config endpoint |
| Error grouping / fingerprinting | Covered | Backend-side (Python) |

### Coverage After Phase 3 (Diagnostics)

| Capability | Status | Notes |
|------------|--------|-------|
| Cold start timing | Covered | RUM metrics |
| Slow frame detection | Covered | SchedulerBinding callback |
| Route transition timing | Covered | NavigatorObserver |
| HTTP latency metrics | Covered | HttpObserver attributes |
| Screenshot on error | Covered | RepaintBoundary capture |

### Remaining Gaps (Accepted or Deferred)

| Capability | Status | Rationale |
|------------|--------|-----------|
| Native crash capture (SIGSEGV) | **Not covered** | Requires OS-level signal handlers (XL effort). Rely on device logs (adb logcat / Console.app) for repro. Most crashes will be Dart-level. |
| Session replay (video) | **Not covered** | Requires commercial-grade infrastructure. Screenshot-on-error is the pragmatic substitute. |
| Distributed tracing (spans) | **Deferred** | Phase 1 is log-only. When Python backend adds tracing, can propagate `traceparent` headers from HTTP client and attach trace context to logs. Evaluate `dartastic_opentelemetry` if their SDK matures. |
| Metrics (counters, histograms) | **Deferred** | RUM captures basic timing as log attributes. True OTel metrics (counters, histograms, gauges) can be added when the Python backend supports metrics ingest. |
| Alerting | **Partial** | Error fingerprinting (12.7) enables threshold-based alerts on the backend. Not a Flutter-side concern. |
| Log search / analytics | **Delegated** | Logfire provides SQL-like querying on structured attributes. No Flutter-side work needed. |

### Comprehensive Solution Grade: **B+**

After all 3 phases, the solution covers structured logging, crash
capture (Dart), offline persistence, PII protection, session
correlation, breadcrumbs, remote config, performance metrics, and error
grouping. The main gaps (native crashes, session replay, full
distributed tracing) are either impractical without commercial tools or
deferred to a future tracing phase.

For a DoD Flutter app with self-hosted constraints, this is a
**pragmatic and thorough** observability solution.

---

## Progress Tracker

| Sub-Milestone | Phase | Status | PR |
|---------------|-------|--------|----|
| 12.1 LogRecord attributes | 1 | Pending | — |
| 12.2 BackendLogSink | 1 | Pending | — |
| 12.3 App integration | 1 | Pending | — |
| 12.4 Backend ingest | 1 | Pending | — |
| 12.5 Breadcrumbs | 2 | Pending | — |
| 12.6 Remote log level | 2 | Pending | — |
| 12.7 Error fingerprinting | 2 | Pending | — |
| 12.8 RUM / performance | 3 | Pending | — |
| 12.9 Screenshot on error | 3 | Pending | — |
