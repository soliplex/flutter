# OpenTelemetry Integration - Overview

## Goal

Export structured logs from `soliplex_logging` to Logfire (Pydantic) via a
simple backend relay. The Flutter client POSTs JSON to the Soliplex Python
backend, which uses the mature Python OTel SDK to forward logs to Logfire
as OTLP. All platforms (mobile, desktop, web) use the same endpoint.

## Status: Pivoting to Option B (Backend Relay)

The spike validated OTLP/HTTP JSON delivery to Logfire. Architectural
review determined that building a full OTel client in Dart (mapper,
exporters, batch processor, retry, circuit breaker) is not justified for
log-only export. The Python OTel SDK is mature and handles all OTLP
complexity server-side.

**Constraint:** DoD environment — no commercial SaaS (Sentry, Crashlytics,
Datadog). Self-hosted/open-source only. Logfire (Pydantic) is approved.

**Scope:** This is a **pragmatic logging framework for field support** — not
a Crashlytics replacement. The goal is: when a support engineer gets a bug
report from a user in the field, they can query Logfire and reconstruct what
happened. Native crashes (SIGSEGV) and session replay are out of scope.

## Architecture (Option B — Backend Relay)

```text
┌─────────────────────────────────────────────────────┐
│  Flutter App (ALL platforms, including web)          │
│                                                      │
│  Logger.info() ──▶ LogManager ──▶ BackendLogSink     │
│                                    │                 │
│                       ┌────────────┴────────────┐    │
│                       │  DiskQueue (JSONL file)  │    │
│                       │  Write-ahead persistence │    │
│                       └────────────┬────────────┘    │
│                                    │                 │
│                              POST /api/v1/logs       │
│                              (simple JSON array)     │
│                              (session JWT auth)      │
└────────────────────────────────┼─────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  Soliplex Backend (Py)  │
                    │                        │
                    │  Python OTel SDK        │
                    │  ├── OTLP mapping       │
                    │  ├── Batching           │
                    │  ├── Retry              │
                    │  └── Compression        │
                    └────────────┼───────────┘
                                 │
                                 ▼
                              Logfire
```

## Sub-Milestones

### Phase 1 — Core (P0)

| # | Name | Scope | Depends On |
|---|------|-------|------------|
| 12.1 | LogRecord attributes | Add `Map<String, Object> attributes` to `LogRecord`, update `Logger` API | — |
| 12.2 | BackendLogSink | Disk-backed queue, JSON POST, batch flush, basic retry, lifecycle flush, log sanitizer, session/user correlation, Dart crash hooks, poison pill protection, isolate-safe serialization | 12.1 |
| 12.3 | App integration | Riverpod providers, Telemetry screen UI, resource attributes, connectivity listener, session start marker | 12.2 |
| 12.4 | Backend ingest | Python `POST /api/v1/logs` endpoint, OTel SDK forwarding to Logfire | 12.2 |

### Phase 2 — Enhanced Context (P1)

| # | Name | Scope | Depends On |
|---|------|-------|------------|
| 12.5 | Breadcrumbs | Categorized breadcrumbs (ui/network/system) from MemorySink attached to crash/error reports | 12.2 |
| 12.6 | Remote log level | Backend config endpoint, app polls on startup + periodically | 12.3 |
| 12.7 | Error fingerprinting | Backend groups errors by type + top stack frame (Python side) | 12.4 |

### Phase 3 — Diagnostics (P2)

| # | Name | Scope | Depends On |
|---|------|-------|------------|
| 12.8 | RUM / performance | Cold start, slow frames, route timing, HTTP latency metrics | 12.2 |
| 12.9 | Screenshot on error | RepaintBoundary capture, attach to error reports | 12.2 |

## Key Decisions

- **Option B (backend relay)** — Flutter sends simple JSON to own backend.
  Python OTel SDK handles OTLP mapping, batching, retry, compression.
  Eliminates need for custom OTel client in Dart.
- **Disk-backed queue** — logs persist to JSONL file before HTTP send.
  Survives crashes and OS kills. Store-and-forward on next launch.
- **Log sanitizer** — PII/classified data redaction is P0 (DoD
  requirement). Runs before any sink receives the record.
- **Same endpoint all platforms** — no web proxy needed. All platforms
  POST to `/api/v1/logs` with session JWT. No CORS issue.
- **Dart crash hooks** — `FlutterError.onError` and
  `PlatformDispatcher.instance.onError` capture uncaught exceptions.
  Fatal records trigger immediate flush.
- **Session correlation** — UUID session ID + user ID injected into
  every payload. Required for log reconstruction on backend.

## What This Replaces

The previous plan (pre-Option B) built a full OTel client in Dart:
OtelMapper, OtelExporter interface, LogfireExporter, ProxyExporter,
batch processor, retry/circuit breaker, gzip compression. That approach
was over-engineered for log-only export. See commit `84d7950` for the
previous milestone structure.

## Reference

- **Full spec:** [12-opentelemetry-integration.md](./12-opentelemetry-integration.md)
- **Execution plan:** [PLAN-otel.md](./PLAN-otel.md)
- **Logfire endpoint:** `https://logfire-us.pydantic.dev/v1/logs`
- **Auth:** Python backend holds Logfire write token server-side
