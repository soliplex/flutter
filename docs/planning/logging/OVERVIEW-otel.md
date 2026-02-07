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
| 12.2 | OtelSink core | `OtelExporter` interface, `LogfireExporter`, `ProxyExporter`, OTLP mapper, batch processor, circuit breaker | 12.1 |
| 12.3 | App integration (native) | Telemetry screen, Riverpod providers, `LogfireExporter` on mobile/desktop, lifecycle flush. Web OTel-disabled (CORS). | 12.2 |
| 12.4 | Web proxy (swap exporter) | Backend proxy endpoint, swap web to `ProxyExporter`, enable web OTel, web lifecycle flush | 12.3 |
| 12.5 | Hardening | PII redaction, sampling, rate limiting, backpressure. Can parallelize with 12.3/12.4 (pure Dart). | 12.2 |

## Key Decisions

- **Pluggable exporters** — `OtelSink` owns batching/queuing. Transport is
  delegated to an `OtelExporter` interface with two implementations:
  `LogfireExporter` (direct OTLP/HTTP) and `ProxyExporter` (backend proxy).
  New backends can be added without touching the sink.
- **Proxy for web** — CORS blocks direct OTLP from browser. Backend proxy
  at `/api/v1/telemetry/logs` attaches Logfire token server-side.
- **Raw OTLP/HTTP JSON** — no `dartastic_opentelemetry` dependency. Their
  log SDK is not implemented. Hand-crafted JSON is simpler and validated.
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
| Backend proxy endpoint | Not started — sub-milestone 12.4 |

## Reference

- **Full spec:** [12-opentelemetry-integration.md](./12-opentelemetry-integration.md)
- **Execution plan:** [PLAN-otel.md](./PLAN-otel.md)
- **Logfire endpoint:** `https://logfire-us.pydantic.dev/v1/logs`
- **Auth:** Raw write token in `Authorization` header (no "Bearer" prefix)
