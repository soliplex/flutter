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
| 12.2 | OtelSink core | `OtelExporter` interface, `LogfireExporter`, `ProxyExporter`, OTLP mapper, batch processor | 12.1 |
| 12.3 | App integration (all platforms) | Riverpod provider with platform exporter selection, backend proxy, `LogConfig`, lifecycle flush | 12.2 |
| 12.4 | Hardening | PII redaction, sampling, rate limiting, backpressure | 12.3 |

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

## Codebase Readiness

| Component | Status |
|-----------|--------|
| `LogRecord` with `traceId`/`spanId` | Ready |
| `LogSink` interface (`write`/`flush`/`close`) | Ready |
| Riverpod sink provider pattern | Ready (3 sinks as model) |
| `LogLevel` → OTel `SeverityNumber` mapping | Validated in spike |
| `flutter_secure_storage` | Already in `pubspec.yaml` |
| `connectivity_plus` | Must be added |
| `LogRecord.attributes` field | Missing — sub-milestone 12.1 |
| Backend proxy endpoint | Not started — sub-milestone 12.3a |

## Reference

- **Full spec:** [12-opentelemetry-integration.md](./12-opentelemetry-integration.md)
- **Execution plan:** [PLAN-otel.md](./PLAN-otel.md)
- **Logfire endpoint:** `https://logfire-us.pydantic.dev/v1/logs`
- **Auth:** Raw write token in `Authorization` header (no "Bearer" prefix)
