# Milestone 03a: Web Console Logging Support

**Status:** complete
**Depends on:** 01-essential-logging-api (complete), 03-migration-strategy (complete)
**Blocks:** Cross-platform verification in OVERVIEW.md ("Logs appear in console" for Web)

## Problem Statement

The current `ConsoleSink` uses `dart:developer log()` which:

- **Native (iOS/macOS/Android):** Works correctly - outputs to IDE debug console
- **Web:** Does NOT work - `dart:developer log()` is a no-op unless Dart DevTools is
  connected

Developers running the Flutter web app cannot see logs in the browser's JavaScript
console, making debugging difficult.

## Objective

Add web platform support to `ConsoleSink` so logs appear in the browser's JavaScript
console with full debugging capabilities (expandable error objects, source maps,
clickable stack traces) without breaking native platform behavior.

## Proposed Solution

Use Dart's conditional imports to provide platform-specific implementations:

1. **Default (native):** Keep existing `dart:developer log()` behavior
2. **Web:** Use `dart:js_interop` to call browser's `console` methods directly

This approach:

- Maintains pure Dart package (no Flutter dependency)
- Zero runtime overhead (compile-time platform selection)
- Maps log levels to appropriate console methods (debug, info, warn, error)
- Preserves browser's interactive debugging features

## Implementation Design

### File Structure

```text
packages/soliplex_logging/lib/src/sinks/
├── console_sink.dart          # Public API with conditional import
├── console_sink_native.dart   # Native implementation (dart:developer)
├── console_sink_web.dart      # Web implementation (dart:js_interop)
└── log_format.dart            # Shared formatting utilities (new)
```

### Shared Formatting (Centralized)

**log_format.dart** (shared between native and web):

```dart
import 'package:soliplex_logging/src/log_record.dart';

/// Formats the basic log message (level, logger, message, spans).
/// Error and stackTrace are handled separately by each platform.
String formatLogMessage(LogRecord record) {
  final buffer = StringBuffer()
    ..write('[${record.level.label}] ${record.loggerName}: ${record.message}');

  if (record.spanId != null || record.traceId != null) {
    buffer.write(' (');
    if (record.traceId != null) buffer.write('trace=${record.traceId}');
    if (record.spanId != null && record.traceId != null) buffer.write(', ');
    if (record.spanId != null) buffer.write('span=${record.spanId}');
    buffer.write(')');
  }

  return buffer.toString();
}
```

### Conditional Import Pattern

**console_sink.dart** (entry point):

```dart
import 'package:meta/meta.dart';

// Native is the default, web overrides when js_interop is available
import 'console_sink_native.dart'
    if (dart.library.js_interop) 'console_sink_web.dart'
    as platform;

/// Function type for console write operations.
typedef ConsoleWriter = void Function(LogRecord record);

class ConsoleSink implements LogSink {
  /// Creates a console sink.
  ///
  /// [testWriter] is for testing only - allows capturing log output
  /// without writing to the actual console.
  ConsoleSink({
    this.enabled = true,
    @visibleForTesting ConsoleWriter? testWriter,
  }) : _testWriter = testWriter;

  bool enabled;
  final ConsoleWriter? _testWriter;

  @override
  void write(LogRecord record) {
    if (!enabled) return;

    // Use test writer if provided, otherwise delegate to platform
    if (_testWriter != null) {
      _testWriter!(record);
    } else {
      platform.writeToConsole(record);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    enabled = false;
  }
}
```

**console_sink_native.dart**:

```dart
import 'dart:developer' as developer;

// Use relative imports within src/sinks directory
import 'log_format.dart';
import '../log_level.dart';
import '../log_record.dart';

/// Writes a log record to the native console via dart:developer.
/// Called by ConsoleSink.write() via conditional import.
void writeToConsole(LogRecord record) {
  developer.log(
    formatLogMessage(record),
    name: record.loggerName,
    level: _mapLevel(record.level),
    time: record.timestamp,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}

int _mapLevel(LogLevel level) {
  return switch (level) {
    LogLevel.trace => 300,
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
    LogLevel.fatal => 1200,
  };
}
```

**console_sink_web.dart**:

```dart
import 'dart:js_interop';

// Use relative imports within src/sinks directory
import 'log_format.dart';
import '../log_level.dart';
import '../log_record.dart';

@JS('console')
external JSConsole get _console;

/// Extension type for browser console with flexible argument types.
/// Uses JSAny? to preserve object references for browser inspection.
extension type JSConsole(JSObject _) implements JSObject {
  external void debug(JSAny? message, [JSAny? arg1, JSAny? arg2]);
  external void info(JSAny? message, [JSAny? arg1, JSAny? arg2]);
  external void log(JSAny? message, [JSAny? arg1, JSAny? arg2]);
  external void warn(JSAny? message, [JSAny? arg1, JSAny? arg2]);
  external void error(JSAny? message, [JSAny? arg1, JSAny? arg2]);
}

/// Writes a log record to the browser console.
/// Called by ConsoleSink.write() via conditional import.
void writeToConsole(LogRecord record) {
  final message = formatLogMessage(record).toJS;

  // Convert error to JS-friendly format for browser inspection.
  // Creates a structured object that browsers can expand/inspect.
  final errorArg = _convertError(record.error);
  final stackArg = record.stackTrace?.toString().toJS;

  switch (record.level) {
    case LogLevel.trace:
    case LogLevel.debug:
      _console.debug(message, errorArg, stackArg);
    case LogLevel.info:
      _console.info(message, errorArg, stackArg);
    case LogLevel.warning:
      _console.warn(message, errorArg, stackArg);
    case LogLevel.error:
    case LogLevel.fatal:
      _console.error(message, errorArg, stackArg);
  }
}

/// Converts a Dart error to a JS object for browser inspection.
/// Creates a structured object that browsers can expand/inspect.
JSAny? _convertError(Object? error) {
  if (error == null) return null;

  // Create a JS object with error details that browsers can inspect
  final jsError = <String, Object?>{
    'type': error.runtimeType.toString(),
    'message': error.toString(),
  }.jsify();

  return jsError;
}
```

### Log Level to Console Method Mapping

| LogLevel | Browser Console Method | Visual Indicator       |
| -------- | ---------------------- | ---------------------- |
| trace    | console.debug          | Often hidden by default |
| debug    | console.debug          | Often hidden by default |
| info     | console.info           | Info icon (ℹ)          |
| warning  | console.warn           | Yellow/Warning         |
| error    | console.error          | Red/Error              |
| fatal    | console.error          | Red/Error              |

**Rationale:**

- `console.debug` for trace/debug keeps console clean (hidden by default in browsers)
- `console.info` for info provides distinct visual indicator
- `console.warn` for warnings shows yellow styling
- `console.error` for errors/fatal shows red styling with stack trace integration

## Testability Design

### Strategy: Constructor Dependency Injection

Testing is achieved via **constructor injection** on `ConsoleSink`, avoiding global
mutable state. The platform files (`console_sink_web.dart`, `console_sink_native.dart`)
remain pure with no test hooks.

**Key principle:** Test injection happens at the `ConsoleSink` class level, not in
the platform-specific files. This keeps the web/native implementations pure and
avoids test pollution between test runs.

**Test file**:

```dart
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleSink', () {
    test('calls testWriter when provided', () {
      final captured = <LogRecord>[];

      final sink = ConsoleSink(
        testWriter: (record) => captured.add(record),
      );

      final record = LogRecord(
        level: LogLevel.debug,
        message: 'test message',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      sink.write(record);

      expect(captured, hasLength(1));
      expect(captured.first.level, LogLevel.debug);
      expect(captured.first.message, 'test message');
    });

    test('respects enabled flag', () {
      final captured = <LogRecord>[];

      final sink = ConsoleSink(
        enabled: false,
        testWriter: (record) => captured.add(record),
      );

      sink.write(LogRecord(
        level: LogLevel.info,
        message: 'should not appear',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      ));

      expect(captured, isEmpty);
    });
  });
}
```

### Benefits of Constructor Injection

- **No global state:** Each test creates its own `ConsoleSink` instance
- **Test isolation:** Tests cannot pollute each other
- **Parallel safe:** Tests can run in parallel without interference
- **Pure platform files:** `console_sink_web.dart` has no test hooks

### Integration Tests

For verifying actual browser console behavior (colors, expandable objects), use
manual testing with `flutter run -d chrome` and DevTools inspection. Unit tests
verify the routing logic; manual tests confirm browser rendering.

## Files to Modify/Create

### New Files

- [ ] `packages/soliplex_logging/lib/src/sinks/log_format.dart`
- [ ] `packages/soliplex_logging/lib/src/sinks/console_sink_native.dart`
- [ ] `packages/soliplex_logging/lib/src/sinks/console_sink_web.dart`

### Modified Files

- [ ] `packages/soliplex_logging/lib/src/sinks/console_sink.dart` - Add conditional
  import, add testWriter parameter, delegate to platform
- [ ] `packages/soliplex_logging/test/console_sink_test.dart` - Add tests for
  testWriter injection
- [ ] `packages/soliplex_logging/pubspec.yaml` - Verify SDK constraint `>=3.3.0`
  for dart:js_interop extension types, add `meta` dependency

## Implementation Steps

### Step 1: Create shared formatting utility

**File:** `packages/soliplex_logging/lib/src/sinks/log_format.dart`

- [ ] Extract `formatLogMessage(LogRecord)` from current console_sink.dart
- [ ] Include level, logger name, message, and span context
- [ ] Do NOT include error/stackTrace (handled per-platform)

### Step 2: Extract native implementation

**File:** `packages/soliplex_logging/lib/src/sinks/console_sink_native.dart`

- [ ] Import shared `log_format.dart`
- [ ] Create `writeToConsole(LogRecord)` function using `dart:developer`
- [ ] Keep `_mapLevel()` helper for dart:developer level mapping
- [ ] Pass error and stackTrace as separate params to `developer.log()`

### Step 3: Create web implementation

**File:** `packages/soliplex_logging/lib/src/sinks/console_sink_web.dart`

- [ ] Import `dart:js_interop` and use **relative imports** for local files
- [ ] Define `JSConsole` extension type with `JSAny?` arguments
- [ ] Implement `writeToConsole(LogRecord)` function (no global state/test hooks)
- [ ] Map log levels to proper console methods (debug, info, warn, error)
- [ ] Pass error as **JS object** via `jsify()` to preserve browser inspection
- [ ] Pass stackTrace as separate string argument

### Step 4: Update console_sink.dart with conditional import

**File:** `packages/soliplex_logging/lib/src/sinks/console_sink.dart`

- [ ] Add conditional import statement
- [ ] Add `@visibleForTesting ConsoleWriter? testWriter` constructor parameter
- [ ] In `write()`: use testWriter if provided, otherwise delegate to platform
- [ ] Keep `enabled` flag check in main class
- [ ] Preserve existing public API (testWriter is optional, existing code unchanged)

### Step 5: Verify SDK constraint

**File:** `packages/soliplex_logging/pubspec.yaml`

- [ ] Ensure SDK constraint is `>=3.3.0` for dart:js_interop extension types

### Step 6: Add tests for ConsoleSink with testWriter

**File:** `packages/soliplex_logging/test/console_sink_test.dart` (update existing)

- [ ] Test ConsoleSink with `testWriter` parameter captures records
- [ ] Test `enabled: false` prevents writing
- [ ] Test records contain correct level, message, loggerName
- [ ] Test error and stackTrace are included in captured records

**Note:** Testing actual console method routing (debug vs info vs warn) requires
browser integration tests. Unit tests verify the ConsoleSink logic; browser tests
verify the platform implementation.

### Step 7: Update existing tests

**File:** `packages/soliplex_logging/test/console_sink_test.dart`

- [ ] Ensure existing tests still pass (they test the public API)
- [ ] Add test for disabled sink behavior

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `dart format --set-exit-if-changed packages/soliplex_logging`
- [ ] `dart analyze --fatal-infos packages/soliplex_logging`
- [ ] `dart test packages/soliplex_logging` passes (native)
- [ ] `flutter test -p chrome packages/soliplex_logging` passes (web)
- [ ] Test coverage >= 85%

### Manual Verification

- [ ] Run Flutter web app in Chrome
- [ ] Open browser DevTools console (F12)
- [ ] Trigger logging with an error (e.g., failed API call)
- [ ] Verify:
  - [ ] trace/debug logs appear under "Verbose" filter (console.debug)
  - [ ] info logs show info icon (console.info)
  - [ ] warning logs show yellow styling (console.warn)
  - [ ] error logs show red styling (console.error)
  - [ ] Error objects are expandable in browser console
- [ ] Verify native app still logs to IDE console

### Review Gates

#### Gemini Review

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files to review:**

- `docs/planning/logging/03a-web-console-support.md`
- `packages/soliplex_logging/lib/src/sinks/console_sink.dart`
- `packages/soliplex_logging/lib/src/sinks/console_sink_native.dart` (after impl)
- `packages/soliplex_logging/lib/src/sinks/console_sink_web.dart` (after impl)
- `packages/soliplex_logging/lib/src/sinks/log_format.dart` (after impl)

- [ ] Gemini review: PASS

#### Codex Review

**Tool:** `mcp__codex__codex`
**Sandbox:** `read-only`

- [ ] Codex review: PASS

## Success Criteria

- [ ] Web app shows logs in browser console with proper level styling
- [ ] Error objects converted to JS objects via `jsify()` for browser inspection
- [ ] Native apps continue to work unchanged
- [ ] Log levels map to correct console methods (debug, info, warn, error)
- [ ] Public API unchanged (testWriter is optional `@visibleForTesting` param)
- [ ] ConsoleSink testable via constructor injection (no global state)
- [ ] Platform files are pure (no test hooks in console_sink_web.dart)
- [ ] Relative imports used within src/sinks directory
- [ ] All tests pass on both platforms
- [ ] SDK constraint supports dart:js_interop extension types (>=3.3.0)
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
