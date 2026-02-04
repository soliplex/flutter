# Milestone 06: Advanced IO Persistence

**Status:** pending
**Depends on:** 01-essential-logging-api

## Objective

Create the `soliplex_logging_io` package with file-based logging sink that
supports rotation and compression. Integrate it with the existing providers
using conditional imports for web compatibility.

**Note:** This milestone modifies app-layer files (providers, config, settings)
to integrate the new FileSink. The type-safe `Loggers.x` API remains unchanged.

## Pre-flight Checklist

- [ ] M01 complete (essential logging API working)
- [ ] Understand file rotation requirements: 5MB max, 5 files max
- [ ] Review conditional import pattern in `packages/soliplex_client_native/`

## Files to Create

### Package Files

- [ ] `packages/soliplex_logging_io/pubspec.yaml`
- [ ] `packages/soliplex_logging_io/analysis_options.yaml`
- [ ] `packages/soliplex_logging_io/lib/soliplex_logging_io.dart`
- [ ] `packages/soliplex_logging_io/lib/src/file_sink.dart`
- [ ] `packages/soliplex_logging_io/lib/src/log_compressor.dart`
- [ ] `packages/soliplex_logging_io/test/file_sink_test.dart`
- [ ] `packages/soliplex_logging_io/test/log_compressor_test.dart`

### App Integration Files

- [ ] `lib/core/logging/file_sink_provider.dart` (conditional import barrel)
- [ ] `lib/core/logging/file_sink_stub.dart`
- [ ] `lib/core/logging/file_sink_io.dart`

## Files to Modify

- [ ] `pubspec.yaml` - Add soliplex_logging_io dependency
- [ ] `lib/core/logging/logging_provider.dart` - Add fileSinkProvider
- [ ] `lib/core/logging/log_config.dart` - Add fileLoggingEnabled
- [ ] `lib/features/settings/settings_screen.dart` - Add file logging toggle

## Implementation Steps

### Step 1: Create package structure

**File:** `packages/soliplex_logging_io/pubspec.yaml`

- [ ] Create pubspec with name `soliplex_logging_io`
- [ ] Set SDK constraint `^3.6.0`
- [ ] Add dependency on `soliplex_logging` (path: ../soliplex_logging)
- [ ] Add `synchronized: ^3.1.0` for thread-safe file access
- [ ] Add `path: ^1.9.0` for cross-platform paths
- [ ] Add dev_dependencies: `test: ^1.24.0`, `very_good_analysis: ^7.0.0`

### Step 2: Implement FileSink

**File:** `packages/soliplex_logging_io/lib/src/file_sink.dart`

- [ ] Accept `directory`, `maxFileSize` (5MB default), `maxFileCount` (5),
  `filePrefix`
- [ ] Implement `initialize()` to create directory and open file
- [ ] Use ISO timestamp (with `:` replaced by `-`) for filenames
- [ ] Implement `write()` with async buffering (use synchronized for safety)
- [ ] Implement rotation: create new file when size exceeded
- [ ] Implement pruning: delete oldest files when count exceeded
- [ ] Implement `getLogFiles()` returning sorted list
- [ ] Implement `getAllLogsContent()` concatenating all files
- [ ] Implement `getCompressedLogs()` returning gzipped bytes
- [ ] Use `package:path` for cross-platform path handling

### Step 3: Implement LogCompressor

**File:** `packages/soliplex_logging_io/lib/src/log_compressor.dart`

- [ ] Implement `compress(String content)` using `dart:io` gzip codec
- [ ] Implement `compressFiles(List<File>)` combining files with headers
- [ ] Return `Uint8List` of compressed bytes

### Step 4: Create barrel export

**File:** `packages/soliplex_logging_io/lib/soliplex_logging_io.dart`

- [ ] Export FileSink and LogCompressor
- [ ] Re-export soliplex_logging for convenience

### Step 5: Add package dependency

**File:** `pubspec.yaml`

- [ ] Add `soliplex_logging_io: path: packages/soliplex_logging_io`

### Step 6: Create conditional file sink files

**CRITICAL: All conditional import files MUST have identical function
signatures.** The stub and io implementations differ only in behavior, not
in API.

**File:** `lib/core/logging/file_sink_provider.dart`

```dart
export 'file_sink_stub.dart'
    if (dart.library.io) 'file_sink_io.dart';
```

**File:** `lib/core/logging/file_sink_stub.dart`

```dart
import 'dart:typed_data';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Creates a file sink. Returns null on web platform.
Future<LogSink?> createFileSink({
  required String logDirectory,
  int maxFileSize = 5 * 1024 * 1024,
  int maxFileCount = 5,
}) async {
  // Web platform - no file I/O available
  return null;
}

/// Gets compressed logs from a file sink.
/// Returns empty bytes on web platform.
Future<Uint8List> getCompressedLogs(LogSink? sink) async {
  // Web platform - no file logs
  return Uint8List(0);
}
```

**File:** `lib/core/logging/file_sink_io.dart`

```dart
import 'dart:typed_data';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_logging_io/soliplex_logging_io.dart';

/// Creates a file sink. Returns initialized FileSink on native platforms.
Future<LogSink?> createFileSink({
  required String logDirectory,
  int maxFileSize = 5 * 1024 * 1024,
  int maxFileCount = 5,
}) async {
  final sink = FileSink(
    directory: logDirectory,
    maxFileSize: maxFileSize,
    maxFileCount: maxFileCount,
  );
  await sink.initialize();
  return sink;
}

/// Gets compressed logs from a file sink.
/// Casts to FileSink internally to access compression method.
Future<Uint8List> getCompressedLogs(LogSink? sink) async {
  if (sink == null) return Uint8List(0);
  if (sink is! FileSink) return Uint8List(0);
  return sink.getCompressedLogs();
}
```

**Signature Requirement:** Both files export:

- `Future<LogSink?> createFileSink({required String logDirectory, ...})`
- `Future<Uint8List> getCompressedLogs(LogSink? sink)`

### Step 7: Update LogConfig

**File:** `lib/core/logging/log_config.dart`

- [ ] Add `fileLoggingEnabled` field (default: true on native, ignored on web)
- [ ] Update copyWith method

### Step 8: Add file sink provider

**File:** `lib/core/logging/logging_provider.dart`

- [ ] Import from `file_sink_provider.dart` (conditional import barrel)
- [ ] Create `fileSinkProvider` (FutureProvider) that:
  - Watches logConfigProvider for fileLoggingEnabled
  - Gets log directory from path_provider
  - Calls `createFileSink()` from conditional import
  - Returns null if fileLoggingEnabled is false or on web
  - Adds sink to LogManager if not null
  - **Handles toggle**: If disabled while running, remove sink from LogManager
  - Uses `ref.keepAlive()` to persist across rebuilds
  - Disposes correctly on provider dispose

```dart
final fileSinkProvider = FutureProvider<LogSink?>((ref) async {
  final config = await ref.watch(logConfigProvider.future);
  if (!config.fileLoggingEnabled) return null;

  final directory = await _getLogDirectory();
  final sink = await createFileSink(logDirectory: directory);

  if (sink != null) {
    LogManager.instance.addSink(sink);
    ref.keepAlive();
    ref.onDispose(() {
      LogManager.instance.removeSink(sink);
      sink.close();
    });
  }

  return sink;
});
```

### Step 9: Update settings screen

**File:** `lib/features/settings/settings_screen.dart`

- [ ] Add SwitchListTile for "Save logs to file"
- [ ] Hide on web platform (use `kIsWeb` check)
- [ ] Use ref.watch(logConfigProvider) for state

### Step 10: Write unit tests

**Files:** `packages/soliplex_logging_io/test/*.dart`

- [ ] Test FileSink creates directory and file
- [ ] Test FileSink rotates at size limit
- [ ] Test FileSink prunes old files at count limit
- [ ] Test FileSink `getLogFiles()` returns sorted list
- [ ] Test LogCompressor produces valid gzip
- [ ] Test LogCompressor output can be decompressed
- [ ] Use temp directories for isolation

**Files:** `test/core/logging/*.dart`

- [ ] Test fileSinkProvider returns null on web (mock kIsWeb)
- [ ] Test LogConfig with fileLoggingEnabled
- [ ] Test toggling fileLoggingEnabled adds/removes sink

## Web Compatibility Strategy

The `soliplex_logging_io` package uses `dart:io` which is unavailable on Flutter
Web. Conditional imports isolate the `dart:io` dependency:

1. `file_sink_provider.dart` - Barrel file with conditional export
2. `file_sink_stub.dart` - Stub that returns null (used on web)
3. `file_sink_io.dart` - Real implementation (native only)

**Critical:** Both stub and io files must have **identical function signatures**.
The stub returns null/empty, the io returns real values, but the function
parameters and return types must match exactly.

## Platform Log Directory Paths

| Platform | Directory | Notes |
|----------|-----------|-------|
| iOS | `Documents/logs/` | Backed up to iCloud |
| macOS | `Application Support/logs/` | App-specific |
| Android | `Documents/logs/` | Internal storage |
| Linux | `Application Support/logs/` | XDG compliant |
| Windows | `Application Support/logs/` | AppData\Roaming |

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `dart format --set-exit-if-changed packages/soliplex_logging_io`
- [ ] `dart analyze --fatal-infos packages/soliplex_logging_io`
- [ ] `dart test packages/soliplex_logging_io` passes
- [ ] Test coverage >= 85% on package
- [ ] `flutter analyze --fatal-infos` passes on main app
- [ ] `flutter test` passes on main app
- [ ] **`flutter build web`** succeeds (no dart:io leakage)

### Manual Verification

- [ ] Run app on native platform
- [ ] Verify log files created in correct directory
- [ ] Generate enough logs to trigger rotation
- [ ] Verify old files are pruned
- [ ] Toggle file logging off/on in settings
- [ ] Run app on web and verify no errors

### Review Gates

- [ ] **Gemini Review:** Run `mcp__gemini__read_files` with model
  `gemini-3-pro-preview` passing:
  - `docs/planning/logging/06-advanced-io-persistence.md`
  - All `.dart` files in `packages/soliplex_logging_io/lib/`
  - All `.dart` files in `packages/soliplex_logging_io/test/`
  - `lib/core/logging/file_sink_provider.dart`
  - `lib/core/logging/file_sink_stub.dart`
  - `lib/core/logging/file_sink_io.dart`
  - `lib/core/logging/logging_provider.dart`
  - `test/core/logging/*.dart`
- [ ] **Codex Review:** Run `mcp__codex__codex` to analyze implementation

## Success Criteria

- [ ] Package compiles with zero analyzer issues
- [ ] All unit tests pass
- [ ] Test coverage >= 85%
- [ ] File rotation correctly limits size and count
- [ ] Compressed logs can be decompressed
- [ ] **Flutter Web compiles without errors**
- [ ] Log files created in correct platform-specific directories
- [ ] Toggle in settings works correctly
- [ ] Conditional import signatures match exactly
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
