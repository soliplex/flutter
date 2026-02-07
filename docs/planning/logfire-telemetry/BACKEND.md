# Backend Requirements — Logfire Log Ingest

## Purpose

This document specifies what the Soliplex Python backend team needs to
implement to support the Flutter logging framework. The Flutter app POSTs
simple JSON to these endpoints; the backend handles OTel mapping and
Logfire forwarding.

**Repo:** `~/dev/soliplex`

---

## Phase 1 — Log Ingest (Milestone 12.4)

### `POST /api/v1/logs`

Receives structured log JSON from the Flutter app and forwards to Logfire
via the Python OTel SDK.

#### Request

```text
POST /api/v1/logs
Content-Type: application/json
Authorization: Bearer <session-jwt>
```

#### Request Body

```json
{
  "logs": [
    {
      "timestamp": "2026-02-06T12:00:00.000Z",
      "level": "info",
      "logger": "Auth",
      "message": "User logged in",
      "attributes": {"user_id": "abc123", "http_status": 200},
      "error": null,
      "stackTrace": null,
      "spanId": null,
      "traceId": null,
      "installId": "install-uuid",
      "sessionId": "session-uuid",
      "userId": "user-abc"
    }
  ],
  "resource": {
    "service.name": "soliplex-flutter",
    "service.version": "1.0.0",
    "os.name": "android",
    "device.model": "Pixel 7"
  }
}
```

#### Field Types

| Field | Type | Notes |
|-------|------|-------|
| `timestamp` | ISO 8601 string | Client device time (may have clock skew) |
| `level` | string | `trace`, `debug`, `info`, `warning`, `error`, `fatal` |
| `logger` | string | Logger name (e.g. `Auth`, `Http`, `Router`) |
| `message` | string | Log message (already PII-scrubbed by client) |
| `attributes` | object | Key-value pairs, plain JSON types (string, number, bool, array, object) |
| `error` | string or null | Error type/message |
| `stackTrace` | string or null | Dart stack trace |
| `spanId` | string or null | Hex (16 chars), only if tracing active |
| `traceId` | string or null | Hex (32 chars), only if tracing active |
| `installId` | string | Per-install UUID (stable across sessions) |
| `sessionId` | string | Per-session UUID (new each app launch) |
| `userId` | string or null | Null for pre-auth logs |

#### Processing Steps

1. **Validate JWT** from `Authorization: Bearer <jwt>` header
2. **Reject** if payload > 1 MB (respond 413)
3. **Rate limit** per-user/per-session (respond 429 if exceeded)
4. **Stamp server-received timestamp** on each record:
   `server_received_at = datetime.utcnow()`. Persist both client
   `timestamp` and `server_received_at` as OTel attributes. This
   handles clock skew on field devices with manual/incorrect time.
5. **Map each log** to OTel `LogRecord` using `opentelemetry-sdk`:

   | Client field | OTel field | Conversion |
   |-------------|-----------|------------|
   | `timestamp` | `timeUnixNano` | Parse ISO → nanoseconds |
   | `server_received_at` | attribute `server.received_at` | Server UTC |
   | `level` | `severityNumber` | See mapping below |
   | `level` | `severityText` | Direct string |
   | `message` | `body` (stringValue) | Direct |
   | `logger` | `InstrumentationScope.name` | Direct |
   | `attributes` | OTel attributes | Python SDK handles typed mapping |
   | `error` | `exception.type`, `exception.message` | OTel semantic conventions |
   | `stackTrace` | `exception.stacktrace` | OTel semantic conventions |
   | `installId` | attribute `install.id` | Direct |
   | `sessionId` | attribute `session.id` | Direct |
   | `userId` | attribute `user.id` | Direct (may be null) |

6. **Forward to Logfire** via `OTLPLogExporter` (Python SDK handles
   batching, retry, compression, OTLP compliance)

#### Level → SeverityNumber Mapping

| Level | SeverityNumber | SeverityText |
|-------|---------------|--------------|
| trace | 1 | TRACE |
| debug | 5 | DEBUG |
| info | 9 | INFO |
| warning | 13 | WARN |
| error | 17 | ERROR |
| fatal | 21 | FATAL |

#### Response Codes

| Code | Meaning | Client behavior |
|------|---------|----------------|
| 200 | Accepted | Client confirms records, removes from queue |
| 401 | Invalid/expired JWT | Client disables export, re-enables on re-login |
| 404 | Endpoint not found | Client disables export |
| 413 | Payload too large | Client should not send >1 MB batches |
| 429 | Rate limited | Client backs off (1s, 2s, 4s, max 60s) |
| 502 | Logfire upstream error | Client backs off |

#### Duplicate Delivery

The Flutter client uses at-least-once delivery. If the app crashes after
the backend returns 200 but before the client confirms, the same logs
will be re-sent on next launch. The backend can optionally deduplicate
by `(installId, sessionId, timestamp, message)` but this is not required
— duplicate logs are preferable to lost logs.

#### Dependencies (Python)

- `opentelemetry-sdk`
- `opentelemetry-exporter-otlp-proto-http` (or equivalent)
- `logfire` Python package (optional — direct OTLP works)

#### Configuration

- `LOGFIRE_TOKEN` — Logfire write token (server-side only, never sent
  to Flutter client)
- `LOGFIRE_ENDPOINT` — `https://logfire-us.pydantic.dev` (default)
- Rate limit thresholds (per-user, per-session)
- Max payload size (default 1 MB)

#### Unit Tests

- Payload parsed correctly (all field types)
- OTel mapping produces valid LogRecords
- `server_received_at` stamped on each record
- `installId`/`sessionId`/`userId` persisted as attributes
- Auth validation (reject invalid/expired JWT)
- Rate limiting (429 after threshold)
- Oversized payload rejection (413)
- Null `userId` handled (pre-auth logs)
- Logfire forwarding verified (mock or staging)

#### Acceptance Criteria

- [ ] Endpoint accepts Flutter log JSON
- [ ] Server-received timestamp stamped on each record
- [ ] Maps to OTel LogRecords via Python SDK
- [ ] `installId`/`sessionId`/`userId` persisted as attributes
- [ ] Forwards to Logfire (verified in staging)
- [ ] Auth, rate limiting, size limits enforced
- [ ] Null userId handled (pre-auth logs)
- [ ] Tests pass

---

## Phase 2 — Breadcrumbs in Error Payloads (Milestone 12.5)

When the Flutter client sends an ERROR or FATAL log, it may include a
`breadcrumbs` array — the last 20 log records leading up to the error.
This gives support engineers the context to understand what happened.

### Payload Extension

Error/fatal log records include an additional `breadcrumbs` field:

```json
{
  "logs": [
    {
      "timestamp": "2026-02-06T12:00:05.000Z",
      "level": "error",
      "logger": "Http",
      "message": "Request failed: 500",
      "attributes": {"url": "/api/v1/chat", "status": 500},
      "error": "HttpException",
      "stackTrace": "...",
      "spanId": null,
      "traceId": null,
      "installId": "install-uuid",
      "sessionId": "session-uuid",
      "userId": "user-abc",
      "breadcrumbs": [
        {
          "timestamp": "2026-02-06T11:59:50.000Z",
          "level": "info",
          "logger": "Router",
          "message": "Navigated to /chat",
          "category": "ui"
        },
        {
          "timestamp": "2026-02-06T11:59:55.000Z",
          "level": "info",
          "logger": "Http",
          "message": "POST /api/v1/chat",
          "category": "network"
        }
      ]
    }
  ],
  "resource": { "...": "..." }
}
```

### Breadcrumb Fields

| Field | Type | Notes |
|-------|------|-------|
| `timestamp` | ISO 8601 string | When the breadcrumb was logged |
| `level` | string | Log level of the breadcrumb |
| `logger` | string | Logger name |
| `message` | string | Log message (already PII-scrubbed) |
| `category` | string | `ui`, `network`, `system`, or `user` |

### Backend Handling

- `breadcrumbs` is **optional** — only present on error/fatal records
- If present, persist as an OTel attribute (`breadcrumbs` JSON string)
  or as individual linked log records (implementation choice)
- Non-error records will have `breadcrumbs: null` or the field absent

### Acceptance Criteria

- [ ] Backend accepts `breadcrumbs` field on log records (optional)
- [ ] Breadcrumbs persisted and queryable in Logfire
- [ ] Non-error records without breadcrumbs handled gracefully

---

## Phase 2 — Remote Log Level (Milestone 12.6)

### `GET /api/v1/config/logging`

Returns the current log level configuration. The Flutter app polls this
on startup and every 10 minutes.

#### Response

```json
{
  "min_level": "debug",
  "modules": {"http": "trace", "auth": "debug"}
}
```

| Field | Type | Notes |
|-------|------|-------|
| `min_level` | string | Global minimum: `trace`, `debug`, `info`, `warning`, `error`, `fatal` |
| `modules` | object | Per-logger overrides (key = logger name, value = level) |

#### Behavior

- If endpoint is unreachable, the Flutter app uses its local defaults
- No auth required (config is not sensitive) — or use same JWT if preferred
- Configuration can be stored in database or config file
- Changes take effect within 10 minutes (next poll interval)

#### Acceptance Criteria

- [ ] Returns valid JSON with `min_level` and `modules`
- [ ] Configurable via admin interface or config file
- [ ] Returns sensible defaults if not configured

---

## Phase 2 — Error Fingerprinting (Milestone 12.7)

### Purpose

Group identical errors so operators see "Top 5 errors" instead of
thousands of individual log entries.

#### Processing (in the 12.4 ingest pipeline)

When a log record has `level` = `error` or `fatal`:

1. Extract `error` (exception type) and top 3 frames from `stackTrace`
2. Compute fingerprint: `sha256(exception_type + top_3_stack_frames)`
3. Store fingerprint + count in database (per time window)
4. Add `error.fingerprint` as an OTel attribute on the Logfire record

#### Logfire Querying

Support engineers can query Logfire:

```sql
SELECT error.fingerprint, count(*) as occurrences
FROM logs
WHERE severity >= ERROR
GROUP BY error.fingerprint
ORDER BY occurrences DESC
LIMIT 10
```

#### Optional: Alerting

When error count for a fingerprint exceeds a threshold in a time window,
trigger an alert (email, webhook, etc.). Implementation details TBD.

#### Acceptance Criteria

- [ ] Errors grouped by fingerprint
- [ ] Count tracked per fingerprint per time window
- [ ] Fingerprint visible in Logfire attributes
- [ ] Optional alerting when threshold exceeded

---

## Summary — What the Backend Team Needs to Build

| Priority | Milestone | Endpoint | Effort |
|----------|-----------|----------|--------|
| P0 | 12.4 | `POST /api/v1/logs` | Medium — OTel SDK does the heavy lifting |
| P1 | 12.5 | Breadcrumbs (in 12.4 payload) | Small — optional field on error records |
| P1 | 12.6 | `GET /api/v1/config/logging` | Small — config endpoint |
| P1 | 12.7 | Error fingerprinting (in 12.4 pipeline) | Medium — hashing + storage |

### Key Constraints

- **Self-hosted environment** — no commercial SaaS. Logfire (Pydantic) is approved.
- **Logfire write token** stays server-side. Never sent to Flutter client.
- **All platforms** (mobile, desktop, web) use the same endpoint.
- **At-least-once delivery** — expect occasional duplicate logs.
- **Clock skew** — always use `server_received_at` for time-based queries,
  not client `timestamp`.
