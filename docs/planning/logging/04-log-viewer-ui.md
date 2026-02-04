# Milestone 04: Log Viewer UI

**Status:** pending
**Depends on:** 01-essential-logging-api

## Objective

Add `MemorySink` to the logging package and create an in-app log viewer screen
accessible from Settings. This provides on-device log visibility without
requiring file I/O, making it work on all platforms including Web.

## Key Design: Pure Dart MemorySink

Since `soliplex_logging` must remain pure Dart (no Flutter), we use
`StreamController` instead of Flutter's `ChangeNotifier` for live UI updates:

```dart
class MemorySink implements LogSink {
  final _controller = StreamController<LogRecord>.broadcast();

  /// Stream of new log records for UI updates
  Stream<LogRecord> get onRecord => _controller.stream;

  // ... buffer implementation
}
```

The Flutter layer wraps this in a provider that rebuilds on stream events.

## Pre-flight Checklist

- [ ] M01 complete (essential logging API working)
- [ ] Verify `path_provider` is already a dependency in `pubspec.yaml`
- [ ] Review existing settings screen structure
- [ ] Review conditional import pattern in `packages/soliplex_client_native/`

## Files to Create

### Package Additions

- [ ] `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`
- [ ] `packages/soliplex_logging/lib/src/log_formatter.dart`
- [ ] `packages/soliplex_logging/test/memory_sink_test.dart`
- [ ] `packages/soliplex_logging/test/log_formatter_test.dart`

### UI Files

- [ ] `lib/features/logging/log_viewer_screen.dart`
- [ ] `lib/features/logging/widgets/log_entry_tile.dart`
- [ ] `lib/features/logging/widgets/log_filter_bar.dart`
- [ ] `lib/features/logging/widgets/log_export_button.dart`
- [ ] `lib/features/logging/log_export.dart` (conditional export barrel)
- [ ] `lib/features/logging/log_export_stub.dart`
- [ ] `lib/features/logging/log_export_web.dart`
- [ ] `lib/features/logging/log_export_io.dart`
- [ ] `test/features/logging/log_viewer_screen_test.dart`
- [ ] `test/features/logging/widgets/log_entry_tile_test.dart`

## Files to Modify

- [ ] `packages/soliplex_logging/lib/soliplex_logging.dart` - Export new types
- [ ] `lib/core/logging/logging_provider.dart` - Add memorySinkProvider
- [ ] `lib/features/settings/settings_screen.dart` - Add logging section
- [ ] `lib/core/router/app_router.dart` - Add log viewer route

## Implementation Steps

### Step 1: Implement MemorySink

**File:** `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`

- [ ] Implement circular buffer with configurable `maxRecords` (default 2000)
- [ ] Expose `records` as unmodifiable list
- [ ] Implement `clear()` method
- [ ] Remove oldest entry when buffer full
- [ ] Add `StreamController<LogRecord>.broadcast()` for live updates
- [ ] Expose `Stream<LogRecord> get onRecord` for UI subscription
- [ ] Close stream in `close()` method

```dart
class MemorySink implements LogSink {
  final int maxRecords;
  final _records = <LogRecord>[];
  final _controller = StreamController<LogRecord>.broadcast();

  MemorySink({this.maxRecords = 2000});

  List<LogRecord> get records => List.unmodifiable(_records);
  Stream<LogRecord> get onRecord => _controller.stream;

  @override
  void write(LogRecord record) {
    if (_records.length >= maxRecords) {
      _records.removeAt(0);
    }
    _records.add(record);
    _controller.add(record);
  }

  void clear() => _records.clear();

  @override
  Future<void> close() async => _controller.close();
}
```

### Step 2: Implement LogFormatter

**File:** `packages/soliplex_logging/lib/src/log_formatter.dart`

- [ ] Create interface for formatting LogRecord to String
- [ ] Implement default formatter: `[LEVEL] loggerName: message`
- [ ] Include timestamp option
- [ ] Include spanId/traceId if present

### Step 3: Update barrel export

**File:** `packages/soliplex_logging/lib/soliplex_logging.dart`

- [ ] Export MemorySink, LogFormatter

### Step 4: Add memory sink provider

**File:** `lib/core/logging/logging_provider.dart`

- [ ] Create `memorySinkProvider` that:
  - Creates single MemorySink instance
  - Adds it to LogManager on init
  - Uses `ref.keepAlive()` to stay active
  - Exposes sink for UI access
- [ ] Ensure sink is initialized early (watch in ProviderScope or main)
- [ ] On dispose: Remove sink from LogManager, close stream

```dart
final memorySinkProvider = Provider<MemorySink>((ref) {
  final sink = MemorySink();
  LogManager.instance.addSink(sink);

  ref.keepAlive();
  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
    sink.close();
  });

  return sink;
});
```

### Step 5: Create LogEntryTile widget

**File:** `lib/features/logging/widgets/log_entry_tile.dart`

- [ ] Display timestamp, level badge, logger name, message
- [ ] Color-code level badge (error=red, warning=orange, info=blue, debug=gray)
- [ ] Show spanId/traceId if present
- [ ] Show error/stackTrace in expandable section if present

### Step 6: Create LogFilterBar widget

**File:** `lib/features/logging/widgets/log_filter_bar.dart`

- [ ] Horizontal scrollable chips for each LogLevel
- [ ] "All" option to clear level filter
- [ ] Module/loggerName dropdown or chips to filter by source
- [ ] Dynamically populate module list from distinct loggerName values
- [ ] Search text field with debounce
- [ ] Callback for filter changes

### Step 7: Create conditional export files

**CRITICAL: All conditional import files MUST have identical function
signatures.** The stub, web, and io implementations differ only in behavior,
not in API.

**File:** `lib/features/logging/log_export.dart`

```dart
export 'log_export_stub.dart'
    if (dart.library.html) 'log_export_web.dart'
    if (dart.library.io) 'log_export_io.dart';
```

**File:** `lib/features/logging/log_export_stub.dart`

```dart
import 'package:soliplex_logging/soliplex_logging.dart';

/// Exports logs to a file. Returns file path on native, null on web.
/// Throws UnsupportedError on unsupported platforms.
Future<String?> exportLogs(List<LogRecord> records, LogFormatter formatter) {
  throw UnsupportedError('Log export not supported on this platform');
}
```

**File:** `lib/features/logging/log_export_web.dart`

```dart
import 'package:soliplex_logging/soliplex_logging.dart';

/// Exports logs via browser download. Returns null (no file path on web).
Future<String?> exportLogs(List<LogRecord> records, LogFormatter formatter) async {
  // Use dart:html Blob API
  // Create text blob from formatted log records
  // Trigger download: soliplex_logs_<timestamp>.txt
  return null; // Web has no file path
}
```

**File:** `lib/features/logging/log_export_io.dart`

```dart
import 'package:soliplex_logging/soliplex_logging.dart';

/// Exports logs to documents directory. Returns file path.
Future<String?> exportLogs(List<LogRecord> records, LogFormatter formatter) async {
  // Use path_provider to get application documents directory
  // Write formatted log content to soliplex_logs_<timestamp>.txt
  // Return the file path for display to user
}
```

**Signature Requirement:** All three files export:

- `Future<String?> exportLogs(List<LogRecord> records, LogFormatter formatter)`

### Step 8: Create LogExportButton widget

**File:** `lib/features/logging/widgets/log_export_button.dart`

- [ ] IconButton with download icon
- [ ] On tap: get filtered records, call platform export
- [ ] Show snackbar with file path (native) or "Downloaded" (web)
- [ ] Show error snackbar on failure

### Step 9: Create LogViewerScreen

**File:** `lib/features/logging/log_viewer_screen.dart`

- [ ] AppBar with title "Logs" and export button
- [ ] LogFilterBar at top
- [ ] Use StreamBuilder or ref.listen on MemorySink.onRecord for live updates
- [ ] ListView.builder displaying filtered LogRecords
- [ ] Use LogEntryTile for each record
- [ ] Filter by level, module/loggerName, and search text
- [ ] Show empty state when no logs match filter

### Step 10: Add settings integration

**File:** `lib/features/settings/settings_screen.dart`

- [ ] Add "Logging" section divider
- [ ] Add ListTile for "Log Level" with current level subtitle, opens picker
- [ ] Add ListTile for "View Logs" navigating to `/settings/logs`
- [ ] Use ref.watch(logConfigProvider) for current state

### Step 11: Add router integration

**File:** `lib/core/router/app_router.dart`

- [ ] Add route `/settings/logs` pointing to LogViewerScreen
- [ ] Nest under settings branch

### Step 12: Ensure early initialization

**File:** `lib/main.dart` or ProviderScope

- [ ] Watch memorySinkProvider early to ensure it's created before other logging
- [ ] Can use `ref.read(memorySinkProvider)` in a startup callback

### Step 13: Write tests

- [ ] Test MemorySink circular buffer behavior
- [ ] Test MemorySink stream emits on write
- [ ] Test LogFormatter output
- [ ] Test LogEntryTile renders all fields correctly
- [ ] Test LogFilterBar emits filter changes
- [ ] Test LogViewerScreen filters by level
- [ ] Test LogViewerScreen filters by search text
- [ ] Test empty state when no logs

## Export Strategy (No New Dependencies)

This milestone uses **direct file save** without any file picker or share
plugins:

- **Native:** Write to app's documents directory using existing `path_provider`,
  display file path via snackbar
- **Web:** Use `dart:html` Blob API to trigger browser download

No `file_picker`, `share_plus`, or other new plugins required.

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `dart format --set-exit-if-changed packages/soliplex_logging`
- [ ] `dart analyze --fatal-infos packages/soliplex_logging`
- [ ] `dart test packages/soliplex_logging` passes
- [ ] `flutter analyze --fatal-infos`
- [ ] `flutter test` passes
- [ ] Test coverage >= 85% on new code

### Manual Verification

- [ ] Navigate to Settings > View Logs
- [ ] Verify logs appear and update in real-time (stream works)
- [ ] Test level filter works
- [ ] Test search filter works
- [ ] Test export on native (verify file created)
- [ ] Test export on web (verify download triggered)

### Review Gates

- [ ] **Gemini Review:** Run `mcp__gemini__read_files` with model
  `gemini-3-pro-preview` passing:
  - `docs/planning/logging/04-log-viewer-ui.md`
  - `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`
  - `packages/soliplex_logging/lib/src/log_formatter.dart`
  - `lib/features/logging/*.dart`
  - `lib/features/logging/widgets/*.dart`
  - `lib/core/logging/logging_provider.dart`
  - `test/features/logging/*.dart`
- [ ] **Codex Review:** Run `mcp__codex__codex` to analyze implementation

## Success Criteria

- [ ] MemorySink captures logs in circular buffer
- [ ] MemorySink uses StreamController (not ChangeNotifier) - pure Dart
- [ ] Log viewer accessible from Settings > View Logs
- [ ] Level filter shows only matching logs
- [ ] Search filters by message content
- [ ] Export works on all platforms
- [ ] Live updates work (new logs appear via stream)
- [ ] memorySinkProvider uses keepAlive and proper disposal
- [ ] All tests pass
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
