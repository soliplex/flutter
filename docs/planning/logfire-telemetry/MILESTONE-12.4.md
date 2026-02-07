# Milestone 12.4 — Backend Ingest Endpoint

**Phase:** 1 — Core (P0)\
**Status:** Pending\
**Blocked by:** 12.2\
**Can parallelize with:** 12.3\
**PR:** —

> **Note:** This is a **backend (Python)** milestone. See
> [BACKEND.md](./BACKEND.md) for the full specification.
> No frontend gates apply.

---

## Goal

Python endpoint that receives log JSON from Flutter clients and forwards
to Logfire via the Python OTel SDK.

---

## Backend (~/dev/soliplex)

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

## Response Codes

- **200** — accepted
- **401** — invalid/expired session
- **413** — payload too large
- **429** — rate limited
- **502** — Logfire upstream error

---

## Unit Tests (Python)

- Payload parsed correctly
- OTel mapping produces valid LogRecords
- Auth validation (reject invalid JWT)
- Rate limiting
- Oversized payload rejection

---

## Acceptance Criteria

- [ ] Endpoint accepts Flutter log JSON
- [ ] Server-received timestamp stamped on each record
- [ ] Maps to OTel LogRecords via Python SDK
- [ ] `installId`/`sessionId`/`userId` persisted as attributes
- [ ] Forwards to Logfire (verified in staging)
- [ ] Auth, rate limiting, size limits enforced
- [ ] Tests pass
