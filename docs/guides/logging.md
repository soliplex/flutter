# Logging Architecture Guide

How the `soliplex_logging` package persists and ships log records.

## Package Structure

```
packages/soliplex_logging/
├── lib/
│   ├── soliplex_logging.dart          # barrel exports
│   └── src/
│       ├── log_level.dart
│       ├── log_manager.dart
│       ├── log_record.dart
│       ├── log_sink.dart
│       ├── logger.dart
│       └── sinks/
│           ├── backend_log_sink.dart   # HTTP shipping sink
│           ├── console_sink.dart
│           ├── disk_queue.dart         # abstract interface
│           ├── disk_queue_io.dart      # native JSONL impl
│           ├── disk_queue_web.dart     # in-memory web fallback
│           ├── memory_sink.dart
│           └── stdout_sink.dart
└── test/
    ├── integration/
    │   └── backend_sink_pipeline_test.dart
    └── sinks/
        ├── backend_log_sink_test.dart
        └── disk_queue_test.dart
```

## DiskQueue

Persistent write-ahead log for log records. Records survive crashes — a new
`DiskQueue` instance pointed at the same directory picks up where the
previous one left off.

### Platform behavior

| Platform | Storage | Survives crash |
|----------|---------|----------------|
| Native (iOS, Android, macOS, Linux, Windows) | JSONL file on disk | Yes |
| Web | In-memory `Queue<Map>` | No (lost on page refresh) |

Platform selection is automatic via conditional imports:

```dart
// disk_queue.dart
import 'disk_queue_io.dart'
    if (dart.library.js_interop) 'disk_queue_web.dart' as platform;
```

### API

```dart
final queue = DiskQueue(directoryPath: '/path/to/logs');

// Async append (normal logs)
await queue.append({'msg': 'hello', 'level': 'info'});

// Sync append (fatal logs — blocks until written)
queue.appendSync({'msg': 'crash', 'level': 'fatal'});

// Read up to N records from the head
final records = await queue.drain(100);

// Remove N confirmed records from the head
await queue.confirm(records.length);

// Check pending count
final count = await queue.pendingCount;

await queue.close();
```

### On-disk layout

```
<directoryPath>/
├── log_queue.jsonl           # main queue (one JSON object per line)
├── log_queue_fatal.jsonl     # fatal-only writes (appendSync)
└── .fatal_merge.jsonl        # transient: exists only during merge
```

- **`log_queue.jsonl`** — main queue file. All async appends and merged
  fatal records end up here.
- **`log_queue_fatal.jsonl`** — written synchronously by `appendSync`.
  Merged into the main file on the next `drain` call.
- **`.fatal_merge.jsonl`** — intermediate file created during the atomic
  rename of the fatal file. Cleaned up automatically; if found on startup,
  it means a previous crash interrupted a merge and will be recovered.

### Concurrency model

All async operations (`append`, `drain`, `confirm`, `pendingCount`) are
serialized through a `_writeLock` future chain. This prevents file corruption
from concurrent writes without requiring a mutex.

`appendSync` writes to a **separate** fatal file, so it never contends with
the async lock. The fatal file is merged into the main queue via atomic
rename during `drain`:

```
appendSync → _fatalFile
                ↓ (rename to .fatal_merge.jsonl)
drain → _mergeFatalFile → append to _file → delete merge file
```

### File rotation

When the main queue file exceeds 10 MB (`_maxFileBytes`), the oldest half
of records is dropped. This is a simple halving strategy — no separate
rotated files.

### Corruption handling

Corrupted JSONL lines (from mid-crash writes) are silently skipped during
`drain`. Non-Map JSON values (arrays, strings, numbers) are also skipped.
Skipped line counts are logged via `dart:developer`.

### Stream-based reading

`drain`, `confirm`, and `pendingCount` read the queue file via a streaming
`LineSplitter` transform instead of loading the entire file into memory.
This keeps memory usage bounded even for a full 10 MB queue file.

```dart
Stream<String> _readLinesStream() {
  return _file
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
}
```

## BackendLogSink

HTTP shipping sink that writes records to `DiskQueue` first, then
periodically POSTs them as JSON batches to the Soliplex backend.

### Data flow

```
LogRecord → write() → DiskQueue.append / appendSync
                            ↓
              Timer (30s) or ERROR/FATAL trigger
                            ↓
                        flush()
                            ↓
              ┌─ jwtProvider == null? → buffer (skip flush)
              ├─ networkChecker == false? → skip
              ├─ backoffUntil in future? → skip
              └─ drain → capByBytes → POST /v1/logs
                                          ↓
                          200 → confirm records from queue
                      401/403 → disable (re-enable on new JWT)
                          404 → disable permanently
                    429/5xx → exponential backoff + jitter
                 50 failures → poison pill (discard batch)
```

### Construction

```dart
final sink = BackendLogSink(
  endpoint: 'https://api.example.com/v1/logs',
  client: httpClient,
  installId: installUuid,        // stable per device
  sessionId: sessionUuid,        // new each app launch
  diskQueue: DiskQueue(directoryPath: queueDir),
  userId: currentUser?.id,       // null before auth
  resourceAttributes: {
    'service.name': 'soliplex-flutter',
    'service.version': appVersion,
  },
  jwtProvider: () => authService.currentJwt,
  networkChecker: () => connectivity.hasNetwork,
  onError: (msg, err) => log.warning(msg),
);
```

### Pre-auth buffering

When `jwtProvider` is set but returns `null`, `flush()` is a no-op. Records
accumulate in `DiskQueue` on disk. Once `jwtProvider` returns a token, the
next flush ships all buffered pre-login logs together.

If the sink is disabled by an auth error (401/403) and a **new** JWT appears
(different from the previous one), the sink re-enables itself automatically.
A 404 (endpoint not found) disables the sink permanently — no JWT change
will re-enable it.

### Record serialization

Each `LogRecord` is serialized to a JSON map with these fields:

| Field | Source |
|-------|--------|
| `timestamp` | `record.timestamp` (UTC ISO 8601) |
| `level` | `record.level.name` |
| `logger` | `record.loggerName` |
| `message` | `record.message` |
| `attributes` | `record.attributes` (coerced to JSON-safe types) |
| `error` | `record.error?.toString()` |
| `stackTrace` | `record.stackTrace?.toString()` |
| `spanId` / `traceId` | from record (optional) |
| `installId` / `sessionId` / `userId` | from sink constructor |

Non-primitive attribute values (custom objects) are coerced to strings.
Lists and Maps are preserved recursively.

### Size limits

| Limit | Value | Behavior |
|-------|-------|----------|
| Max record size | 64 KB | Fields truncated: message → stackTrace → error → attributes cleared |
| Max batch payload | 900 KB | Records capped per-batch; oversized single records discarded |
| Max records per batch | 100 | Remaining records stay in queue for next flush |

Truncation is UTF-8 safe — multi-byte characters are never split mid-sequence.
Size checks use `utf8.encode().length` for byte accuracy.

### Retry and backoff

On 429 or 5xx responses (or network errors), records stay in the queue and
the sink enters exponential backoff:

- Base delay: 1s, 2s, 4s, 8s, ... capped at 60s
- Jitter: +0–1000ms random per attempt (decorrelates retries)
- **Poison pill**: after 50 consecutive failures, the batch is discarded via
  `onError` to prevent a single bad batch from blocking the queue forever

### Severity-triggered flush

`ERROR` and `FATAL` records trigger an immediate `flush()` call (in addition
to the periodic timer). A concurrency guard (`_isFlushing`) prevents
duplicate HTTP requests when the timer and severity trigger fire
simultaneously.

### Fatal records

`FATAL` logs bypass the async `DiskQueue.append` path and use
`DiskQueue.appendSync` instead, blocking the caller until the record is
fsynced to disk. This guarantees the record survives even if the process
dies immediately after.

## Testing BackendLogSink

Tests live in `test/sinks/backend_log_sink_test.dart` (24 tests).

### Running tests

```bash
cd packages/soliplex_logging
dart test test/sinks/backend_log_sink_test.dart
```

### Test setup pattern

Tests use a `MockClient` from `package:http/testing.dart` and a real
`PlatformDiskQueue` backed by a temp directory:

```dart
late Directory tempDir;
late PlatformDiskQueue diskQueue;
late List<http.Request> capturedRequests;
late http.Client mockClient;
var httpStatus = 200;

setUp(() {
  tempDir = Directory.systemTemp.createTempSync('backend_sink_test_');
  diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
  capturedRequests = [];
  httpStatus = 200;

  mockClient = http_testing.MockClient((request) async {
    capturedRequests.add(request);
    return http.Response('', httpStatus);
  });
});
```

### What's covered

| Test | What it verifies |
|------|------------------|
| records serialized with installId/sessionId/userId | Envelope fields present |
| resource attributes included in payload | Resource envelope |
| HTTP 200 confirms records | Queue drains on success |
| HTTP 429 keeps records in queue with backoff | Retryable error handling |
| HTTP 5xx keeps records in queue | Server error handling |
| HTTP 401 disables export and calls onError | Auth failure disable |
| HTTP 404 disables export and calls onError | Missing endpoint disable |
| pre-auth: flush skips when jwtProvider returns null | Buffering before login |
| post-auth: buffered pre-login logs drain on first flush | Pre-auth drain |
| networkChecker false skips flush | Offline handling |
| poison pill: batch discarded after 50 failures | Queue unblocking |
| attribute value safety: non-primitive coerced to string | Type coercion |
| fatal records use appendSync | Sync write path |
| close attempts final flush | Graceful shutdown |
| severity-triggered flush on ERROR | Immediate flush |
| JWT included in Authorization header | Auth header |
| re-enables after new JWT on 401 | Auth recovery |
| byte-based batch cap limits records per batch | Batch size limit |
| oversized single record is discarded and reported | C1 fix validation |
| concurrent flush calls are deduplicated | C2 fix validation |
| network error triggers retry with backoff | Network error handling |
| coerces List and Map attribute values | Nested type coercion |
| record size guard truncates oversized messages | Truncation |
| UTF-8 safe truncation does not split multi-byte chars | Multi-byte safety |

### Testing backoff manually

To test backoff behavior, clear `backoffUntil` between flushes to simulate
time passing:

```dart
test('poison pill after 50 failures', () async {
  httpStatus = 500;
  final sink = createSink(onError: (msg, _) => errorMessage = msg)
    ..write(makeRecord());

  for (var i = 0; i < 50; i++) {
    sink.backoffUntil = null; // simulate time passing
    await sink.flush();
  }

  expect(errorMessage, contains('poison pill'));
  expect(await diskQueue.pendingCount, 0);
});
```

## Testing DiskQueue

Tests live in `test/sinks/disk_queue_test.dart` (12 tests).

### Running tests

```bash
cd packages/soliplex_logging
dart test test/sinks/disk_queue_test.dart
```

### Test patterns

All tests use temporary directories that are cleaned up in `tearDown`:

```dart
late Directory tempDir;
late PlatformDiskQueue queue;

setUp(() {
  tempDir = Directory.systemTemp.createTempSync('disk_queue_test_');
  queue = PlatformDiskQueue(directoryPath: tempDir.path);
});

tearDown(() async {
  await queue.close();
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
});
```

### What's covered

| Test | What it verifies |
|------|------------------|
| append and drain round-trip | Basic read/write cycle |
| appendSync writes to fatal file | Sync write hits disk immediately |
| appendSync records merge into drain | Fatal merge works on next drain |
| confirm removes records | Head-of-queue removal |
| survives simulated crash | New instance reads previous data |
| corrupted JSONL line is skipped | Graceful corruption handling |
| non-Map JSON values are skipped | Only `Map<String, Object?>` accepted |
| pendingCount is accurate | Count tracks appends and confirms |
| drain returns empty list when no records | Empty queue edge case |
| drain respects count limit | Partial reads |
| file rotation drops oldest | 10 MB rotation threshold |
| concurrent appends are serialized | No data loss under concurrency |

### Testing crash recovery

To test crash recovery, close a queue instance without flushing, then create
a new instance pointing at the same directory:

```dart
test('survives simulated crash', () async {
  await queue.append({'msg': 'before-crash'});
  await queue.close();

  final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
  final records = await newQueue.drain(10);
  expect(records, hasLength(1));
  expect(records[0]['msg'], 'before-crash');
  await newQueue.close();
});
```

### Testing with pre-seeded files

To test corruption handling or specific queue states, write directly to the
JSONL file before draining:

```dart
test('corrupted JSONL line is skipped', () async {
  final file = File('${tempDir.path}/log_queue.jsonl');
  await file.writeAsString(
    '{"msg":"valid1"}\n'
    'this is not json\n'
    '{"msg":"valid2"}\n',
  );

  final records = await queue.drain(10);
  expect(records, hasLength(2));
});
```
