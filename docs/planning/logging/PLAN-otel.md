# OpenTelemetry Integration - Execution Plan

## How to Use This Plan

Each sub-milestone is a single PR. Work them in order — each depends on the
previous (except 12.9 which can parallelize with 12.6–12.8). A developer or
agent (wiggum) can pick up any pending sub-milestone by reading its section
below, implementing the changes, and checking off the acceptance criteria.

## Resumption Context

- **Branch:** `feat/otel`
- **Base:** `main`
- **Spec:** `docs/planning/logging/12-opentelemetry-integration.md`
- **Logfire:** Account ready, write token available via `LOGFIRE_TOKEN` env var
- **Backend repo:** `~/dev/soliplex` (git worktree for proxy work in 12.8)

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

### Unit Tests

- `test/log_record_test.dart` — attributes stored, default empty, included
  in `toString()`
- `test/logger_test.dart` — attributes passed through to `LogRecord`

### Integration Tests

- `test/integration/attributes_through_sink_test.dart` — Log a message
  with attributes via `Logger`, verify the `LogRecord` captured by
  `MemorySink` carries the attributes intact. Confirms the full path:
  `Logger.info(attributes:) → LogManager → LogSink.write() → LogRecord`

### Acceptance Criteria

- [ ] `LogRecord` has `attributes` field, default `const {}`
- [ ] All `Logger` methods accept optional `attributes`
- [ ] Existing call sites compile without changes
- [ ] Integration: attributes survive Logger → LogManager → sink pipeline
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

## 12.2 — OTLP Mapper

**Status:** Pending (blocked by 12.1)

**Goal:** Pure-function mapper that converts `LogRecord` instances into
OTLP JSON structures. No state, no I/O, no HTTP — just deterministic
data transformation. This is the foundation that all downstream milestones
build on.

### Changes

**`packages/soliplex_logging/lib/src/sinks/otel_mapper.dart` (new):**

- `mapLogRecord(LogRecord, {DateTime? observedTime}) → Map<String, Object>`
  — OTLP JSON mapping. `observedTime` defaults to `DateTime.now()` (set
  by `OtelSink.write()` to capture ingestion time)
- `mapSeverity(LogLevel) → (int severityNumber, String severityText)`
- `mapTimestamp(DateTime) → String` (nanosecond string)
- `mapObservedTimestamp(DateTime) → String` — same format, distinct field
  (`observedTimeUnixNano`) per OTel spec
- `mapAttributes(Map<String, Object>) → List<Map>` (OTel attribute format).
  **Typed `AnyValue` serialization:** preserve Dart types into correct
  OTLP type wrappers:
  - `String` → `{"stringValue": ...}`
  - `int` → `{"intValue": "..."}` (string-encoded int64)
  - `double` → `{"doubleValue": ...}`
  - `bool` → `{"boolValue": ...}`
  - `List` → `{"arrayValue": {"values": [...]}}`
  - `Map<String, Object>` → `{"kvlistValue": {"values": [...]}}`
  - Unknown types → `.toString()` fallback only
  This preserves Logfire's SQL-like attribute querying capability.
- `mapError(Object?, StackTrace?) → List<Map>` (exception semantic
  conventions)
- `buildPayload(List<LogRecord>, Map resourceAttrs) → Map` (full OTLP
  `resourceLogs/scopeLogs` structure)
- `mapFlags(String? traceId) → int` — `0x01` if trace context present
  (sampled), `0x00` otherwise
- Track `droppedAttributesCount` when attribute map exceeds size limits

**`packages/soliplex_logging/lib/soliplex_logging.dart`:**

- Export `otel_mapper.dart`

### Unit Tests

- `test/sinks/otel_mapper_test.dart`:
  - Severity mapping (all 6 levels)
  - Timestamp conversion (microseconds × 1000 → nanosecond string)
  - `observedTimeUnixNano` generation (distinct from `timeUnixNano`)
  - `flags` field (`0x01` when traceId present, `0x00` when null)
  - `droppedAttributesCount` (truncation when attributes exceed limit)
  - Typed `AnyValue` attribute encoding:
    - `String` → `stringValue`
    - `int` → `intValue` (string-encoded)
    - `double` → `doubleValue`
    - `bool` → `boolValue`
    - `List` → `arrayValue` (recursive)
    - `Map<String, Object>` → `kvlistValue` (recursive)
    - Unknown types → `.toString()` fallback
  - Error conventions (`exception.type`, `exception.message`,
    `exception.stacktrace`)
  - Scope grouping (records grouped by `loggerName`)
  - `buildPayload` produces valid `resourceLogs/scopeLogs` structure
  - Null `traceId`/`spanId` omitted from output

### Acceptance Criteria

- [ ] OTLP JSON matches OTel spec (field names, types, nesting)
- [ ] Mapper uses typed `AnyValue` wrappers — preserves `String`, `int`,
  `double`, `bool`, `List`, `Map` into correct OTLP type keys. Falls back
  to `.toString()` only for unknown types
- [ ] Mapper emits `observedTimeUnixNano` (distinct from `timeUnixNano`)
- [ ] Mapper emits `flags` field from trace context
- [ ] Mapper tracks `droppedAttributesCount` when attributes truncated
- [ ] `buildPayload` groups records by scope (logger name)
- [ ] Null `traceId`/`spanId` omitted (not empty strings)
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

## 12.3 — Exporter Transport

**Status:** Pending (blocked by 12.2)

**Goal:** Define the `OtelExporter` interface and implement two transports:
`LogfireExporter` (direct OTLP/HTTP) and `ProxyExporter` (backend proxy).
Exporters handle HTTP, auth, and gzip — no batching or retry logic.

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
- Constructor takes `endpoint` (URL), `authToken` (raw write token),
  optional `http.Client` (defaults to `http.Client()` — allows app
  to inject platform-native client from `soliplex_client_native`),
  and optional `bool compress` (default `true`)
- POST to endpoint with `Content-Type: application/json` and raw token
  in `Authorization` header
- When `compress` is true, gzip the request body and set
  `Content-Encoding: gzip` header (reduces payload size significantly
  on mobile — battery/data savings)
- Maps HTTP status to `ExportResult`:
  - 200 → `success`
  - 413/429/5xx → `retryable` (413: sink splits batch in half and retries)
  - 401/403 → `fatal`

**`packages/soliplex_logging/lib/src/sinks/proxy_exporter.dart` (new):**

- Implements `OtelExporter`
- Constructor takes `endpoint` (relative URL), `sessionToken` (JWT),
  optional `http.Client`, and optional `bool compress` (default `true`)
- POST to endpoint with `Authorization: Bearer <jwt>`
- When `compress` is true, gzip the request body and set
  `Content-Encoding: gzip` header
- Same HTTP status → `ExportResult` mapping as `LogfireExporter`
- Token can be updated at runtime (session refresh) via setter

**`packages/soliplex_logging/pubspec.yaml`:**

- Add `http: ^1.2.0` (pure Dart — the only new dependency)

**`packages/soliplex_logging/lib/soliplex_logging.dart`:**

- Export `otel_exporter.dart`, `logfire_exporter.dart`,
  `proxy_exporter.dart`

### Layering Note

All code in 12.3 is **pure Dart**. No Flutter imports. Platform concerns
are injected via constructor arguments:

- `http.Client?` on exporters — app injects native client

### Unit Tests

- `test/sinks/logfire_exporter_test.dart` — HTTP status mapping, auth
  header format (raw token, no "Bearer"), Content-Type header, gzip
  compression (Content-Encoding header set, body is valid gzip),
  uncompressed mode when `compress: false`
- `test/sinks/proxy_exporter_test.dart` — HTTP status mapping, Bearer
  auth, token refresh via setter, gzip compression
- Use a mock HTTP client for all exporter tests

### Acceptance Criteria

- [ ] `OtelExporter` interface defined with `export()` and `shutdown()`
- [ ] `LogfireExporter` sends raw token, maps HTTP status correctly
- [ ] `ProxyExporter` sends Bearer JWT, supports token refresh
- [ ] Exporters send `Content-Encoding: gzip` compressed payloads
- [ ] Uncompressed mode works when `compress: false`
- [ ] `http` dependency added to `soliplex_logging/pubspec.yaml`
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

## 12.4 — OtelSink Batching Core

**Status:** Pending (blocked by 12.3)

**Goal:** Implement `OtelSink` as a `LogSink` with queue management,
batch processing, and flush triggers. Uses `OtelMapper` for payload
building and delegates to `OtelExporter` for transport. No retry or
circuit breaker logic — that comes in 12.5.

### Changes

**`packages/soliplex_logging/lib/src/sinks/otel_sink.dart` (new):**

- Implements `LogSink`
- Constructor takes `OtelExporter`, `resourceAttributes` (Map),
  optional `batchSize` (default 256), `flushInterval` (default 30s),
  `maxQueueSize` (default 1024)
- `write()` — enqueues record (capturing `observedTime` via
  `DateTime.now()`); triggers immediate flush on ERROR/FATAL
- `flush()` — builds OTLP payload via `OtelMapper`, calls
  `exporter.export()`
- `close()` — drains remaining queue, cancels timer, calls
  `exporter.shutdown()`

**Batch processor (inside `OtelSink`):**

- Timer-based flush every `flushInterval`
- Size-based flush when queue reaches `batchSize`
- Severity-triggered flush: immediate on ERROR/FATAL
- Queue capped at `maxQueueSize`; oldest TRACE/DEBUG dropped first.
  If queue is entirely ERROR/FATAL, drop oldest ERROR (never block writes)
- **Concurrent flush guard:** If an export is in-flight when a timer or
  severity trigger fires, skip the duplicate flush (do not queue a second
  concurrent HTTP request)

**`packages/soliplex_logging/lib/soliplex_logging.dart`:**

- Export `otel_sink.dart`

### Unit Tests

- `test/sinks/otel_sink_test.dart`:
  - Timer-based flush (advance fake timer past `flushInterval`)
  - Size-based flush (write `batchSize` records → flush triggered)
  - Severity-triggered flush (ERROR/FATAL → immediate flush)
  - Queue overflow: drop TRACE/DEBUG first; if all ERROR/FATAL, drop
    oldest ERROR
  - Concurrent flush guard (second trigger while export in-flight → skip)
  - `close()` drains remaining queue
  - Payload passed to exporter matches `OtelMapper.buildPayload` output
  - Uses a fake/mock `OtelExporter` (always returns `success`)

### Integration Tests

- `test/integration/otel_pipeline_test.dart` — End-to-end pipeline:
  `Logger.info()` → `LogManager` → `OtelSink` → mock `OtelExporter`.
  Verify the exporter receives a valid OTLP JSON payload with correct
  severity, timestamp, scope, body, and attributes.
- `test/integration/otel_batch_flush_test.dart` — Write N records below
  batch size, advance fake timer past `flushInterval`, verify exporter
  called exactly once with N records.
- `test/integration/otel_severity_flush_test.dart` — Write an ERROR
  record, verify exporter called immediately (no timer wait).
- `test/integration/otel_close_drain_test.dart` — Write records, call
  `close()`, verify all buffered records exported before shutdown
  completes.

### Acceptance Criteria

- [ ] `OtelSink` implements `LogSink` (`write`, `flush`, `close`)
- [ ] Batch processor respects size, timer, and severity triggers
- [ ] Queue overflow drops TRACE/DEBUG first; if all ERROR/FATAL, drops
  oldest ERROR (never blocks writes)
- [ ] Concurrent flush guard prevents overlapping in-flight exports
- [ ] `close()` drains remaining queue and calls `exporter.shutdown()`
- [ ] Integration: full pipeline Logger → OtelSink → exporter produces
  valid OTLP
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

## 12.5 — Reliability Layer

**Status:** Pending (blocked by 12.4)

**Goal:** Add retry, circuit breaker, and network awareness to `OtelSink`.
This milestone makes the sink production-ready for unreliable networks.

### Changes

**`packages/soliplex_logging/lib/src/sinks/otel_sink.dart` (modify):**

- Add `networkChecker` (`NetworkStatusChecker?`) constructor parameter.
  When provided and returns false, skip export attempt and keep records
  buffered
- Retry with exponential backoff + jitter (1s, 2s, 4s, max 32s) on
  `ExportResult.retryable`
- On 413 (`retryable` from oversized batch): split batch in half and
  retry each half
- **Circuit breaker:** After N consecutive `fatal` results (e.g. 3),
  disable export entirely. Surface disabled state via `onError` callback
- **No re-entrant logging:** `OtelSink` must NEVER generate log records
  about its own failures that re-enter the logging pipeline — use a
  separate diagnostic `onError` callback or `stderr` only
- Disables export on `ExportResult.fatal` (surfaces error via callback)

**`packages/soliplex_logging/lib/src/sinks/otel_exporter.dart` (modify):**

- Add `NetworkStatusChecker` typedef (if not already exported)

### Unit Tests

- `test/sinks/otel_sink_reliability_test.dart`:
  - Retry on `retryable` with exponential backoff timing
  - 413 split: batch split in half, both halves exported
  - Circuit breaker: N consecutive `fatal` → export disabled, `onError`
    fired
  - `networkChecker` returns false → export skipped, records buffered
  - `networkChecker` returns true → normal export
  - No re-entrant logging: verify `OtelSink` does not call
    `LogManager.emit()` or `Logger` on failure

### Integration Tests

- `test/integration/otel_circuit_breaker_test.dart` — Configure exporter
  to return `fatal` N times. Verify OtelSink disables export, fires
  `onError` callback, and does NOT generate log records about the failure
  (no re-entrant logging).
- `test/integration/otel_retry_split_test.dart` — Configure exporter to
  return `retryable` on first call (simulating 413), verify sink splits
  batch and retries with smaller payload.
- `test/integration/otel_offline_skip_test.dart` — Mock
  `networkChecker` to return false. Write records. Verify exporter
  is NOT called. Mock back online, trigger flush, verify exporter
  receives records.

### Acceptance Criteria

- [ ] Retry with exponential backoff + jitter on `retryable`
- [ ] 413 triggers batch split in half and retry
- [ ] Circuit breaker disables export after N consecutive fatals
- [ ] `onError` callback fires when circuit breaker trips
- [ ] `networkChecker` skips export when offline, buffers records
- [ ] OtelSink never generates log records about its own failures (no
  re-entrant logging — diagnostic errors go to `onError` callback or
  `stderr` only)
- [ ] Integration: circuit breaker disables without re-entrant logging
- [ ] Integration: retry splits batch on 413
- [ ] Integration: offline → skip export, online → resume
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass, coverage 85%+

---

## 12.6 — App Wiring (Native)

**Status:** Pending (blocked by 12.5)

**Goal:** Wire `OtelSink` + `LogfireExporter` into the Flutter app via
Riverpod providers. Build resource attributes, integrate connectivity,
and add lifecycle flush. **No UI in this milestone** — Telemetry screen
comes in 12.7. Web is OTel-disabled until 12.8.

### Changes

**`lib/core/logging/log_config.dart`:**

- Add `otelEnabled` (bool, default false)
- Add `otelEndpoint` (String, default Logfire URL)
- Token is NOT in `LogConfig` — lives in `flutter_secure_storage` only

**`lib/core/logging/logging_provider.dart` (token provider):**

- Add `otelTokenProvider` — `FutureProvider<String?>` that reads the
  Logfire write token from `flutter_secure_storage`.

  ```dart
  final otelTokenProvider = FutureProvider<String?>((ref) async {
    final storage = ref.read(secureStorageProvider);
    return storage.read(key: 'logfire_write_token');
  });
  ```

**`lib/core/logging/logging_provider.dart` (exporter + sink):**

- Add `otelExporterProvider` — creates `LogfireExporter` with endpoint
  from config, token from `otelTokenProvider`, and injected
  `http.Client` from existing platform client provider. All platforms
  use `LogfireExporter` in this milestone.

  ```dart
  final exporter = LogfireExporter(
    endpoint: config.otelEndpoint,
    authToken: token,       // from otelTokenProvider
    client: httpClient,     // from platform client provider
  );
  ```

- Add `otelSinkProvider` — creates `OtelSink` with the exporter,
  resource attributes (built from `package_info_plus` +
  `device_info_plus`), and connectivity checker (from
  `connectivity_plus`). Registers with LogManager,
  `ref.onDispose → close`.

  ```dart
  final sink = OtelSink(
    exporter: exporter,
    resourceAttributes: resourceMap,  // built in app layer
    networkChecker: () => connectivityState != ConnectivityResult.none,
  );
  ```

- Sink disabled when `otelEnabled` is false or token is empty

**`lib/core/logging/logging_provider.dart` (config controller):**

- React to `otelEnabled` changes: register/unregister `OtelSink`
- React to token changes (provider invalidation): recreate exporter

**Lifecycle flush:**

- **Mobile:** `AppLifecycleListener` calls `OtelSink.flush()` on
  `AppLifecycleState.paused`
- **Desktop:** `AppLifecycleListener` calls `OtelSink.flush()` on
  `AppLifecycleState.hidden` (desktop does not reliably emit `paused`).
  Also flush on `AppLifecycleState.detached` as a final-chance drain.

**Resource attributes:**

- Build resource map at startup: `service.name`, `service.version` (from
  `package_info_plus`), `deployment.environment` (build-time constant via
  `--dart-define`), `os.name`, `os.version` (platform detection),
  `device.model` (from `device_info_plus`)

### Dependencies (App Layer Only)

These are Flutter plugins added to `pubspec.yaml` (root app), NOT to
`soliplex_logging`. They are injected into pure Dart components via
constructor arguments.

- `connectivity_plus` — provides `NetworkStatusChecker` callback to
  `OtelSink`. **Note:** requires `WidgetsFlutterBinding` to be
  initialized before use. Existing provider pattern initializes lazily
  which is safe, but integration tests must call
  `WidgetsFlutterBinding.ensureInitialized()` explicitly.
- `package_info_plus` — provides `service.version` for resource
  attributes map
- `device_info_plus` — provides `device.model`, `os.version` for
  resource attributes map
- `flutter_secure_storage` — already in pubspec.yaml, provides token
  storage

### Unit Tests

- `test/core/logging/logging_provider_test.dart`:
  - OtelSink created with `LogfireExporter` when enabled + token present
  - Sink not created when disabled or token empty
  - Token change triggers exporter recreation
  - Disposed on ref dispose
- `test/core/logging/log_config_test.dart` — new fields serialize/
  deserialize correctly (token NOT in config)

### Integration Tests

- `test/integration/otel_token_flow_test.dart` — Write token to secure
  storage → `otelTokenProvider` invalidated → `otelExporterProvider`
  recreates `LogfireExporter` with new token → `OtelSink` begins
  exporting. Verify full provider chain reacts to token change.
- `test/integration/otel_toggle_flow_test.dart` — Toggle `otelEnabled`
  false → `OtelSink` unregistered from `LogManager`. Toggle back on →
  sink re-registered. Verify logs stop/start flowing to exporter.
- `test/integration/otel_lifecycle_flush_test.dart` — Write records to
  `OtelSink`, simulate `AppLifecycleState.paused` (mobile) and
  `AppLifecycleState.hidden` (desktop), verify `flush()` called and
  exporter receives buffered records.
- `test/integration/otel_logfire_roundtrip_test.dart` — **Manual/CI
  gated:** Full round-trip to Logfire staging endpoint using real
  `LOGFIRE_TOKEN` from env. Log records at each severity level with
  attributes. Verify HTTP 200 response. This test is skipped by default
  (requires `LOGFIRE_TOKEN` env var) and runs in CI with the token
  configured as a secret.

### Acceptance Criteria

- [ ] `otelTokenProvider` reads token from `flutter_secure_storage` (async)
- [ ] Token is NOT in `LogConfig` or `SharedPreferences`
- [ ] `otelExporterProvider` creates `LogfireExporter` (native platforms)
- [ ] `otelSinkProvider` creates `OtelSink`, disabled when no token or web
- [ ] Token change → provider invalidation → exporter recreated
- [ ] Config toggle enables/disables OTel export at runtime
- [ ] Lifecycle flush: `paused` on mobile, `hidden`/`detached` on desktop
- [ ] Web: OTel disabled (no sink created)
- [ ] Resource attributes populated from device info
- [ ] `connectivity_plus` added, export skipped when offline
- [ ] Integration: token write → provider chain → export starts
- [ ] Integration: toggle off → export stops, toggle on → export resumes
- [ ] Integration: lifecycle event → flush → exporter called
- [ ] Integration (CI-gated): round-trip to Logfire staging returns 200
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

## 12.7 — Telemetry Screen UI

**Status:** Pending (blocked by 12.6)

**Goal:** Add a dedicated Telemetry settings screen for configuring OTel
export. Uses the providers from 12.6 — no new backend logic.

### Changes

**`lib/features/settings/telemetry_screen.dart` (new):**

Dedicated screen accessible from Settings navigation. Keeps telemetry
config separate from general app settings.

- **Enable/disable toggle** — controls `otelEnabled` in `LogConfig`
- **Logfire token field** — `TextField` (obscured) where user pastes
  their write token. Saved to `flutter_secure_storage` on submit.
  Shows checkmark when token is stored, empty state when not.
- **Endpoint field** — pre-filled with Logfire URL, editable for
  custom collectors
- **Connection status** — indicator showing whether export is active,
  disabled, or failed (from circuit breaker state)
- **Web (12.7):** Token field and toggle hidden. Shows "OTel export
  requires backend proxy (coming in 12.8)" message. Web export is
  enabled when `ProxyExporter` ships.
- Token is written to `flutter_secure_storage` and `otelTokenProvider`
  is invalidated → exporter recreated → export starts

**`lib/core/router/`:**

- Add route for Telemetry screen (linked from Settings)

### Widget Tests

- `test/features/settings/telemetry_screen_test.dart`:
  - Token saved to secure storage on submit
  - Toggle enables/disables export
  - Connection status reflects sink state (active/disabled/failed)
  - Endpoint field pre-filled with default, editable
  - Empty token shows empty state, stored token shows checkmark
  - Web shows proxy-required message, hides token field

### Integration Tests

- `test/integration/otel_screen_token_test.dart` — Enter token on
  Telemetry screen → token written to secure storage →
  `otelTokenProvider` invalidated → `otelExporterProvider` recreates
  `LogfireExporter` with new token → `OtelSink` begins exporting.
  Verify full UI → provider chain → export flow.
- `test/integration/otel_screen_toggle_test.dart` — Toggle OTel off on
  Telemetry screen → `otelEnabled` set to false in `LogConfig` →
  `OtelSink` unregistered from `LogManager`. Toggle back on → sink
  re-registered. Verify UI toggle drives export state.

### Acceptance Criteria

- [ ] Telemetry screen allows entering Logfire token (stored in secure
  storage)
- [ ] Telemetry screen has enable/disable toggle, endpoint field, and
  connection status indicator
- [ ] Telemetry screen routed from Settings
- [ ] Web: Telemetry screen shows proxy-required message
- [ ] Integration: UI token entry → provider chain → export starts
- [ ] Integration: UI toggle → export stops/resumes
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

## 12.8 — Web Proxy (Swap Exporter)

**Status:** Pending (blocked by 12.7)

**Goal:** Add backend proxy and swap web to `ProxyExporter`. Native
continues using `LogfireExporter`. The token no longer needs to be on
the web client in production — the proxy holds it server-side.

### Backend (~/dev/soliplex, git worktree)

**`POST /api/v1/telemetry/logs`:**

- Validate session JWT from `Authorization: Bearer <jwt>` header
- Forward request body (OTLP JSON) to
  `https://logfire-us.pydantic.dev/v1/logs`
- Attach Logfire write token from server config (env var)
- Return upstream status code to client
- Rate limit: per-user/per-session caps
- Reject payloads > 1 MB (413)

### Flutter Changes

**`lib/core/logging/logging_provider.dart`:**

- Update `otelExporterProvider` to select exporter by platform:

  ```dart
  final exporter = kIsWeb
      ? ProxyExporter(
          endpoint: '/api/v1/telemetry/logs',
          sessionToken: sessionJwt,
        )
      : LogfireExporter(
          endpoint: config.otelEndpoint,
          authToken: token,
        );
  ```

- `OtelSink` constructor unchanged — only the exporter differs

**Telemetry screen (web):**

- Replace "requires backend proxy" message with enable/disable toggle
- Hide token field on web (not needed — proxy holds token)
- Keep endpoint field

**Token handling (web):**

- No Logfire token on web client in production
- `ProxyExporter` uses session JWT from existing auth state

**Web lifecycle flush:**

- `visibilitychange` listener calls `flush()` when
  `document.hidden == true`
- `beforeunload` is best-effort only — accept up to 30s of log loss on
  abrupt tab close (`sendBeacon` cannot set auth headers; not worth
  adding nonce complexity)

### Unit Tests

**Backend:**

- Proxy forwards OTLP payload correctly
- Rejects unauthenticated requests (401)
- Enforces rate limits (429)
- Rejects oversized payloads (413)

**Flutter:**

- Web provider creates `ProxyExporter` with relative endpoint
- Native provider creates `LogfireExporter` with Logfire URL
- `OtelSink` works identically with either exporter

### Widget Tests

- Telemetry screen hides token field on web
- Telemetry screen still shows toggle and endpoint on web

### Integration Tests

- `test/integration/otel_proxy_exporter_test.dart` — On web, verify
  `otelExporterProvider` creates `ProxyExporter` with relative endpoint
  and session JWT. On native, verify `LogfireExporter` with Logfire URL
  and write token. Write records through `OtelSink`, verify mock
  exporter receives identical OTLP payloads regardless of exporter type.
- `test/integration/otel_proxy_session_refresh_test.dart` — Simulate
  session JWT refresh. Verify `ProxyExporter.sessionToken` setter
  updates the token. Next export uses new JWT in `Authorization` header.
- **Backend integration (CI-gated):** Deploy proxy to staging. Send OTLP
  JSON via `ProxyExporter` with valid session JWT. Verify HTTP 200 and
  logs appear in Logfire staging.

### Acceptance Criteria

- [ ] Backend proxy forwards OTLP, attaches token, validates session
- [ ] `otelExporterProvider` selects `ProxyExporter` on web,
  `LogfireExporter` on native
- [ ] `OtelSink` unchanged — only the exporter differs
- [ ] Telemetry screen hides token field on web
- [ ] Web clients no longer store the Logfire write token
- [ ] Web lifecycle flush via `visibilitychange`
- [ ] Integration: same OTLP payload produced regardless of exporter
- [ ] Integration: session JWT refresh propagates to ProxyExporter
- [ ] Integration (CI-gated): round-trip through proxy to Logfire staging
- [ ] `dart analyze` — 0 issues
- [ ] Tests pass

---

## 12.9 — Hardening

**Status:** Pending (blocked by 12.5, can parallelize with 12.6–12.8)

**Goal:** Production-harden OTel export with PII protection, sampling,
and backpressure observability. All code is pure Dart — no Flutter
dependency, so this can be developed in parallel with app integration
milestones.

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
| 12.2 OTLP mapper | Pending | — |
| 12.3 Exporter transport | Pending | — |
| 12.4 OtelSink batching core | Pending | — |
| 12.5 Reliability layer | Pending | — |
| 12.6 App wiring (native) | Pending | — |
| 12.7 Telemetry screen UI | Pending | — |
| 12.8 Web proxy (swap exporter) | Pending | — |
| 12.9 Hardening | Deferred | — |
