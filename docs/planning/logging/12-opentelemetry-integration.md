# Milestone 12: OpenTelemetry Integration (Logfire)

## Goal

Export structured logs from `soliplex_logging` to Logfire (Pydantic) via a
backend relay. Flutter POSTs simple JSON to the Soliplex Python backend,
which uses the mature Python OTel SDK to forward logs as OTLP.

## Status: Pivoting to Option B (Backend Relay)

The spike validated OTLP/HTTP JSON delivery to Logfire. Architectural review
determined that building a full OTel client in Dart (mapper, exporters, batch
processor, retry, circuit breaker) is not justified for log-only export. The
Python OTel SDK is mature and handles all OTLP complexity server-side.

**Constraint:** DoD environment — no commercial SaaS (Sentry, Crashlytics,
Datadog). Self-hosted/open-source only. Logfire (Pydantic) is approved.

## Context

### Current Architecture Readiness

The `soliplex_logging` package is well-positioned for OTel:

- **LogRecord** already carries `spanId` and `traceId` fields
- **LogSink** interface (`write`, `flush`, `close`) maps directly to OTel's
  batch-process-export lifecycle
- **LogManager** isolates sink failures (try/catch around `write()`)
- **Riverpod providers** handle sink lifecycle (create, register, dispose)
- **LogLevel** maps cleanly to OTel SeverityNumber

### dartastic_opentelemetry Assessment

| Signal | Status | Notes |
|--------|--------|-------|
| Tracing | Working | Full OTLP/gRPC and OTLP/HTTP export |
| Metrics | Working | Seven instrument types, OTLP export |
| **Logs** | **Not implemented** | API interfaces exist, proto stubs generated, but no SDK-level LogRecordProcessor or LogRecordExporter |

The proto stubs for `collector/logs/v1` are present in the package. The bridge
from `Logger.emit()` to OTLP export is not wired up.

**Risk factors:** Single maintainer, <1 year old, CNCF donation pending.

### Logfire Target

Logfire (Pydantic) accepts standard OTLP. Endpoint format:

```text
https://logfire-us.pydantic.dev/v1/logs
```

Authentication via static OAuth write token in `Authorization` header
(no "Bearer" prefix). The token does not expire or rotate — it is a
long-lived project-level credential. Logfire supports both JSON and
Protobuf over HTTP (no gRPC).

### Spike Results (Validated)

The spike (`spike/otel_spike.dart`) confirmed end-to-end delivery:

| Finding | Detail |
|---------|--------|
| **Endpoint** | `https://logfire-us.pydantic.dev/v1/logs` (not `logfire-api`) |
| **Auth** | Raw write token in `Authorization` header, no "Bearer" prefix |
| **Protocol** | OTLP/HTTP JSON accepted, HTTP 200 returned |
| **Payload size** | 2.2 KB for 6 records across 4 scopes |
| **Content-Type** | `application/json` |
| **Trace context** | `traceId`/`spanId` hex strings accepted, but see Orphaned Spans below |
| **Error records** | `exception.type`, `exception.message`, `exception.stacktrace` attributes accepted |
| **Resource attrs** | `service.name`, `service.version`, `deployment.environment`, `os.name`, `os.version` all ingested |
| **Scope grouping** | Records grouped by `scope.name` (logger name) — Logfire displays them correctly |
| **Timestamps** | `timeUnixNano` as string (microseconds * 1000) accepted |

**One gotcha:** Logfire is fully standard OTLP — no quirks or special
requirements beyond the auth header format. However, see Orphaned Spans below.

### Orphaned Spans (Spike Finding)

Sending log records with `traceId`/`spanId` without corresponding trace spans
(via `/v1/traces`) causes Logfire to display "missing root span" warnings.
Logfire sees the trace IDs referenced in logs, looks for matching spans, and
groups the orphaned references together.

**Root cause:** The spike only exports **log records** — it never creates
actual **trace spans**. Logfire correctly identifies the trace context as
incomplete.

**Resolution:** The spike was updated to omit `traceId`/`spanId` from log
records. For production, trace context should only be attached to log records
when it originates from real trace spans. The `BackendLogSink` passes through
`traceId`/`spanId` from `LogRecord` fields only when they are populated by
the tracing layer, not synthesized.

## Approach: Spike First

### Phase 0 — Spike Solution (This Milestone)

**Goal:** Validate end-to-end log delivery from Dart to Logfire in the
simplest possible way. No production concerns, no batching, no retry.

#### Chosen: Option A — Raw OTLP/HTTP JSON (No dartastic dependency)

Build a minimal OTLP/HTTP log exporter from scratch using the OTLP JSON
protocol. The OTLP/HTTP JSON spec is simple enough to hand-craft:

```text
POST /v1/logs HTTP/1.1
Content-Type: application/json
Authorization: <write-token>

{
  "resourceLogs": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "soliplex-flutter"}},
        {"key": "service.version", "value": {"stringValue": "0.1.0"}},
        {"key": "deployment.environment", "value": {"stringValue": "dev"}},
        {"key": "os.name", "value": {"stringValue": "macos"}}
      ]
    },
    "scopeLogs": [{
      "scope": { "name": "Auth" },
      "logRecords": [{
        "timeUnixNano": "1706000000000000000",
        "severityNumber": 9,
        "severityText": "INFO",
        "body": { "stringValue": "User logged in" },
        "traceId": "2858b245789667e5f284d6f014f510ec",
        "spanId": "a1b2c3d4e5f67890",
        "attributes": []
      }]
    }]
  }]
}
```

**Why not Option B (dartastic for tracing + raw log export)?**
Heavier dependency, mixes two approaches, and dartastic's log pipeline is
incomplete. Option A validates protocol and Logfire acceptance with minimal
investment. Re-evaluate dartastic for production tracing later.

**Result:** Option A validated successfully. See Spike Results above.

### Spike Deliverables

1. **`spike/otel_spike.dart`** — Standalone Dart script that:
   - Creates sample LogRecords at multiple severity levels
   - Converts them to OTLP JSON format
   - POSTs to Logfire endpoint
   - Prints HTTP response (200 = success)
   - Includes an error record with exception + stack trace
2. **LogLevel → SeverityNumber mapping** — Validated against OTel spec
3. **LogRecord → OTLP LogRecord conversion** — Field mapping documented
4. **Logfire authentication** — Raw write token (no "Bearer" prefix) via
   `LOGFIRE_TOKEN` env var

### Spike Success Criteria

- [x] HTTP 200 from Logfire endpoint
- [ ] Log records visible in Logfire UI
- [ ] Trace/span IDs correlate correctly in Logfire
- [ ] Timestamps render correctly (nanosecond precision)
- [ ] Error records show exception details in Logfire

### Spike Gotchas (from review)

- **traceId/spanId encoding:** OTLP JSON expects hex-encoded strings.
  Ensure Dart strings are clean hex (32 chars for traceId, 16 for spanId).
- **Strip nulls:** Omit null fields from JSON to minimize payload.
- **Logfire views:** Logfire uses attributes for its SQL-like filtering.
  Without structured attributes, logs will show as flat text only.

## Known Gaps (Post-Spike)

### LogRecord Attributes Gap

**Critical finding from review:** `LogRecord` currently has no
`Map<String, Object>? attributes` field. Without it, we can only export
flat messages and exceptions — no structured context like `user_id`,
`http_status`, or `view_name`.

**Plan:**

- Add `final Map<String, Object> attributes` to `LogRecord` with default
  `const {}` (non-breaking for the constructor)
- Update `Logger` method signatures to accept optional `attributes`
  parameter (API change — coordinate with consumers)
- This is a Phase 1 prerequisite, not needed for the spike

### Resource Detection

The OTel `Resource` describes the entity producing telemetry. For production
the `BackendLogSink` constructor needs:

- `service.name` — "soliplex-flutter"
- `service.version` — from `package_info_plus`
- `os.name`, `os.version` — platform detection
- `device.model` — from `device_info_plus`
- `deployment.environment` — dev/staging/prod

The spike hardcodes these; production builds them dynamically.

### Instrumentation Scope Version

Map `loggerName` to `scope.name` (already planned). Should also send
`scope.version` with the `soliplex_logging` package version.

## Production Roadmap (Option B — Backend Relay)

The previous roadmap (commit `84d7950`) built a full OTel client in Dart:
OtelMapper, OtelExporter, LogfireExporter, ProxyExporter, batch processor,
retry/circuit breaker, gzip compression. That approach was over-engineered
for log-only export.

**Option B** sends simple JSON to the Soliplex Python backend, which uses
the mature Python OTel SDK for OTLP mapping, batching, retry, and
compression.

### Phase 1 — Core (P0, Sub-milestones 12.1–12.4)

- [ ] **12.1 LogRecord attributes** — Add `Map<String, Object> attributes`
  field to `LogRecord` (default `const {}`). Update `Logger` API.
- [ ] **12.2 BackendLogSink** — disk-backed queue (JSONL), JSON POST to
  backend, timer + severity flush, basic retry, `LogSanitizer` (PII
  redaction), session/user correlation, Dart crash hooks
- [ ] **12.3 App integration** — Riverpod providers, Telemetry screen UI,
  resource attributes, connectivity check, lifecycle flush
- [ ] **12.4 Backend ingest** — Python `POST /api/v1/logs` endpoint,
  Python OTel SDK forwarding to Logfire

### Phase 2 — Enhanced Context (P1, Sub-milestones 12.5–12.7)

- [ ] **12.5 Breadcrumbs** — last N logs from MemorySink attached to
  crash/error payloads
- [ ] **12.6 Remote log level** — backend config endpoint, app polls on
  startup + periodically
- [ ] **12.7 Error fingerprinting** — backend groups errors by type + top
  stack frame (Python side)

### Phase 3 — Diagnostics (P2, Sub-milestones 12.8–12.9)

- [ ] **12.8 RUM / performance** — cold start, slow frames, route timing,
  HTTP latency as structured log attributes
- [ ] **12.9 Screenshot on error** — RepaintBoundary capture, attach to
  error reports

### Context Propagation (Future)

Currently `traceId`/`spanId` are passed manually via `Logger.info(traceId:
...)`. The `Logger` API is designed so that explicit params are optional
overrides, not the primary mechanism. When tracing is added later, a
Zone-based context holder can propagate trace context automatically without
requiring changes at every call site.

## Field Mapping Reference

### LogLevel → OTel SeverityNumber

| LogLevel | SeverityNumber | SeverityText |
|----------|---------------|--------------|
| trace | 1 | TRACE |
| debug | 5 | DEBUG |
| info | 9 | INFO |
| warning | 13 | WARN |
| error | 17 | ERROR |
| fatal | 21 | FATAL |

### LogRecord → OTLP LogRecord

| LogRecord field | OTLP field | Conversion |
|----------------|------------|------------|
| `timestamp` | `timeUnixNano` | `microsecondsSinceEpoch * 1000` (string) |
| *(set by sink)* | `observedTimeUnixNano` | `DateTime.now()` at `write()` time (string) |
| `level` | `severityNumber` | See mapping table above |
| `level.label` | `severityText` | Direct string |
| `message` | `body.stringValue` | Direct string |
| `loggerName` | `scope.name` | InstrumentationScope |
| `traceId` | `traceId` | Hex string (32 chars) |
| `spanId` | `spanId` | Hex string (16 chars) |
| *(trace context)* | `flags` | `0x01` if sampled, `0x00` otherwise |
| `error` | `attributes[exception.type, exception.message]` | OTel semantic conventions |
| `stackTrace` | `attributes[exception.stacktrace]` | String representation |
| `attributes` | `attributes` | Typed `AnyValue` mapping (see below) |
| *(computed)* | `droppedAttributesCount` | Count of attributes dropped by limit |

### Attribute `AnyValue` Mapping (Reference)

With Option B, the Python OTel SDK handles typed attribute mapping. This
section is retained as reference for the JSON attribute format the Flutter
client sends to the backend. The Python SDK maps these to OTLP `AnyValue`:

| Dart type | OTLP `AnyValue` key | Example |
|-----------|---------------------|---------|
| `String` | `stringValue` | `{"stringValue": "hello"}` |
| `int` | `intValue` | `{"intValue": "42"}` (string-encoded int64) |
| `double` | `doubleValue` | `{"doubleValue": 3.14}` |
| `bool` | `boolValue` | `{"boolValue": true}` |
| `List` | `arrayValue` | `{"arrayValue": {"values": [...]}}` |
| `Map<String, Object>` | `kvlistValue` | `{"kvlistValue": {"values": [{"key":..., "value":...}]}}` |
| *(other)* | `stringValue` | Fallback: `.toString()` for unknown types only |

This enables Logfire's SQL-like querying on structured attributes
(e.g., `WHERE attributes.cart.total > 50`). Flattening to strings
would destroy this capability.

## Web Platform Considerations

### Why Backend Relay Solves CORS

The previous plan required a web-specific proxy because browsers block
direct OTLP POSTs to `https://logfire-us.pydantic.dev/v1/logs` (CORS
preflight failure). Option B eliminates this — all platforms POST to the
same backend endpoint (`/api/v1/logs`), which is same-origin for web.

### Remaining Web Constraints

| Concern | Mobile/Desktop | Web |
|---------|---------------|-----|
| Lifecycle flush | `AppLifecycleState.paused` | No `paused` — must use `visibilitychange` / `beforeunload` |
| Background timers | Run freely | Throttled to ~1/min in background tabs |
| Connectivity | `connectivity_plus` | `navigator.onLine` (unreliable) |
| DiskQueue | JSONL file | No filesystem — falls back to in-memory queue |

### Platform Handling (Option B)

With Option B, all platforms POST to the same backend endpoint (`/api/v1/logs`)
using session JWT auth. No platform branching is needed:

| Platform | Endpoint | Auth Header |
|----------|----------|-------------|
| Mobile / Desktop / Web | `/api/v1/logs` | `Bearer <session-jwt>` |

The Logfire write token never reaches the client on any platform. The Python
backend holds it server-side.

### Web Lifecycle Handling

Flutter Web does not fire `AppLifecycleState.paused`. Use browser events:

- **`visibilitychange`** → `document.hidden == true`: flush the batch
  queue (tab hidden or switching away)
- **`beforeunload`** → last-chance flush before navigation/close.
  Use synchronous `XMLHttpRequest` or `navigator.sendBeacon()` (note:
  `sendBeacon` cannot set custom headers, so the proxy must accept
  unauthenticated requests from `sendBeacon` with a short-lived nonce,
  or accept that final-flush logs may be lost on web)

**Practical approach:** Rely on `visibilitychange` for the primary flush
trigger. Accept that `beforeunload` is best-effort — the 30s batch
interval means at most 30s of logs are at risk on abrupt tab close.

### Web Timer Throttling

Browsers throttle `setTimeout`/`setInterval` in background tabs to ~1
call per minute. Impact on the 30s batch interval:

- **Background tab:** Batch export slows to ~60s. Acceptable — logs are
  buffered in memory and flushed when the tab regains focus via
  `visibilitychange`.
- **Foreground tab:** No throttling, 30s interval works as designed.

No mitigation needed. The `visibilitychange` flush covers the gap.

## Production Concerns

### What Moves Server-Side (Option B)

With Option B, the Python OTel SDK handles OTLP mapping, batching, retry,
compression, gzip, and circuit breaking. The Flutter client is simpler but
still needs:

### PII & Redaction (P0 — DoD Requirement)

`LogSanitizer` (12.2) runs client-side before any data leaves the device:

- **Key blocklist:** `password`, `token`, `auth`, `secret`, `ssn`,
  `credential` → values replaced with `[REDACTED]`
- **Pattern scrubbing:** regex for emails, SSNs, bearer tokens, IPs
- **Stack trace trimming:** strip absolute file paths to relative
- Configurable: additional keys/patterns at construction

### Backpressure & Drop Policy

`DiskQueue` (12.2) caps at 10 MB. When full:

- Drop oldest records (preserve recent context)
- File rotation: new file, discard oldest
- Drop counter tracked for diagnostics

### Error Handling (HTTP)

`BackendLogSink` (12.2) classifies HTTP responses:

- **200** — confirm records, remove from queue
- **401/403** — disable export, fire `onError` callback
- **429/5xx** — exponential backoff (1s, 2s, 4s, max 60s), keep in queue
- **Poison pill:** if same batch fails 3 consecutive times, discard it
  and move to next batch (prevents one malformed record from blocking
  all log delivery)
- **No re-entrant logging:** sink failures go to `onError` callback or
  `stderr`, never re-enter the logging pipeline

### Record Size Guard

Individual log records are capped at 64 KB serialized JSON. If a developer
accidentally logs a large API response or binary blob, the record is
truncated before entering `DiskQueue`. This prevents mega-logs from
filling the queue and burning battery on repeated writes.

### Token Security (Simplified)

With Option B, the Logfire write token **never reaches the Flutter client**.
The Python backend holds it in server-side config. Flutter clients
authenticate to the backend via session JWT only. No `flutter_secure_storage`
needed for token storage.

### Testing Strategy

- **LogSanitizer tests:** PII patterns scrubbed, key blocklist enforced
- **DiskQueue tests:** append/drain round-trip, crash recovery, rotation
- **BackendLogSink tests:** timer flush, severity flush, HTTP classification,
  offline skip, `close()` drain
- **Integration tests:** full pipeline (Logger → sink → mock HTTP),
  crash recovery, sanitizer in payload
- **Backend tests (Python):** OTel mapping, auth, rate limits, size limits

## Validation Gate

Production-ready when:

- [ ] `LogRecord` has `attributes` field, all `Logger` methods accept it
- [ ] `LogSanitizer` redacts sensitive keys and PII patterns (DoD P0)
- [ ] `DiskQueue` persists records to JSONL, survives crashes
- [ ] `DiskQueue` rotates at 10 MB cap
- [ ] `BackendLogSink` serializes `LogRecord` to simple JSON
- [ ] SessionId and userId injected into every payload
- [ ] Timer-based flush (30s) and severity-triggered flush (ERROR/FATAL)
- [ ] HTTP 200 confirms records, 429/5xx retries with backoff
- [ ] HTTP 401/403 disables export, fires `onError`
- [ ] Sink never re-enters logging pipeline on failure
- [ ] NetworkChecker skips flush when offline
- [ ] `flush()` called on app lifecycle pause/hidden/visibilitychange
- [ ] `close()` drains remaining queue
- [ ] Poison pill: batch discarded after 3 consecutive failures
- [ ] Record size guard: records > 64 KB truncated
- [ ] Session start marker emitted on startup with device/app attributes
- [ ] Connectivity changes logged as `network_changed` events
- [ ] Dart crash hooks capture uncaught exceptions as fatal logs
- [ ] Logfire write token never reaches the Flutter client
- [ ] Python endpoint maps to OTel LogRecords, forwards to Logfire
- [ ] Backend enforces auth, rate limits, and size limits
- [ ] No PII in exported payloads (sanitizer tests pass)

## Dartastic Review Findings (Feb 2026)

Reviewed `dartastic_opentelemetry` v1.0.0-alpha feature set. Key insight:
dartastic has no working log SDK. This reinforced the Option B decision —
there is no viable Dart OTel log library. Building one from scratch is
not justified when the Python OTel SDK is mature.

### Weaknesses Identified (Informed Option B Decision)

| Finding | Severity | Resolution |
|---------|----------|------------|
| `toString()` attribute coercion | P0 | Moot — Python SDK handles typed mapping server-side |
| Missing `observedTimeUnixNano` | P0 | Moot — Python SDK sets `observedTimestamp` |
| No gzip compression | P1 | Moot — Python SDK handles compression |
| Missing `droppedAttributesCount`/`flags` | P1 | Moot — Python SDK handles these fields |
| Manual `traceId`/`spanId` threading | P2 | Context propagation prep noted (Future) |
| Lifecycle flush race | P2 | Solved — `DiskQueue` (12.2) survives OS kills |

### What We Do Better

- **Log export works** — dartastic has no log SDK; we ship logs via backend relay
- **All platforms, one endpoint** — no CORS issues, no web proxy needed
- **Crash persistence** — `DiskQueue` survives crashes (dartastic has no persistence)
- **PII protection** — `LogSanitizer` (DoD P0) before data leaves device
- **Pure Dart boundary** — no global statics, clean constructor injection

## Breaking Changes

**Spike:** None.

**12.1:** Adding `attributes` to `LogRecord` constructor is non-breaking
(optional with default `const {}`). Updating `Logger` method signatures to
accept `attributes` is an API change — all call sites still compile but
should be coordinated.

**12.2:** New files only (`BackendLogSink`, `DiskQueue`, `LogSanitizer`).
No breaking changes.

## Dependencies

### Spike

- `http` package (already in dependency tree via `soliplex_client`)

### Production — soliplex_logging (Pure Dart)

- `http` package for HTTP POST (pure Dart)
- `path_provider` for `DiskQueue` file location (Flutter plugin — see
  layering note below)

### Production — soliplex_frontend (Flutter App Layer)

- `connectivity_plus` for network awareness (injected to `BackendLogSink`
  via `networkChecker` callback)
- `package_info_plus` for `service.version` resource attribute
- `device_info_plus` for `device.model` resource attribute
- `uuid` for session ID generation

### Layering Note

`path_provider` is a Flutter plugin, which conflicts with the pure Dart
boundary of `soliplex_logging`. Options:

1. **Inject the file path** — `DiskQueue` constructor takes a `String`
   directory path. App layer calls `path_provider` and passes the result.
   `soliplex_logging` stays pure Dart. **(Preferred)**
2. **Accept the dependency** — add `path_provider` to `soliplex_logging`.
   Simpler but breaks the pure Dart boundary.

### Layering Principle

```text
soliplex_logging (Pure Dart)        soliplex_frontend (Flutter)
├── http                            ├── connectivity_plus
├── BackendLogSink                  ├── package_info_plus
│   accepts http.Client             ├── device_info_plus
│   accepts networkChecker          ├── path_provider (→ DiskQueue path)
│   accepts resourceAttributes Map  ├── uuid (→ sessionId)
├── DiskQueue                       └── Riverpod providers compose
│   accepts directory path String       pure Dart + Flutter plugins
├── LogSanitizer
└── LogRecord + attributes
```
