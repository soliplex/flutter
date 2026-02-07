# ADR-002: Backend Log Shipping via Logfire

**Status:** Accepted

**Date:** 2026-02-07

**Branch:** `feat/otel-log-record`

## Context

The Soliplex Flutter client had only local logging (console + in-app log viewer).
Production issues were diagnosed by asking users to reproduce bugs while
screen-sharing or reading console output. This approach fails when:

- The app crashes (logs lost with the process)
- The user is offline or on a flaky connection (logs never seen)
- Support engineers need historical context across sessions and devices
- Government deployments require audit trails

We needed centralized, persistent log shipping that works within our
self-hosted DoD-compliant environment (no commercial SaaS).

## Decisions

### 1. Ship Logs to Logfire via the Python Backend

**Decision:** Flutter client POSTs log batches to `/api/v1/logs` on the
existing Python backend, which maps them to OTel and forwards to Logfire.

**Rationale:**

- Logfire write token stays server-side (no credential exposure in client)
- Backend can enrich logs with server-side context (server-received timestamp,
  rate limiting, payload validation)
- Reuses existing auth infrastructure (session JWT)
- Single observability backend for both server and client telemetry

**Trade-off:** Adds a network hop. Acceptable because logs are not
latency-sensitive and batching amortizes overhead.

### 2. Disk-Backed Queue for At-Least-Once Delivery

**Decision:** Buffer log records in a JSONL write-ahead log (`DiskQueue`)
before HTTP upload. Records are only removed after a 200 response.

**Rationale:**

- Apps crash, networks fail, users kill processes. Disk persistence guarantees
  logs survive all of these.
- At-least-once semantics: duplicates are preferable to missing data.
  Server-side deduplication handles the rest.
- FATAL logs write synchronously (brief UI block) to guarantee they hit disk
  before process death.

**Trade-off:** Disk I/O overhead and 10 MB file rotation. Acceptable for a
logging system that writes infrequently relative to UI frames.

### 3. Batched Upload with Exponential Backoff

**Decision:** Flush logs in batches (max 100 records / 900 KB) on a 30-second
timer, with immediate flush on ERROR/FATAL and on app lifecycle pause.

**Rationale:**

- Batching reduces HTTP overhead and backend load
- Severity-triggered flush ensures errors are visible in near-real-time
- Lifecycle flush prevents data loss on app backgrounding
- Exponential backoff (1s to 60s) with poison-pill discard (3 retries)
  prevents infinite loops on malformed data or prolonged outages

### 4. No Client-Side Log Sanitization

**Decision:** Do not implement PII pattern scrubbing (emails, SSNs, tokens) in
the Flutter client. Sanitization is handled server-side in the Python backend
and Logfire.

**Rationale:**

- The client cannot anticipate all domain-specific PII patterns
- Server-side scrubbing is more flexible and centrally configurable
- Logfire already provides scrubbing capabilities out of the box
- Fewer regex operations on the client means less CPU in the UI thread

**Trade-off:** Raw log payloads transit the network before scrubbing. Acceptable
because the connection is authenticated (JWT) and the backend is self-hosted
within the same trust boundary.

### 5. OTel-Style Attributes for Session Correlation

**Decision:** Attach structured attributes to every log record: `installId`,
`sessionId`, plus resource attributes (app version, OS, device model).

**Rationale:**

- `installId` (stable UUID per install) identifies the device across sessions
- `sessionId` (new UUID per launch) groups logs within a single app run
- Resource attributes enable filtering in Logfire by OS, version, etc.
- Follows OTel semantic conventions for future compatibility

### 6. Pure Dart Logging Package

**Decision:** All log shipping logic lives in `packages/soliplex_logging/`
with no Flutter dependency. Platform-specific `DiskQueue` implementations use
conditional imports (`dart:io` vs web fallback).

**Rationale:**

- Testable without Flutter test harness
- Reusable in non-Flutter Dart projects
- Matches existing package separation (`soliplex_client` is also pure Dart)

## Consequences

### Positive

- Crash logs, pre-auth events, and historical sessions are all preserved
- Support engineers can query by installId/sessionId in Logfire
- No client-side credential exposure (Logfire token stays on server)
- PII scrubbing is centrally managed, not scattered across clients

### Negative

- Network dependency: logs are delayed until connectivity is available
- Disk usage: up to 10 MB of buffered logs per device
- Backend must implement `/api/v1/logs` endpoint and OTel mapping

### Neutral

- Log viewer screen continues to work independently (reads from MemorySink)
- Existing console logging is unaffected
