# OpenTelemetry Integration - Execution Plan

## How to Use This Plan

Each sub-milestone is a single PR. Work them in order — each depends on the
previous. A developer or agent (wiggum) can pick up any pending sub-milestone
by reading its section below, implementing the changes, and checking off the
acceptance criteria.

## Resumption Context

- **Branch:** `feat/otel`
- **Base:** `main`
- **Spec:** `docs/planning/logging/12-opentelemetry-integration.md`
- **Logfire:** Account ready, write token available via `LOGFIRE_TOKEN` env var
- **Backend repo:** `~/dev/soliplex` (git worktree for proxy work in 12.4)

---

## 12.1 — LogRecord Attributes

**Status:** Pending

**Goal:** Add structured attributes to `LogRecord` so OTel export can carry
contextual key-value pairs (e.g. `user_id`, `http_status`, `view_name`).

### Changes

**`packages/soliplex_logging/lib/src/log_record.dart`:**

- Add `final Map<String, Object> attributes` field with default `const {}`
- Non-breaking: existing constructor call sites compile unchanged

**`packages/soliplex_logging/lib/src/logger.dart`:**

- Add optional `Map<String, Object>? attributes` parameter to `info()`,
  `debug()`, `warning()`, `error()`, `fatal()`, `trace()`
- Pass through to `LogRecord` constructor

**`packages/soliplex_logging/lib/src/log_record.dart` (toString):**

- Include non-empty attributes in `toString()` output for debug visibility

### Tests

- `test/log_record_test.dart` — attributes stored, default empty, included
  in `toString()`
- `test/logger_test.dart` — attributes passed through to `LogRecord`

### Acceptance Criteria

- [ ] `LogRecord` has `attributes` field, default `const {}`
- [ ] All `Logger` methods accept optional `attributes`
- [ ] Existing call sites compile without changes
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

## 12.2 — OtelSink Core

**Status:** Pending (blocked by 12.1)

**Goal:** Implement `OtelSink` with a pluggable `OtelExporter` interface.
The sink owns batching and queuing; exporters own transport.

### Architecture

```text
OtelSink (LogSink)
├── Batch Processor (queue, timer, severity flush)
├── OtelMapper (LogRecord → OTLP JSON)
└── OtelExporter (pluggable transport)
      ├── LogfireExporter  — direct OTLP/HTTP to Logfire
      └── ProxyExporter    — routes through backend proxy
```

### Changes

**`packages/soliplex_logging/lib/src/sinks/otel_exporter.dart` (new):**

```dart
/// Result of an export attempt.
enum ExportResult { success, retryable, fatal }

/// Pluggable transport for OTLP log payloads.
///
/// Implementations handle authentication, endpoint routing, and HTTP
/// concerns. The [OtelSink] calls [export] with pre-built OTLP JSON
/// payloads and handles retry/backoff based on the [ExportResult].
abstract interface class OtelExporter {
  /// Exports a batch of OTLP JSON (the full `resourceLogs` payload).
  Future<ExportResult> export(Map<String, Object> payload);

  /// Releases any resources held by this exporter.
  Future<void> shutdown();
}
```

**`packages/soliplex_logging/lib/src/sinks/logfire_exporter.dart` (new):**

- Implements `OtelExporter`
- Constructor takes `endpoint` (URL) and `authToken` (raw write token)
- POST to endpoint with `Content-Type: application/json` and raw token
  in `Authorization` header
- Maps HTTP status to `ExportResult`:
  - 200 → `success`
  - 429/5xx → `retryable`
  - 401/403/413 → `fatal`

**`packages/soliplex_logging/lib/src/sinks/proxy_exporter.dart` (new):**

- Implements `OtelExporter`
- Constructor takes `endpoint` (relative URL) and `sessionToken` (JWT)
- POST to endpoint with `Authorization: Bearer <jwt>`
- Same HTTP status → `ExportResult` mapping as `LogfireExporter`
- Token can be updated at runtime (session refresh) via setter

**`packages/soliplex_logging/lib/src/sinks/otel_sink.dart` (new):**

- Implements `LogSink`
- Constructor takes `OtelExporter`, `resourceAttributes` (Map),
  optional `batchSize` (default 256), `flushInterval` (default 30s),
  `maxQueueSize` (default 1024)
- `write()` — enqueues record; triggers immediate export on ERROR/FATAL
- `flush()` — builds OTLP payload via mapper, calls `exporter.export()`
- `close()` — drains remaining queue, cancels timer, calls
  `exporter.shutdown()`
- Retry with exponential backoff + jitter (1s, 2s, 4s, max 32s) on
  `ExportResult.retryable`
- Disables export on `ExportResult.fatal` (surfaces error via callback)

**`packages/soliplex_logging/lib/src/sinks/otel_mapper.dart` (new):**

- `mapLogRecord(LogRecord) → Map<String, Object>` — OTLP JSON mapping
- `mapSeverity(LogLevel) → (int severityNumber, String severityText)`
- `mapTimestamp(DateTime) → String` (nanosecond string)
- `mapAttributes(Map<String, Object>) → List<Map>` (OTel attribute format)
- `mapError(Object?, StackTrace?) → List<Map>` (exception semantic
  conventions)
- `buildPayload(List<LogRecord>, Map resourceAttrs) → Map` (full OTLP
  `resourceLogs/scopeLogs` structure)

**Batch processor (inside `OtelSink`):**

- Timer-based flush every `flushInterval`
- Size-based flush when queue reaches `batchSize`
- Severity-triggered flush: immediate on ERROR/FATAL
- Queue capped at `maxQueueSize`; oldest TRACE/DEBUG dropped first

**`packages/soliplex_logging/lib/soliplex_logging.dart`:**

- Export `otel_sink.dart`, `otel_exporter.dart`, `logfire_exporter.dart`,
  `proxy_exporter.dart`, and `otel_mapper.dart`

### Tests

- `test/sinks/otel_mapper_test.dart` — severity mapping, timestamp
  conversion, attribute encoding, error conventions, scope grouping
- `test/sinks/otel_sink_test.dart` — timer flush, size flush, severity
  flush, queue overflow/drop policy, close() drain, retry on retryable,
  disable on fatal
- `test/sinks/logfire_exporter_test.dart` — HTTP status mapping, auth
  header format
- `test/sinks/proxy_exporter_test.dart` — HTTP status mapping, Bearer
  auth, token refresh
- Use a mock HTTP client for all exporter tests

### Acceptance Criteria

- [ ] `OtelExporter` interface defined with `export()` and `shutdown()`
- [ ] `LogfireExporter` sends raw token, maps HTTP status correctly
- [ ] `ProxyExporter` sends Bearer JWT, supports token refresh
- [ ] OTLP JSON matches OTel spec (field names, types, nesting)
- [ ] `OtelSink` retries on `retryable`, disables on `fatal`
- [ ] Batch processor respects size, timer, and severity triggers
- [ ] Queue overflow drops TRACE/DEBUG first, never ERROR/FATAL
- [ ] `close()` drains remaining queue
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

## 12.3 — App Integration (All Platforms)

**Status:** Pending (blocked by 12.2)

**Goal:** Wire `OtelSink` into the app with platform-aware exporter
selection from day one. Web is a first-class citizen — both
`LogfireExporter` (native) and `ProxyExporter` (web) ship together.

### 12.3a — Backend Proxy Endpoint (~/dev/soliplex, git worktree)

This can be worked in parallel with 12.3b since the contract is defined
in 12.2 (`OtelExporter` interface + `ProxyExporter`).

**`POST /api/v1/telemetry/logs`:**

- Validate session JWT from `Authorization: Bearer <jwt>` header
- Forward request body (OTLP JSON) to
  `https://logfire-us.pydantic.dev/v1/logs`
- Attach Logfire write token from server config (env var)
- Return upstream status code to client
- Rate limit: per-user/per-session caps
- Reject payloads > 1 MB (413)

**Tests (backend):**

- Proxy forwards OTLP payload correctly
- Rejects unauthenticated requests (401)
- Enforces rate limits (429)
- Rejects oversized payloads (413)

### 12.3b — Flutter Integration

**`lib/core/logging/log_config.dart`:**

- Add `otelEnabled` (bool, default false)
- Add `otelEndpoint` (String, default Logfire URL)
- Add `otelAuthToken` (String, default empty)

**`lib/core/logging/logging_provider.dart`:**

- Add `otelExporterProvider` — selects exporter by platform:

  ```dart
  final exporter = kIsWeb
      ? ProxyExporter(
          endpoint: '/api/v1/telemetry/logs',
          sessionToken: sessionJwt,
        )
      : LogfireExporter(
          endpoint: 'https://logfire-us.pydantic.dev/v1/logs',
          authToken: logfireToken,
        );
  ```

- Add `otelSinkProvider` — creates `OtelSink` with the exporter from
  `otelExporterProvider`, registers with LogManager,
  `ref.onDispose → close`
- Sink disabled when `otelEnabled` is false
- `OtelSink` is platform-agnostic — only the exporter differs

**`lib/core/logging/logging_provider.dart` (config controller):**

- React to `otelEnabled` changes: register/unregister `OtelSink`

**Lifecycle flush (platform-aware):**

- **Mobile/Desktop:** `AppLifecycleListener` calls `OtelSink.flush()`
  on `AppLifecycleState.paused`
- **Web:** `visibilitychange` listener calls `flush()` when
  `document.hidden == true`. Best-effort `beforeunload` flush
  (accept potential log loss on abrupt tab close)

**Token handling (platform-aware):**

- **Mobile/Desktop:** Read `otelAuthToken` from `flutter_secure_storage`
  at startup. Never persist in SharedPreferences or log output.
- **Web:** No Logfire token on client — proxy holds it server-side.
  `ProxyExporter` uses session JWT, refreshed via setter on token
  rotation.

**Resource attributes:**

- Build resource map at startup: `service.name`, `service.version` (from
  `package_info_plus`), `deployment.environment`, `os.name`

### Dependencies

- `connectivity_plus` — add to `pubspec.yaml` for network awareness
  before export attempts

### Tests (Flutter)

- `test/core/logging/logging_provider_test.dart`:
  - Web: `ProxyExporter` selected, uses relative endpoint
  - Native: `LogfireExporter` selected, uses Logfire URL
  - OtelSink created when enabled, not created when disabled
  - Disposed on ref dispose
- `test/core/logging/log_config_test.dart` — new fields serialize/
  deserialize correctly
- Lifecycle: `visibilitychange` (web) and `paused` (native) trigger flush

### Acceptance Criteria

- [ ] `otelExporterProvider` selects `ProxyExporter` on web,
  `LogfireExporter` on native
- [ ] `otelSinkProvider` creates `OtelSink` with platform exporter
- [ ] `OtelSink` is platform-agnostic — no `kIsWeb` inside sink
- [ ] Config toggle enables/disables OTel export at runtime
- [ ] Token: secure storage on native, server-side on web
- [ ] Lifecycle flush: `paused` on native, `visibilitychange` on web
- [ ] Resource attributes populated from device info
- [ ] `connectivity_plus` added, export skipped when offline
- [ ] Backend proxy forwards OTLP, attaches token, validates session
- [ ] Web clients never receive/store the Logfire write token
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

## 12.4 — Hardening (Deferred)

**Status:** Pending (blocked by 12.3)

**Goal:** Production-harden OTel export with PII protection, sampling,
and backpressure observability.

### Scope

- **PII redaction:** Attribute allowlist, message scrubbing (regex for
  emails, tokens, IPs), stack trace path trimming
- **Sampling:** Level-based (always export ERROR/FATAL, configurable rate
  for DEBUG/TRACE), per-logger rate caps, burst limits
- **Backpressure observability:** Track `otel.logs.dropped_count`, surface
  sustained drop rates in debug indicator
- **Drop policy:** Severity-aware — drop TRACE/DEBUG first, never
  ERROR/FATAL

### Acceptance Criteria

- [ ] No PII in exported attributes (redaction tests pass)
- [ ] Sampling rates configurable per-level and per-logger
- [ ] Drop counter tracks and reports lost records
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

## Progress Tracker

| Sub-Milestone | Status | PR |
|---------------|--------|----|
| 12.1 LogRecord attributes | Pending | — |
| 12.2 OtelSink core | Pending | — |
| 12.3 App integration (all platforms) | Pending | — |
| 12.4 Hardening | Deferred | — |
