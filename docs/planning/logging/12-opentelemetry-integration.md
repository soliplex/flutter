# Milestone 12: OpenTelemetry Integration (Logfire)

## Goal

Validate that soliplex_logging can export structured logs to an OpenTelemetry
collector (Logfire) via OTLP/HTTP, then build a production-ready `OtelSink`.

## Status: Spike Complete

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
when it originates from real trace spans (Phase 3). The `OtelSink` should
pass through `traceId`/`spanId` from `LogRecord` fields only when they are
populated by the tracing layer, not synthesized.

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
the `OtelSink` constructor needs:

- `service.name` — "soliplex-flutter"
- `service.version` — from `package_info_plus`
- `os.name`, `os.version` — platform detection
- `device.model` — from `device_info_plus`
- `deployment.environment` — dev/staging/prod

The spike hardcodes these; production builds them dynamically.

### Instrumentation Scope Version

Map `loggerName` to `scope.name` (already planned). Should also send
`scope.version` with the `soliplex_logging` package version.

## Production Roadmap (Post-Spike)

### Phase 1 — OtelSink + Pluggable Exporters (Sub-milestones 12.1–12.2)

- [ ] Add `Map<String, Object> attributes` field to `LogRecord`
- [ ] `OtelExporter` interface with `export()` and `shutdown()`
- [ ] `LogfireExporter` — direct OTLP/HTTP to Logfire (raw write token).
  Accepts injected `http.Client` (app provides native client)
- [ ] `ProxyExporter` — routes through backend proxy (session JWT).
  Accepts injected `http.Client`
- [ ] `OtelSink` implements `LogSink`, takes any `OtelExporter`.
  Accepts optional `NetworkStatusChecker` callback for connectivity
- [ ] `OtelMapper` with safe serialization (coerce non-primitives to
  `.toString()`)
- [ ] Batch processor with **mobile-tuned** settings:
  - Batch size: 256 records
  - Export interval: **30s** (not 5s — preserves battery/radio)
  - Severity-based flush: immediate export on ERROR/FATAL
  - Max queue size: 1024 records (bounded memory)
  - Drop policy: when full, drop TRACE/DEBUG first. If queue is all
    ERROR/FATAL, drop oldest ERROR (never block writes)
- [ ] Retry with exponential backoff + jitter (1s, 2s, 4s, max 32s)
- [ ] HTTP status classification via `ExportResult`:
  - 401/403 → `fatal` (disable export)
  - 413 → `retryable` (split batch in half and retry)
  - 429 → `retryable` (respect `Retry-After`)
  - 5xx → `retryable` (backoff, max 5 min per batch)
- [ ] **Connectivity check** via injected `NetworkStatusChecker` callback
  (app layer provides using `connectivity_plus`; `soliplex_logging` stays
  pure Dart)
- [ ] Graceful shutdown: flush remaining records in `close()`
- [ ] Export from `soliplex_logging.dart` barrel

### Phase 2a — App Integration, Native Platforms (Sub-milestone 12.3)

- [ ] **Telemetry screen** — dedicated Settings sub-screen with token
  entry field, enable/disable toggle, endpoint field, connection status.
  Web shows "requires backend proxy" message (CORS blocks direct export).
- [ ] `otelTokenProvider` (`FutureProvider<String?>`) — reads Logfire
  write token from `flutter_secure_storage`
- [ ] `otelExporterProvider` — creates `LogfireExporter` on mobile/desktop
  (direct to Logfire). Web OTel-disabled until 12.4 proxy.
- [ ] `otelSinkProvider` — creates `OtelSink` with exporter, registers
  with LogManager (follows existing sink provider pattern)
- [ ] `LogConfig` extended with `otelEnabled`, `otelEndpoint` (NOT token —
  token lives in `flutter_secure_storage` via separate async provider)
- [ ] `logConfigControllerProvider` updated to manage OtelSink
- [ ] **Resource provider** (app layer) — builds `Map<String, Object>`
  resource attributes at startup using `package_info_plus` and
  `device_info_plus`: `service.name`, `service.version`, `os.name`,
  `os.version`, `device.model`, `deployment.environment`. Passed to
  `OtelSink` constructor (pure Dart accepts a `Map`)
- [ ] **Mobile lifecycle flush** — `flush()` on `AppLifecycleState.paused`
  via `AppLifecycleListener`
- [ ] **Desktop lifecycle flush** — `flush()` on
  `AppLifecycleState.hidden` and `detached` (desktop does not reliably
  emit `paused`)

### Phase 2b — Web Proxy Swap (Sub-milestone 12.4)

- [ ] **Backend proxy endpoint** — `POST /api/v1/telemetry/logs` on
  Soliplex backend (forwards OTLP to Logfire with server-side token)
- [ ] `otelExporterProvider` updated — selects `ProxyExporter` (web) or
  `LogfireExporter` (native) based on `kIsWeb`
- [ ] **Telemetry screen (web)** — hides token field (proxy holds token)
- [ ] Web clients no longer store the Logfire write token

### Phase 3 — Tracing Integration (Optional)

- [ ] Evaluate `dartastic_opentelemetry` for tracing (if log support matures)
- [ ] Or `flutterrific_opentelemetry` for automatic navigation/lifecycle spans
- [ ] Propagate W3C traceparent header from HTTP requests to log records
- [ ] Link x-request-id (Milestone 11) to OTel trace context

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
| `timestamp` | `timeUnixNano` | `microsecondsSinceEpoch * 1000` |
| `level` | `severityNumber` | See mapping table above |
| `level.label` | `severityText` | Direct string |
| `message` | `body.stringValue` | Direct string |
| `loggerName` | `scope.name` | InstrumentationScope |
| `traceId` | `traceId` | Hex string (32 chars) |
| `spanId` | `spanId` | Hex string (16 chars) |
| `error` | `attributes[exception.type, exception.message]` | OTel semantic conventions |
| `stackTrace` | `attributes[exception.stacktrace]` | String representation |

## Web Platform (Proxy Route)

### Problem

Browsers enforce same-origin policy. A direct `POST` from Flutter Web to
`https://logfire-us.pydantic.dev/v1/logs` with a custom `Authorization`
header triggers a CORS preflight that Logfire does not support. Additional
web constraints:

| Concern | Mobile/Desktop | Web |
|---------|---------------|-----|
| CORS | N/A | Blocks cross-origin OTLP requests |
| Token storage | Keychain / Keystore | No secure storage — `localStorage` is visible in DevTools |
| Lifecycle flush | `AppLifecycleState.paused` | No `paused` — must use `visibilitychange` / `beforeunload` |
| Background timers | Run freely | Throttled to ~1/min in background tabs |
| Connectivity | `connectivity_plus` | `navigator.onLine` (unreliable) |

### Solution: Backend Proxy

Route web log export through the Soliplex backend. The proxy:

1. Receives OTLP JSON from the client on a same-origin endpoint
2. Attaches the Logfire write token server-side
3. Forwards to `https://logfire-us.pydantic.dev/v1/logs`
4. Returns the upstream status code to the client

```text
Flutter Web ──POST /api/v1/telemetry/logs──▶ Soliplex Backend ──POST /v1/logs──▶ Logfire
              (same origin, no auth header)     (attaches write token)
```

**Benefits:**

- **No CORS** — same-origin request, no preflight
- **Token never reaches the client** — write token lives in backend
  config/secrets, not in browser storage or JS bundles
- **Unified auth** — proxy authenticates the request using the existing
  session/JWT, so only authenticated users can export logs
- **Rate limiting** — backend can enforce per-user/per-session rate limits
  before forwarding to Logfire

### Proxy Endpoint Spec

```text
POST /api/v1/telemetry/logs
Content-Type: application/json
Authorization: Bearer <session-jwt>

Body: OTLP JSON (same schema as direct Logfire export)
```

The backend validates the session, then forwards the body to Logfire with
the write token. Returns:

- **200** — forwarded successfully
- **401** — invalid/expired session
- **413** — payload too large (reject before forwarding)
- **429** — rate limited
- **502** — Logfire upstream error

### OtelSink Platform Branching

`OtelSink` accepts an endpoint URL at construction. The platform difference
is configuration only — no conditional code inside the sink:

| Platform | Endpoint | Auth Header |
|----------|----------|-------------|
| Mobile / Desktop | `https://logfire-us.pydantic.dev/v1/logs` | `<write-token>` (raw) |
| Web | `/api/v1/telemetry/logs` (relative, same origin) | `Bearer <session-jwt>` |

The Riverpod provider selects the endpoint based on `kIsWeb`:

```dart
final endpoint = kIsWeb
    ? '/api/v1/telemetry/logs'
    : 'https://logfire-us.pydantic.dev/v1/logs';
```

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

## Production Concerns (from Codex Review)

### Sampling & Rate Limiting

The spec defines batching but no sampling. For production:

- **Level-based sampling:** Always export ERROR/FATAL. Sample DEBUG/TRACE
  at a configurable rate (e.g., 10% in prod, 100% in dev)
- **Per-logger rate caps:** Prevent noisy loggers from dominating export
  bandwidth (e.g., max 100 records/min per logger)
- **Burst limits:** Allow short bursts but throttle sustained high volume
- **Interaction with trace sampling:** When Phase 3 adds tracing, ensure
  log sampling aligns with trace sampling to avoid orphaned context

### PII & Redaction

No sanitizer layer exists. Before production export:

- **Attribute allowlist:** Only export known-safe attribute keys by default
- **Message scrubbing:** Configurable regex patterns to redact emails,
  tokens, IPs, and other PII from message bodies
- **Stack trace trimming:** Strip file paths that may leak internal
  directory structure
- **Guidelines:** Document which attributes are safe to export and which
  require scrubbing

### Backpressure & Drop Policy

Max queue size is 1024 records:

- **Drop strategy:** Drop oldest records first (preserve recent context)
- **Severity protection:** Drop TRACE/DEBUG first. If queue is entirely
  ERROR/FATAL, drop oldest ERROR (never block writes)
- **Drop counter:** Track and export `otel.logs.dropped_count` as a
  self-diagnostic metric
- **User alert:** Surface sustained drop rates via in-app debug indicator

### Circuit Breaker & Self-Logging Protection

- **Circuit breaker:** After N consecutive `fatal` export results (e.g. 3),
  disable export entirely until config is changed or app restarts.
  Surface disabled state via `onError` callback.
- **No re-entrant logging:** `OtelSink` must NEVER generate log records
  about its own failures that re-enter the logging pipeline. This
  prevents infinite loops where export failure → log → export failure.
  Diagnostic errors go to a separate `onError` callback or `stderr` only.

### Error Handling (HTTP Classification)

Retry with exponential backoff is planned, but HTTP error responses
need specific handling:

- **401/403:** Disable export and surface auth error to settings UI.
  Do not retry (token is invalid/revoked)
- **413:** Batch too large — split and retry with smaller batches
- **429:** Respect `Retry-After` header; back off accordingly
- **5xx:** Exponential backoff with jitter (1s, 2s, 4s, max 32s).
  Max retry window: 5 minutes per batch
- **Partial success:** If Logfire returns per-record errors, drop
  failed records and log diagnostically

### Token Security

The Logfire write token is **not** stored in `LogConfig` (which uses
synchronous `SharedPreferences`). Instead, it is loaded via a dedicated
async provider backed by `flutter_secure_storage`:

- **Mobile / Desktop:** `otelTokenProvider` (`FutureProvider<String?>`)
  reads from `flutter_secure_storage` (Keychain on iOS, Keystore on
  Android). Token rotation invalidates the provider, triggering exporter
  recreation.
- **Web:** Write token never reaches the client. The backend proxy
  holds the Logfire token in server-side config. Web clients authenticate
  to the proxy via session JWT only.
- **Never log the token:** Ensure token value is excluded from all
  log output, error messages, and debug prints
- **Static token:** The Logfire write token is a long-lived static OAuth
  credential. No rotation mechanism is needed, but the provider pattern
  supports invalidation if Logfire changes this in the future.
- **Startup policy:** If token unavailable at startup, disable OTel
  export gracefully (fail open for logging, closed for export)

### Testing Strategy

The spike validates protocol acceptance but production needs:

- **Unit tests:** OTLP JSON mapping (severity, timestamp, attributes,
  error conventions, scope grouping)
- **Batch processor tests:** Timer-based flush, size-based flush,
  severity-triggered flush, queue overflow/drop policy
- **Retry tests:** Backoff timing, jitter, HTTP status classification,
  max retry window
- **Redaction tests:** PII patterns scrubbed, allowlist enforced
- **Integration test:** Round-trip to Logfire staging endpoint
- **Lifecycle tests:** Flush on `AppLifecycleState.paused` (mobile),
  `visibilitychange` (web), graceful `close()` drain
- **Proxy tests:** Backend forwards OTLP payload, attaches token,
  rejects unauthenticated requests, enforces rate limits

## Validation Gate

Production-ready when:

- [ ] OTLP JSON mapping matches OTel spec (unit tests)
- [ ] Mapper safely coerces non-primitive attribute values to `.toString()`
- [ ] Batch processor respects size, timer, and severity triggers
- [ ] Queue overflow drops by severity (TRACE first); if all ERROR/FATAL,
  drops oldest ERROR (never blocks writes)
- [ ] Retry handles 401/403/413/429/5xx correctly (413 splits batch)
- [ ] Circuit breaker disables export after consecutive fatals
- [ ] OtelSink never re-enters logging pipeline on failure
- [ ] Concurrent flush guard prevents overlapping exports
- [ ] Token stored in `flutter_secure_storage` (NOT `LogConfig`/
  `SharedPreferences`), never logged
- [ ] `flush()` called on app lifecycle pause (mobile) and
  `visibilitychange` (web)
- [ ] `close()` drains remaining queue
- [ ] Web proxy forwards OTLP, attaches token server-side, validates session
- [ ] Web clients never receive or store the Logfire write token
- [ ] No PII in exported attributes (redaction tests pass — hardening)
- [ ] Drop counter tracks and reports lost records

## Breaking Changes

**Spike:** None.

**Phase 1:** Adding `attributes` to `LogRecord` constructor is non-breaking
(optional with default). Updating `Logger` method signatures to accept
`attributes` is an API change — all call sites still compile but should be
coordinated.

## Dependencies

### Spike

- `http` package (already in dependency tree via `soliplex_client`)

### Production — soliplex_logging (Pure Dart)

- `http` package for OTLP/HTTP (pure Dart, added to
  `packages/soliplex_logging/pubspec.yaml`)
- No Flutter plugins — all platform concerns injected via constructor

### Production — soliplex_frontend (Flutter App Layer)

- `connectivity_plus` for network awareness (injected to `OtelSink` via
  `NetworkStatusChecker` callback)
- `flutter_secure_storage` for token storage (already in pubspec.yaml)
- `package_info_plus` for `service.version` resource attribute
- `device_info_plus` for `device.model` resource attribute
- Possibly `dartastic_opentelemetry` if their log export matures
- Possibly `protobuf` if upgrading from JSON to binary encoding

### Layering Principle

```text
soliplex_logging (Pure Dart)        soliplex_frontend (Flutter)
├── http                            ├── connectivity_plus
├── OtelSink                        ├── flutter_secure_storage
│   accepts NetworkStatusChecker    ├── package_info_plus
│   accepts resourceAttributes Map  ├── device_info_plus
├── OtelExporter interface          └── Riverpod providers compose
├── LogfireExporter                     pure Dart + Flutter plugins
│   accepts http.Client
├── ProxyExporter
│   accepts http.Client
└── OtelMapper
```
