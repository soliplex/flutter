# Milestone 12.2 — BackendLogSink

**Phase:** 1 — Core (P0)\
**Status:** Pending\
**Blocked by:** 12.1\
**PR:** —

---

## Goal

A "dumb" sink that persists logs to disk and periodically POSTs them as
JSON to the Soliplex backend. No OTLP mapping — the backend handles
conversion to OTel format. Includes crash hooks, session correlation,
log sanitizer, and disk-backed queue.

---

## Architecture

```text
LogManager (sanitization layer)
├── LogSanitizer (PII redaction — ALL sinks get sanitized data)
│   └── Runs before record is dispatched to any sink
│
BackendLogSink (LogSink)
├── DiskQueue (JSONL write-ahead log)
│   ├── write() → append to file
│   ├── drain() → read + delete confirmed lines
│   └── Survives crashes, OS kills, restarts
├── BatchUploader (periodic HTTP POST)
│   ├── Timer-based flush (30s)
│   ├── Severity-triggered flush (immediate on ERROR/FATAL)
│   ├── Lifecycle flush (app pause/hidden)
│   ├── Basic retry (backoff on 5xx/429, re-enable on new JWT)
│   ├── Poison pill protection (max 3 retries per batch, then discard)
│   └── Byte-based batch cap (< 1 MB payload)
└── SessionContext (injected into every payload)
    ├── installId (UUID, generated once per install, persisted)
    ├── sessionId (UUID, generated on app start)
    └── userId (from auth state)
```

---

## Changes

### LogSanitizer (new file)

**`packages/soliplex_logging/lib/src/log_sanitizer.dart`:**

- `LogSanitizer` class with configurable rules
- **Key redaction:** blocklist of sensitive keys (`password`, `token`,
  `auth`, `authorization`, `secret`, `ssn`, `credential`). Values
  replaced with `[REDACTED]`
- **Pattern scrubbing:** regex patterns for emails, SSNs, bearer tokens,
  IP addresses in message strings
- **Stack trace trimming:** strip absolute file paths to relative
- Configurable: additional keys/patterns can be added at construction
- **Deferred:** Pattern scrubbing on attribute *values* (not just message
  strings). Current scope covers key blocklist + message regex. Extending
  to attribute values is additive — no architectural rework needed.

### LogManager sanitizer integration

**`packages/soliplex_logging/lib/src/log_manager.dart`:**

- Add `LogSanitizer? sanitizer` **property setter** on the singleton.
  `LogManager` uses a `static final` singleton (`LogManager.instance`)
  — you cannot pass constructor arguments. The app layer sets it after
  initialization: `LogManager.instance.sanitizer = LogSanitizer(...)`.
- In `emit()`, if `sanitizer != null`, run
  `record = sanitizer!.sanitize(record)` before dispatching to sinks.
  `sanitize()` returns a **new** `LogRecord` via `copyWith()` (original
  is `@immutable`). All sinks receive the sanitized copy.
  P0: no unsanitized PII reaches any output.

### DiskQueue (new file)

**`packages/soliplex_logging/lib/src/sinks/disk_queue.dart`:**

- Abstract `DiskQueue` interface with `append`, `appendSync`, `drain`,
  `confirm`, `pendingCount`
- **Conditional imports** (like `ConsoleSink` pattern):
  - `disk_queue_io.dart` — JSONL file implementation using `dart:io`
  - `disk_queue_web.dart` — in-memory `List<Map>` fallback (no filesystem)
- `DiskQueueIo` constructor takes `String directoryPath` (app layer
  resolves via `path_provider` — keeps `soliplex_logging` pure Dart)
- `append(Map<String, Object> json)` — async append to file
- `appendSync(Map<String, Object> json)` — **synchronous** file write
  for fatal logs (blocks UI briefly but guarantees crash log hits disk)
- `drain(int count) → List<Map>` — reads up to N records from head.
  **Corruption recovery:** wraps each line's `jsonDecode` in try-catch,
  skips malformed lines (from mid-crash writes). Logs skipped count to
  diagnostics.
- `confirm(int count)` — removes confirmed records from file
- `pendingCount` — number of unsent records
- File rotation: cap at 10 MB, drop oldest on overflow

### BackendLogSink (new file)

**`packages/soliplex_logging/lib/src/sinks/backend_log_sink.dart`:**

- Implements `LogSink`
- Constructor takes:
  - `endpoint` (URL string, e.g. `/api/v1/logs`)
  - `http.Client` (injected by app layer)
  - `installId` (String — per-install UUID, persisted locally)
  - `sessionId` (String)
  - `userId` (String?, nullable for pre-auth)
  - `resourceAttributes` (Map — service.name, version, os, device)
  - `DiskQueue` (injected)
  - Optional `maxBatchBytes` (default 900 KB — stays under 1 MB limit)
  - Optional `batchSize` (default 100), `flushInterval` (default 30s)
  - Optional `networkChecker` (`bool Function()?`)
  - Optional `jwtProvider` (`String? Function()`) — returns current JWT
    or null if not yet authenticated. Flush skips when null.
  - Optional `memorySink` (`MemorySink?`) — injected for breadcrumb
    access on ERROR/FATAL (12.5). Null until Phase 2.

**Pre-auth behavior:** `write()` always appends to `DiskQueue` regardless
of auth state. Logs buffer on disk pre-login. `flush()` skips the HTTP
POST when `jwtProvider` returns null. Once the user authenticates, the
next flush drains the full buffer — startup logs, session marker, and
connectivity events all ship together.

### write(LogRecord)

1. Record is already sanitized by `LogManager` pipeline
2. Build JSON map (not yet encoded):

   ```json
   {
     "timestamp": "2026-02-06T12:00:00.000Z",
     "level": "info",
     "logger": "Auth",
     "message": "User logged in",
     "attributes": {"user_id": "abc123"},
     "error": null,
     "stackTrace": null,
     "spanId": null,
     "traceId": null,
     "installId": "install-uuid",
     "sessionId": "session-uuid",
     "userId": "user-abc"
   }
   ```

3. **Attribute value safety:** before building the JSON map, coerce
   any non-JSON-primitive attribute values to `String` via `.toString()`.
   Only `String`, `num`, `bool`, `null`, `List`, and `Map` pass through
   directly. This prevents `jsonEncode` from throwing at runtime if a
   developer passes a custom object (e.g. `{'user': userObj}`).
4. **Record size guard:** truncate the **Map values** before encoding
   (not after). Check estimated size, truncate in order: `message`,
   `attributes`, `stackTrace`, `error`. Use UTF-8 safe truncation
   (never split multi-byte characters — find last valid char boundary).
5. If FATAL → `DiskQueue.appendSync(map)` (synchronous write —
   guarantees crash log hits disk before process dies)
6. Else → `DiskQueue.append(map)` (async, non-blocking)
7. If ERROR/FATAL → trigger immediate flush

### flush()

1. If `jwtProvider` returns null → skip, keep buffered (pre-auth)
2. If `networkChecker` provided and returns false → skip, keep buffered
3. Drain records from `DiskQueue` up to `batchSize` OR `maxBatchBytes`
   (whichever limit hits first — prevents 413 from backend)
4. POST JSON object to endpoint with `Authorization: Bearer <jwt>`
   (JWT from `jwtProvider`)
5. On 200 → confirm records in queue, reset retry counter
6. On 429/5xx → exponential backoff (1s, 2s, 4s, max 60s), records
   stay in queue for next attempt, increment retry counter
7. On 401/403 → disable export, surface via `onError` callback.
   **Recovery:** if a new JWT is observed (e.g. re-login), re-enable
   export automatically and retry
8. On 404 → treat as permanent failure (endpoint not deployed), disable
   export, surface via `onError`. Re-enable on config change.
9. **Poison pill:** if same batch fails 3 consecutive times → discard
   batch, log diagnostic to `onError`, move to next batch

### close()

- Final flush attempt, cancel timer

### Duplicate log note

If the app crashes after POST succeeds but before `confirm()` removes
records from `DiskQueue`, the next launch will re-send those records.
This is accepted behavior — at-least-once delivery. The backend can
deduplicate by `(installId, sessionId, timestamp, message)` if needed,
but for a logging system duplicates are preferable to lost logs.

### Payload format

```json
{
  "logs": [ "...array of log objects..." ],
  "resource": {
    "service.name": "soliplex-flutter",
    "service.version": "1.0.0",
    "os.name": "android",
    "device.model": "Pixel 7"
  }
}
```

### Dart crash hooks (in sink or app-layer setup)

```dart
PlatformDispatcher.instance.onError = (error, stack) {
  logger.fatal('Uncaught async error', error: error, stackTrace: stack);
  return true;
};

FlutterError.onError = (details) {
  logger.fatal('Flutter framework error',
    error: details.exception, stackTrace: details.stack);
};
```

### Package changes

**`packages/soliplex_logging/pubspec.yaml`:**

- Add `http: ^1.2.0`
- NO `path_provider` — directory path injected by app layer (pure Dart)

**`packages/soliplex_logging/lib/soliplex_logging.dart`:**

- Export `backend_log_sink.dart`, `disk_queue.dart`, `log_sanitizer.dart`
  (`LogSanitizer` is in `lib/src/` not `lib/src/sinks/` since it's
  used by `LogManager`, not just `BackendLogSink`)

### Layering note

`BackendLogSink`, `DiskQueue`, and `LogSanitizer` are **pure Dart**.
`LogSanitizer` is wired into `LogManager` (not `BackendLogSink`) so all
sinks receive sanitized data. All platform concerns are injected by the
app layer: `http.Client`, `directoryPath` (from `path_provider`),
`installId`, `sessionId`, `userId`, `networkChecker`, and
`resourceAttributes`.

---

## Unit Tests

- `test/log_sanitizer_test.dart`:
  - Key redaction (password, token, auth → `[REDACTED]`)
  - Pattern scrubbing (emails, SSNs, bearer tokens in messages)
  - Stack trace path trimming
  - Custom additional keys/patterns
  - Does not modify safe records
- `test/log_manager_sanitizer_test.dart`:
  - LogManager with sanitizer sanitizes before all sinks
  - LogManager without sanitizer passes records unmodified
- `test/sinks/disk_queue_test.dart`:
  - Append + drain round-trip
  - `appendSync` writes synchronously (verify file content immediately)
  - Confirm removes records
  - Survives simulated "crash" (create new instance, read pending)
  - **Corrupted JSONL:** half-written line skipped, valid lines preserved
  - File rotation at size limit
  - `pendingCount` accuracy
  - Web fallback: in-memory queue (conditional import)
- `test/sinks/backend_log_sink_test.dart`:
  - Timer-based flush (advance fake timer)
  - Severity-triggered flush (ERROR → immediate)
  - Records serialized with installId/sessionId/userId
  - Byte-based batch cap (stops draining when payload nears limit)
  - NetworkChecker false → skip flush
  - HTTP 200 → records confirmed
  - HTTP 429/5xx → records stay in queue, backoff
  - Pre-auth: flush skips when jwtProvider returns null
  - Post-auth: buffered pre-login logs drain on first flush
  - HTTP 401 → onError callback, stop retrying, re-enable on new JWT
  - HTTP 404 → onError callback, disable until config change
  - Poison pill: 3 consecutive failures → batch discarded
  - Attribute value safety: non-primitive → `.toString()` before encode
  - Record size guard: Map values truncated before encoding
  - UTF-8 safe truncation (no split multi-byte characters)
  - Fatal records use `appendSync` (synchronous disk write)
  - `close()` attempts final flush
  - Flush race: `append()` immediately followed by `flush()` — record
    either included or safely deferred, never lost

---

## Integration Tests

- `test/integration/backend_sink_pipeline_test.dart` — Logger.info() →
  LogManager → BackendLogSink → mock HTTP client. Verify JSON payload
  includes sessionId, resource attributes, sanitized message.
- `test/integration/backend_sink_crash_recovery_test.dart` — Write
  records to DiskQueue, destroy sink (simulating crash), create new sink
  instance, verify pending records are sent on first flush.
- `test/integration/backend_sink_sanitizer_test.dart` — Log a message
  containing an email and a password attribute. Verify the HTTP payload
  has `[REDACTED]` values and scrubbed message.

---

## Acceptance Criteria

- [ ] `LogSanitizer` redacts sensitive keys and patterns
- [ ] `LogSanitizer` wired into `LogManager` — all sinks get sanitized data
- [ ] `DiskQueue` uses conditional imports (io/web)
- [ ] `DiskQueue` persists records to JSONL file (io) / memory (web)
- [ ] `DiskQueue.appendSync` guarantees disk write for fatal logs
- [ ] `DiskQueue.drain` skips corrupted JSONL lines (crash recovery)
- [ ] Records survive app crash (new instance reads pending)
- [ ] `BackendLogSink` serializes `LogRecord` to simple JSON
- [ ] installId, sessionId, and userId injected into every payload
- [ ] Timer-based and severity-triggered flush
- [ ] Batch capped by bytes (< 1 MB) and record count
- [ ] HTTP 200 confirms records, 429/5xx retries with backoff
- [ ] HTTP 401 disables export, re-enables on new JWT
- [ ] HTTP 404 disables export (endpoint not deployed)
- [ ] Pre-auth logs buffer in DiskQueue, flush after first JWT available
- [ ] NetworkChecker skips flush when offline
- [ ] `close()` drains remaining queue
- [ ] Poison pill: batch discarded after 3 consecutive failures
- [ ] Attribute value safety: non-primitive values coerced via `.toString()`
- [ ] Record size guard: Map values truncated before encoding (not after)
- [ ] UTF-8 safe truncation (no split multi-byte characters)
- [ ] Fatal logs use `appendSync` (synchronous disk write)
- [ ] Dart crash hooks capture uncaught exceptions as fatal logs
- [ ] Integration: crash recovery round-trip
- [ ] Integration: sanitizer scrubs PII from payload

---

## Gates

All gates must pass before the milestone PR can merge.

### Automated

- [ ] **Format:** `dart format --set-exit-if-changed .` — zero changes
- [ ] **Analyze:** `dart analyze` — zero issues (errors, warnings, hints)
- [ ] **Unit tests:** all pass, coverage ≥ 85% for changed files
- [ ] **Integration tests:** all pass

### Gemini Review (up to 3 iterations)

Pass this file and all changed `.dart` source files to Gemini Pro 3
via `mcp__gemini__read_files` (model: `gemini-3-pro-preview`).

- [ ] Gemini passes with no blockers (or issues resolved within 3 iterations)

### Codex Review (up to 3 iterations)

After Gemini passes, submit to Codex for cross-milestone consistency.

- [ ] Codex passes with no blockers (or issues resolved within 3 iterations)
