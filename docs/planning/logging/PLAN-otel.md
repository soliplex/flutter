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
LogManager (sanitization layer)
├── LogSanitizer (PII redaction — ALL sinks get sanitized data)
│   └── Runs before record is dispatched to any sink
│
BackendLogSink (LogSink)
├── DiskQueue (JSONL write-ahead log)
│   ├── write() → append to file
│   ├── drain() → read + delete confirmed lines
│   └── Survives crashes, OS kills, restarts
├── BatchUploader (periodic HTTP POST)
│   ├── Timer-based flush (30s)
│   ├── Severity-triggered flush (immediate on ERROR/FATAL)
│   ├── Lifecycle flush (app pause/hidden)
│   ├── Basic retry (backoff on 5xx/429, re-enable on new JWT)
│   ├── Poison pill protection (max 3 retries per batch, then discard)
│   └── Byte-based batch cap (< 1 MB payload)
└── SessionContext (injected into every payload)
    ├── installId (UUID, generated once per install, persisted)
    ├── sessionId (UUID, generated on app start)
    └── userId (from auth state)
```

#### Changes

**`packages/soliplex_logging/lib/src/log_sanitizer.dart` (new):**

- `LogSanitizer` class with configurable rules
- **Key redaction:** blocklist of sensitive keys (`password`, `token`,
  `auth`, `authorization`, `secret`, `ssn`, `credential`). Values
  replaced with `[REDACTED]`
- **Pattern scrubbing:** regex patterns for emails, SSNs, bearer tokens,
  IP addresses in message strings
- **Stack trace trimming:** strip absolute file paths to relative
- Configurable: additional keys/patterns can be added at construction

**`packages/soliplex_logging/lib/src/log_manager.dart`:**

- Add optional `LogSanitizer? sanitizer` to `LogManager` constructor
- In `emit()`, run `sanitizer.sanitize(record)` before dispatching to
  sinks. This ensures ALL sinks (Console, Memory, Backend) receive
  sanitized data. DoD P0: no unsanitized PII reaches any output.

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
  - `installId` (String — per-install UUID, persisted locally)
  - `sessionId` (String)
  - `userId` (String?, nullable for pre-auth)
  - `resourceAttributes` (Map — service.name, version, os, device)
  - `DiskQueue` (injected)
  - Optional `maxBatchBytes` (default 900 KB — stays under 1 MB limit)
  - Optional `batchSize` (default 100), `flushInterval` (default 30s)
  - Optional `networkChecker` (`bool Function()?`)

**`write(LogRecord)`:**

1. Record is already sanitized by `LogManager` pipeline
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
     "installId": "install-uuid",
     "sessionId": "session-uuid",
     "userId": "user-abc"
   }
   ```

3. **Record size guard:** if serialized JSON exceeds 64 KB, truncate
   `message`, `attributes`, `stackTrace`, and `error` (in that order)
4. Append to `DiskQueue`
5. If ERROR/FATAL → trigger immediate flush

**`flush()`:**

1. If `networkChecker` provided and returns false → skip, keep buffered
2. Drain records from `DiskQueue` up to `batchSize` OR `maxBatchBytes`
   (whichever limit hits first — prevents 413 from backend)
3. POST JSON object to endpoint with `Authorization: Bearer <jwt>`
4. On 200 → confirm records in queue, reset retry counter
5. On 429/5xx → exponential backoff (1s, 2s, 4s, max 60s), records
   stay in queue for next attempt, increment retry counter
6. On 401/403 → disable export, surface via `onError` callback.
   **Recovery:** if a new JWT is observed (e.g. re-login), re-enable
   export automatically and retry
7. **Poison pill:** if same batch fails 3 consecutive times → discard
   batch, log diagnostic to `onError`, move to next batch

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
  (`LogSanitizer` is in `lib/src/` not `lib/src/sinks/` since it's
  used by `LogManager`, not just `BackendLogSink`)

#### Layering Note

`BackendLogSink`, `DiskQueue`, and `LogSanitizer` are **pure Dart**.
`LogSanitizer` is wired into `LogManager` (not `BackendLogSink`) so all
sinks receive sanitized data. All platform concerns are injected by the
app layer: `http.Client`, `directoryPath` (from `path_provider`),
`installId`, `sessionId`, `userId`, `networkChecker`, and
`resourceAttributes`.

#### Unit Tests

- `test/log_sanitizer_test.dart`:
  - Key redaction (password, token, auth → `[REDACTED]`)
  - Pattern scrubbing (emails, SSNs, bearer tokens in messages)
  - Stack trace path trimming
  - Custom additional keys/patterns
  - Does not modify safe records
- `test/log_manager_sanitizer_test.dart`:
  - LogManager with sanitizer sanitizes before all sinks
  - LogManager without sanitizer passes records unmodified
- `test/sinks/disk_queue_test.dart`:
  - Append + drain round-trip
  - Confirm removes records
  - Survives simulated "crash" (create new instance, read pending)
  - File rotation at size limit
  - `pendingCount` accuracy
- `test/sinks/backend_log_sink_test.dart`:
  - Timer-based flush (advance fake timer)
  - Severity-triggered flush (ERROR → immediate)
  - Records serialized with installId/sessionId/userId
  - Byte-based batch cap (stops draining when payload nears limit)
  - NetworkChecker false → skip flush
  - HTTP 200 → records confirmed
  - HTTP 429/5xx → records stay in queue, backoff
  - HTTP 401 → onError callback, stop retrying
  - Poison pill: 3 consecutive failures → batch discarded
  - Record size guard: oversized record truncated before queue
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
- [ ] `LogSanitizer` wired into `LogManager` — all sinks get sanitized data
- [ ] `DiskQueue` persists records to JSONL file
- [ ] Records survive app crash (new instance reads pending)
- [ ] `BackendLogSink` serializes `LogRecord` to simple JSON
- [ ] installId, sessionId, and userId injected into every payload
- [ ] Timer-based and severity-triggered flush
- [ ] Batch capped by bytes (< 1 MB) and record count
- [ ] HTTP 200 confirms records, 429/5xx retries with backoff
- [ ] HTTP 401 disables export, re-enables on new JWT
- [ ] NetworkChecker skips flush when offline
- [ ] `close()` drains remaining queue
- [ ] Poison pill: batch discarded after 3 consecutive failures
- [ ] Record size guard: records > 64 KB truncated (message, attributes,
  stackTrace, error — in priority order)
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
- Add `backendEndpoint` (String, default `/api/v1/logs`).
  **Locked in production builds** — editable only in debug/dev to
  prevent misconfiguration or exfiltration risk (DoD)

**`lib/core/logging/logging_provider.dart`:**

- Add `installIdProvider` — per-install UUID, persisted to local storage
  on first launch. Stable "device Y" key for cross-session queries.
- Add `backendLogSinkProvider` — creates `BackendLogSink` with:
  - Endpoint from config
  - `http.Client` from platform client provider
  - `installId` from `installIdProvider`
  - `sessionId` from new `sessionIdProvider` (UUID, generated once)
  - `userId` from auth state provider
  - `resourceAttributes` from `package_info_plus` + `device_info_plus`
  - `networkChecker` from `connectivity_plus`
  - `DiskQueue` with path from `path_provider`
- Wire `LogSanitizer` with default DoD-appropriate rules into
  `LogManager` (not `BackendLogSink`) so all sinks get sanitized data
- Register with `LogManager`, `ref.onDispose → close`
- Sink disabled when `backendLoggingEnabled` is false

**Lifecycle flush:**

- **Mobile:** `AppLifecycleListener` → `flush()` on `paused`
- **Desktop:** `AppLifecycleListener` → `flush()` on `hidden`/`detached`
- **Web:** `visibilitychange` → `flush()` when `document.hidden`

**Session start marker:**

- On app startup (after providers initialize), emit a single `info`-level
  log with attributes: `app_version`, `build_number`, `os_name`,
  `os_version`, `device_model`, `dart_version`. This is the first record
  in every session — gives support a device fingerprint per session.

**Connectivity listener:**

- Subscribe to `connectivity_plus` stream. On connectivity change, emit
  `info`-level log: `network_changed` with attributes `type`
  (wifi/cellular/none) and `online` (bool). Support needs to know if the
  device was offline *when* the error occurred, not just at flush time.

**Dart crash hooks:**

- Set up `PlatformDispatcher.instance.onError` and
  `FlutterError.onError` in app initialization (before `runApp`)

**`lib/features/settings/telemetry_screen.dart` (new):**

- Enable/disable toggle
- Endpoint field (pre-filled, **read-only in production builds**,
  editable in debug/dev only — DoD exfil prevention)
- Connection status indicator
- No token field needed (backend holds Logfire token)

**`lib/core/router/`:**

- Add route for Telemetry screen

#### Dependencies (App Layer Only)

- `connectivity_plus` — `NetworkStatusChecker` callback + change listener
- `package_info_plus` — `service.version` resource attribute
- `device_info_plus` — `device.model`, `os.version` resource attributes
- `path_provider` — `DiskQueue` file location
- `uuid` — installId + sessionId generation
- `shared_preferences` — persist `installId` across installs

#### Unit Tests

- `test/core/logging/logging_provider_test.dart`:
  - BackendLogSink created when enabled
  - Sink not created when disabled
  - InstallId persisted across app launches (same install)
  - SessionId persists across provider rebuilds (same session)
  - UserId updates when auth state changes
  - Disposed on ref dispose

#### Widget Tests

- `test/features/settings/telemetry_screen_test.dart`:
  - Toggle enables/disables export
  - Connection status reflects sink state
  - Endpoint field read-only in production mode
  - Endpoint field editable in debug mode

#### Integration Tests

- `test/integration/backend_toggle_flow_test.dart` — Toggle backend
  logging off → sink unregistered. Toggle on → re-registered. Verify
  logs stop/start flowing.
- `test/integration/backend_lifecycle_flush_test.dart` — Write records,
  simulate `AppLifecycleState.paused`, verify flush called.

#### Acceptance Criteria

- [ ] `backendLogSinkProvider` creates sink with all injected deps
- [ ] `installId` persisted per-install, included in every payload
- [ ] SessionId generated on startup, injected into every payload
- [ ] UserId from auth state, nullable for pre-auth logs
- [ ] Config toggle enables/disables at runtime
- [ ] Session start marker emitted on startup with device/app attributes
- [ ] Connectivity listener logs `network_changed` events
- [ ] Lifecycle flush on all platforms
- [ ] Dart crash hooks wired before `runApp`
- [ ] Telemetry screen with toggle, endpoint (locked in prod), status
- [ ] `connectivity_plus` integration (flush check + change listener)
- [ ] `LogSanitizer` wired into `LogManager` (all sinks sanitized)
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
- **Server-received timestamp:** stamp each record with
  `server_received_at` from server clock. Persists both client
  `timestamp` and server `server_received_at` as OTel attributes.
  Handles clock skew on DoD devices with manual/incorrect time.
- Map each log to OTel `LogRecord` using Python `opentelemetry-sdk`:
  - `level` → `SeverityNumber`
  - `timestamp` → `observedTimestamp` (client time)
  - `server_received_at` → OTel attribute (server time)
  - `logger` → `InstrumentationScope`
  - `attributes` → OTel attributes (typed correctly by Python SDK)
  - `error`/`stackTrace` → exception semantic conventions
  - `installId`/`sessionId`/`userId` → resource or record attributes
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
- [ ] Server-received timestamp stamped on each record
- [ ] Maps to OTel LogRecords via Python SDK
- [ ] `installId`/`sessionId`/`userId` persisted as attributes
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
- Each breadcrumb includes: timestamp, level, logger, message, **category**
- **Categories** help support filter noise:
  - `ui` — navigation, taps, screen transitions
  - `network` — HTTP requests, connectivity changes
  - `system` — lifecycle events, permission changes
  - `user` — login, logout, explicit user actions
- Category is derived from `loggerName` convention (e.g. `Router.*` → `ui`,
  `Http.*` → `network`) or from an explicit `breadcrumb_category` attribute

#### Acceptance Criteria

- [ ] Crash payloads include last 20 breadcrumb records
- [ ] Breadcrumbs categorized (ui/network/system/user)
- [ ] Breadcrumbs come from existing MemorySink (no duplication)
- [ ] Tests verify breadcrumb attachment and categorization on fatal log

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
- On ERROR/FATAL, capture via `toImage()` → PNG bytes
- **Encode in background isolate** — base64 encoding a retina screenshot
  (5MB+) on the UI thread causes visible jank. Use `compute()` for
  PNG-to-base64 conversion.
- Upload screenshot as separate POST (reference by ID in error log) —
  embedding large base64 in JSON payload bloats the log pipeline
- Thumbnail option: downscale to 480p before encoding (reduces to ~50 KB)

#### Acceptance Criteria

- [ ] Screenshot captured on error
- [ ] PNG-to-base64 runs in background isolate (not UI thread)
- [ ] Image uploaded separately, referenced by ID in error log
- [ ] Does not crash if RepaintBoundary unavailable
- [ ] Does not jank the UI on capture

---

## Observability Gap Analysis

Comprehensive assessment of what this **pragmatic field-support logging
framework** covers after all phases. This is NOT a Crashlytics replacement
— the goal is: support engineer gets a bug report, queries Logfire,
reconstructs what happened.

### Coverage After Phase 1 (Core)

| Capability | Status | Notes |
|------------|--------|-------|
| Structured logging | Covered | LogRecord + attributes |
| Remote log export | Covered | BackendLogSink → Logfire |
| Dart crash capture | Covered | FlutterError + PlatformDispatcher hooks |
| Offline persistence | Covered | DiskQueue (JSONL write-ahead) |
| PII/classified redaction | Covered | LogSanitizer (P0 for DoD) |
| Session correlation | Covered | UUID sessionId + userId |
| Install ID (device Y) | Covered | Per-install UUID for cross-session queries |
| Session start marker | Covered | Device/app fingerprint on startup |
| Connectivity history | Covered | `network_changed` events logged |
| Server-received timestamp | Covered | Backend stamps server time (clock skew) |
| Poison pill protection | Covered | Bad batches discarded after 3 retries |
| Record size guard | Covered | Oversized records truncated at 64 KB |
| In-app log viewer | Covered | MemorySink + existing UI |
| Cross-platform support | Covered | Same endpoint all platforms |
| Lifecycle-aware flush | Covered | paused/hidden/visibilitychange |

### Coverage After Phase 2 (Enhanced Context)

| Capability | Status | Notes |
|------------|--------|-------|
| Categorized breadcrumbs | Covered | Last N logs with ui/network/system/user categories |
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
| Native crash capture (SIGSEGV) | **Out of scope** | Not a Crashlytics replacement. Requires OS-level signal handlers (XL effort). Rely on `adb logcat` / Console.app. Most crashes are Dart-level and captured. |
| Session replay (video) | **Out of scope** | Not a Crashlytics replacement. Screenshot-on-error is the pragmatic substitute. |
| Distributed tracing (spans) | **Deferred** | Phase 1 is log-only. When Python backend adds tracing, can propagate `traceparent` headers from HTTP client and attach trace context to logs. Evaluate `dartastic_opentelemetry` if their SDK matures. |
| Metrics (counters, histograms) | **Deferred** | RUM captures basic timing as log attributes. True OTel metrics (counters, histograms, gauges) can be added when the Python backend supports metrics ingest. |
| Alerting | **Partial** | Error fingerprinting (12.7) enables threshold-based alerts on the backend. Not a Flutter-side concern. |
| Log search / analytics | **Delegated** | Logfire provides SQL-like querying on structured attributes. No Flutter-side work needed. |

### Field Support Readiness Grade: **B+**

**"User X on device Y had issue Z at time T" — can we reconstruct that?**

After all 3 phases: **Yes**, for Dart-level issues. The support engineer
can query Logfire by sessionId, see the session start marker (device,
app version, OS), connectivity history, categorized breadcrumbs leading
up to the error, the full stack trace, and the sanitized attributes.

The solution covers structured logging, Dart crash capture, offline
persistence, PII protection, session correlation, connectivity tracking,
categorized breadcrumbs, remote config, performance metrics, and error
grouping. Out-of-scope items (native crashes, session replay) require
commercial-grade infrastructure that DoD constraints prohibit.

For a DoD Flutter app with self-hosted constraints, this is a
**pragmatic field-support logging framework**.

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
