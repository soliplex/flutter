# Milestone 1: Log Record Export Serialization

**Branch**: `feat/log-export-serialization`
**PR title**: `feat(log-viewer): add log record export serialization`
**Depends on**: nothing

## Goal

Ship the pure-Dart serialization layer and controller method. No new
dependencies, no UI changes, no platform code. Independently useful —
`toExportJson()` and `exportFilteredAsJsonlBytes()` can be called
programmatically (debug console, future "attach logs to ticket" feature).

## Changes

### 1. Add `LogRecordExport` extension

**File**: `lib/features/log_viewer/log_record_export.dart` (**new**)

Extension on `LogRecord` — keeps serialization out of the pure logging
package:

```dart
import 'package:soliplex_logging/soliplex_logging.dart';

extension LogRecordExport on LogRecord {
  Map<String, Object?> toExportJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'level': level.name,
    'logger': loggerName,
    'message': message,
    if (attributes.isNotEmpty) 'attributes': _safeAttributes(attributes),
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    if (spanId != null) 'spanId': spanId,
    if (traceId != null) 'traceId': traceId,
  };
}
```

Plus private top-level `_safeAttributes()` / `_coerceValue()` helpers
(~15 lines, same logic as `BackendLogSink`):

```dart
Map<String, Object?> _safeAttributes(Map<String, Object> attributes) {
  if (attributes.isEmpty) return const {};
  final result = <String, Object?>{};
  for (final entry in attributes.entries) {
    result[entry.key] = _coerceValue(entry.value);
  }
  return result;
}

Object? _coerceValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value.map(_coerceValue).toList();
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _coerceValue(v)));
  }
  return value.toString();
}
```

### 2. Add `exportFilteredAsJsonlBytes()` to `LogViewerController`

**File**: `lib/features/log_viewer/log_viewer_controller.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:soliplex_frontend/features/log_viewer/log_record_export.dart';

Uint8List exportFilteredAsJsonlBytes() {
  _flushPending();  // Capture any buffered records
  final buffer = StringBuffer();
  for (final record in _filteredRecords) {
    buffer.writeln(jsonEncode(record.toExportJson()));
  }
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}
```

Key details:

- Calls `_flushPending()` first to capture buffered records (finding #5)
- Uses `Uint8List.fromList(utf8.encode(...))` for correct return type (finding #4)
- Exports chronological order (oldest-first) — standard for log files
- `writeln()` trailing newline is valid POSIX/JSONL convention

## Files

| File | Action |
|------|--------|
| `lib/features/log_viewer/log_record_export.dart` | **New** — extension + helpers |
| `lib/features/log_viewer/log_viewer_controller.dart` | Edit — add `exportFilteredAsJsonlBytes()` |
| `test/features/log_viewer/log_record_export_test.dart` | **New** |
| `test/features/log_viewer/log_viewer_controller_test.dart` | **New** |

## Tests

### `test/features/log_viewer/log_record_export_test.dart`

| Test | What it verifies |
|------|------------------|
| `toExportJson includes all required fields` | Map has timestamp, level, logger, message |
| `timestamp is UTC ISO8601` | Non-UTC input → UTC output string |
| `null optional fields are omitted` | No error/stackTrace/spanId/traceId keys when null |
| `present optional fields are included` | error, stackTrace, spanId, traceId appear when set |
| `empty attributes omitted` | No `attributes` key when map is empty |
| `attributes with primitives pass through` | String, int, double, bool unchanged |
| `attributes with nested maps coerced` | Map keys → String, values recursively coerced |
| `attributes with lists coerced` | List elements recursively coerced |
| `attributes with custom objects use toString` | Non-primitive → `toString()` |
| `error uses toString` | `Exception('foo')` → `'Exception: foo'` |

### `test/features/log_viewer/log_viewer_controller_test.dart`

| Test | What it verifies |
|------|------------------|
| `exportFilteredAsJsonlBytes returns valid JSONL` | Each line parses as JSON, fields match records |
| `respects level filter` | Only filtered-in records appear in output |
| `respects logger exclusion` | Excluded loggers absent from output |
| `respects search query` | Only matching messages in output |
| `empty filtered list returns empty bytes` | `Uint8List` with length 0 |
| `flushes pending records before export` | Record written just before export is included |
| `chronological order preserved` | First line is oldest record |

## Gates

1. `dart format .` — no changes
2. `flutter analyze --fatal-infos` — 0 issues
3. `dart test` in `packages/soliplex_logging/` — passes (no regressions)
4. `flutter test test/features/log_viewer/log_record_export_test.dart` — passes
5. `flutter test test/features/log_viewer/log_viewer_controller_test.dart` — passes
6. `flutter test` — full suite passes
