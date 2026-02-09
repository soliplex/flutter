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
│           ├── console_sink.dart
│           ├── disk_queue.dart         # abstract interface
│           ├── disk_queue_io.dart      # native JSONL impl
│           ├── disk_queue_web.dart     # in-memory web fallback
│           ├── memory_sink.dart
│           └── stdout_sink.dart
└── test/
    └── sinks/
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
