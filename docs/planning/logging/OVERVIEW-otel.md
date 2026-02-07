# OpenTelemetry Integration - Overview

## Goal

Export structured logs from `soliplex_logging` to Logfire (Pydantic) via
OTLP/HTTP JSON. Native platforms export directly; web routes through a
backend proxy.

## Status: Spike Complete, Production Build Starting

The spike (`spike/otel_spike.dart`) validated end-to-end delivery: HTTP 200
from Logfire, OTLP JSON accepted, severity/timestamp/scope/error attributes
all ingested correctly.

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Flutter App                                                │
│                                                             │
│  Logger.info() ──▶ LogManager ──▶ OtelSink                  │
│                                    │                        │
│                         ┌──────────┴──────────┐             │
│                         │  Batch Processor     │             │
│                         │  256 records / 30s   │             │
│                         │  Immediate on ERROR  │             │
│                         └──────────┬──────────┘             │
│                                    │                        │
│                              OtelExporter                   │
│                           (pluggable interface)             │
│                    ┌───────────────┼───────────────┐        │
│                    │               │               │        │
│              LogfireExporter  ProxyExporter    (future)     │
│                    │               │                        │
└────────────────────┼───────────────┼────────────────────────┘
                     │               │
                     ▼               ▼
              Logfire direct    Soliplex Backend
              (write token)     /api/v1/telemetry/
                                logs (session JWT)
                                     │
                                     ▼
                                  Logfire
                                (server-side token)
```

## Sub-Milestones

| # | Name | Scope | Depends On |
|---|------|-------|------------|
| 12.1 | LogRecord attributes | Add `Map<String, Object> attributes` to `LogRecord`, update `Logger` API | — |
| 12.2 | OTLP mapper | `OtelMapper`: typed `AnyValue` serialization, timestamps, `observedTimeUnixNano`, `flags`, `droppedAttributesCount`, payload structure | 12.1 |
| 12.3 | Exporter transport | `OtelExporter` interface, `LogfireExporter`, `ProxyExporter`, gzip compression, HTTP status → `ExportResult` mapping | 12.2 |
| 12.4 | OtelSink batching | `OtelSink` implements `LogSink`: queue, timer/size/severity flush triggers, overflow drop policy, concurrent flush guard, `close()` drain | 12.3 |
| 12.5 | Reliability layer | Retry with exponential backoff, 413 batch split, circuit breaker, `NetworkStatusChecker`, no re-entrant logging | 12.4 |
| 12.6 | App wiring (native) | Riverpod providers, resource attributes, connectivity integration, lifecycle flush (no UI yet). Web OTel-disabled. | 12.5 |
| 12.7 | Telemetry screen UI | Dedicated settings screen: token entry, enable/disable toggle, endpoint, connection status | 12.6 |
| 12.8 | Web proxy (swap exporter) | Backend proxy endpoint, swap web to `ProxyExporter`, web lifecycle flush, web UI adjustments | 12.7 |
| 12.9 | Hardening | PII redaction, sampling, rate limiting, backpressure observability. Can parallelize with 12.6–12.8 (pure Dart). | 12.5 |

## Key Decisions

- **Pluggable exporters** — `OtelSink` owns batching/queuing. Transport is
  delegated to an `OtelExporter` interface with two implementations:
  `LogfireExporter` (direct OTLP/HTTP) and `ProxyExporter` (backend proxy).
  New backends can be added without touching the sink.
- **Proxy for web** — CORS blocks direct OTLP from browser. Backend proxy
  at `/api/v1/telemetry/logs` attaches Logfire token server-side.
- **Raw OTLP/HTTP JSON** — no `dartastic_opentelemetry` dependency. Their
  log SDK is not implemented. Hand-crafted JSON is simpler and validated.
- **Typed `AnyValue` attributes** — mapper preserves `bool`, `int`,
  `double`, `List`, `Map` into correct OTLP type wrappers (not
  `toString()`). Enables Logfire SQL-like attribute querying.
- **Gzip compression** — exporters compress payloads by default to reduce
  mobile battery/data usage.
- **PII/sampling deferred** — get basic export working first, harden later.
- **`LogRecord.attributes`** is its own sub-milestone — clean prerequisite
  boundary, separate PR.
- **Pure Dart boundary** — `soliplex_logging` only adds `http` as a
  dependency. Flutter plugins (`connectivity_plus`, `flutter_secure_storage`,
  `package_info_plus`, `device_info_plus`) stay in the app layer and are
  injected via constructor args (`NetworkStatusChecker` callback, `http.Client`,
  resource attributes `Map`).

## Codebase Readiness

| Component | Status |
|-----------|--------|
| `LogRecord` with `traceId`/`spanId` | Ready |
| `LogSink` interface (`write`/`flush`/`close`) | Ready |
| Riverpod sink provider pattern | Ready (3 sinks as model) |
| `LogLevel` → OTel `SeverityNumber` mapping | Validated in spike |
| `flutter_secure_storage` | Already in `pubspec.yaml` |
| `connectivity_plus` | Must be added (app layer, injected via callback) |
| `LogRecord.attributes` field | Missing — sub-milestone 12.1 |
| Backend proxy endpoint | Not started — sub-milestone 12.8 |

## Dartastic Review (Feb 2026)

Reviewed `dartastic_opentelemetry` v1.0.0-alpha against our plan.
See full findings in [12-opentelemetry-integration.md § Dartastic Review
Findings](./12-opentelemetry-integration.md#dartastic-review-findings-feb-2026).

**Applied:** typed `AnyValue` mapper, `observedTimeUnixNano`, gzip
compression, `droppedAttributesCount`, `flags` field.

**Deferred:** composite exporter, resource detectors, three-tier config,
W3C trace context propagation (Phase 3).

## Reference

- **Full spec:** [12-opentelemetry-integration.md](./12-opentelemetry-integration.md)
- **Execution plan:** [PLAN-otel.md](./PLAN-otel.md)
- **Logfire endpoint:** `https://logfire-us.pydantic.dev/v1/logs`
- **Auth:** Raw write token in `Authorization` header (no "Bearer" prefix)
