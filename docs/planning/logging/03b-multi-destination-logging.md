# Milestone 03b: Multi-Destination Logging (Desktop Dual Output)

**Status:** planning
**Depends on:** 03a-web-console-support (complete)
**Blocks:** Cross-platform verification in OVERVIEW.md

## Problem Statement

The current logging architecture has a gap in desktop platform support:

| Platform | Current               | Desired                          |
| -------- | --------------------- | -------------------------------- |
| Desktop  | `dart:developer` only | `dart:developer` + stdout        |
| Mobile   | `dart:developer`      | `dart:developer` only            |
| Web      | Browser console only  | Browser console + dart:developer |

**The Gap:** Desktop developers running the app from terminal cannot see logs
unless they have IDE DevTools attached. Logs go to `dart:developer log()` which
is only visible in:

- VS Code Debug Console (when debugging)
- Android Studio Logcat (for Flutter)
- Dart DevTools (when connected)

**Not visible in:**

- Terminal when running `flutter run` (stdout)
- Terminal when running built executable directly

## User Story

> As a desktop developer, I want logs to appear in my terminal AND in the IDE
> debug console, so I can debug without requiring DevTools attachment.

## Decision: Platform-Specific Dual Output

After Gemini review and further analysis:

| Platform | Destinations                         | Rationale                      |
| -------- | ------------------------------------ | ------------------------------ |
| Desktop  | dart:developer + stdout              | Terminal + IDE/DevTools        |
| Mobile   | dart:developer only                  | Avoid duplicate logcat entries |
| Web      | Browser console + dart:developer     | F12 console + Dart DevTools    |

**Why not mobile stdout?** `dart:developer` already pipes to Logcat (Android)
and Syslog (iOS). Adding stdout on mobile results in duplicate entries with no
benefit.

**Why web dual output?** The current web implementation (03a) only writes to
the browser's JavaScript console. When Dart DevTools is attached to a web app,
`dart:developer log()` logs would be visible there - but currently we don't
call it on web. Adding `dart:developer` support on web enables DevTools
visibility alongside the browser console.

## Technical Analysis

### Current Architecture

```text
Loggers.http.info('message')
       |
Logger.info() checks minimumLevel
       |
LogManager.emit(record)
       |
ConsoleSink.write(record)
       |
platform.writeToConsole(record)  [conditional import]
       |
+--------------------------------------------------+
| Native: dart:developer.log() -> IDE/DevTools     |
| Web: console.info() -> Browser console           |
+--------------------------------------------------+
```

### Proposed Architecture

```text
Loggers.http.info('message')
       |
Logger.info() checks minimumLevel
       |
LogManager.emit(record)
       |
+--------------------------------------------------+
| ConsoleSink.write(record) -> dart:developer      |
| StdoutSink.write(record) -> stdout (desktop)     | [NEW]
+--------------------------------------------------+
```

## Implementation: Separate StdoutSink

Create a new `StdoutSink` that writes to stdout. Desktop platforms register both
`ConsoleSink` and `StdoutSink`.

**Pros:**

- Clean separation of concerns (SRP)
- Each sink does one thing
- Easy to enable/disable independently
- Matches existing multi-sink architecture

**Cons:**

- Two sink instances on desktop (negligible overhead)

### File Structure

```text
packages/soliplex_logging/lib/src/sinks/
+-- console_sink.dart           # Existing (dart:developer)
+-- console_sink_native.dart    # Existing
+-- console_sink_web.dart       # Existing
+-- stdout_sink.dart            # NEW - Public API with conditional import
+-- stdout_sink_io.dart         # NEW - dart:io implementation with ANSI colors
+-- stdout_sink_web.dart        # NEW - Stub (no-op on web)
```

### StdoutSink Implementation

**stdout_sink.dart** (entry point):

```dart
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';

// IO is default, web overrides to no-op
import 'stdout_sink_io.dart'
    if (dart.library.js_interop) 'stdout_sink_web.dart'
    as platform;

/// A sink that writes logs to stdout with ANSI colors.
///
/// On native platforms (desktop, mobile), writes to stdout via dart:io.
/// On web, this is a no-op (web has no stdout concept).
///
/// Primary use case: Desktop development where developers run from terminal.
class StdoutSink implements LogSink {
  StdoutSink({this.enabled = true});

  bool enabled;

  @override
  void write(LogRecord record) {
    if (!enabled) return;
    platform.writeToStdout(record);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    enabled = false;
  }
}
```

**stdout_sink_io.dart** (native implementation with ANSI colors):

```dart
import 'dart:io';

import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/sinks/log_format.dart';

/// ANSI color codes for terminal output.
const _reset = '\x1B[0m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _gray = '\x1B[90m';

/// Writes a log record to stdout via dart:io with ANSI colors.
void writeToStdout(LogRecord record) {
  final color = _colorForLevel(record.level);
  final levelTag = '$color[${record.level.label}]$_reset';
  final message = formatLogMessage(record);

  // Replace level tag with colored version
  final coloredMessage = message.replaceFirst(
    '[${record.level.label}]',
    levelTag,
  );

  stdout.writeln(coloredMessage);

  if (record.error != null) {
    stdout.writeln('$_red  Error: ${record.error}$_reset');
  }
  if (record.stackTrace != null) {
    stdout.writeln('$_gray  Stack: ${record.stackTrace}$_reset');
  }
}

String _colorForLevel(LogLevel level) {
  return switch (level) {
    LogLevel.trace => _gray,
    LogLevel.debug => _gray,
    LogLevel.info => _cyan,
    LogLevel.warning => _yellow,
    LogLevel.error => _red,
    LogLevel.fatal => _red,
  };
}
```

**stdout_sink_web.dart** (web stub):

```dart
import 'package:soliplex_logging/src/log_record.dart';

/// No-op on web (stdout doesn't exist).
void writeToStdout(LogRecord record) {
  // Intentionally empty - web has no stdout concept
}
```

### Provider Integration

**CRITICAL:** Do NOT use `dart:io Platform` in the provider - it breaks web
builds. Use `package:flutter/foundation.dart` instead.

Update `logging_provider.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Provider that manages the stdout sink lifecycle (desktop only).
final stdoutSinkProvider = Provider<StdoutSink?>((ref) {
  // Web never uses StdoutSink
  if (kIsWeb) return null;

  // Only enable on desktop platforms
  final isDesktop = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => true,
    TargetPlatform.windows => true,
    TargetPlatform.linux => true,
    _ => false,
  };

  if (!isDesktop) return null;

  ref.keepAlive();

  final configAsync = ref.watch(logConfigProvider);
  final config = configAsync.when(
    data: (config) => config,
    loading: () => LogConfig.defaultConfig,
    error: (_, __) => LogConfig.defaultConfig,
  );

  if (!config.stdoutLoggingEnabled) return null;

  final sink = StdoutSink();
  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
  });

  return sink;
});
```

### Configuration Update

Add `stdoutLoggingEnabled` to `LogConfig`:

```dart
class LogConfig {
  const LogConfig({
    this.minimumLevel = LogLevel.info,
    this.consoleLoggingEnabled = true,
    this.stdoutLoggingEnabled = true,  // Default on (provider gates by platform)
  });

  final LogLevel minimumLevel;
  final bool consoleLoggingEnabled;
  final bool stdoutLoggingEnabled;
}
```

## Platform Behavior Summary

After implementation:

| Platform | ConsoleSink                        | StdoutSink         | Result            |
| -------- | ---------------------------------- | ------------------ | ----------------- |
| macOS    | dart:developer -> IDE              | stdout -> terminal | Both visible      |
| Windows  | dart:developer -> IDE              | stdout -> terminal | Both visible      |
| Linux    | dart:developer -> IDE              | stdout -> terminal | Both visible      |
| iOS      | dart:developer -> IDE              | N/A (disabled)     | IDE only          |
| Android  | dart:developer -> IDE              | N/A (disabled)     | IDE only          |
| Web      | Browser console + dart:developer   | N/A (no-op)        | F12 + DevTools    |

## Resolved Questions (Gemini Review)

1. **Mobile stdout:** **No.** Do not implement. It adds noise/duplication to
   Logcat/Device Console with no benefit.

2. **Output format:** **Add ANSI Colors.** Since StdoutSink is primarily for
   terminal usage, wrap level tags in ANSI escape codes for visual clarity.

3. **Settings UI:** **Hidden by default.** Regular users do not understand
   "Stdout". Keep `stdoutLoggingEnabled` in `LogConfig`, but only expose in a
   "Developer Options" menu if absolutely necessary.

4. **Performance:** **No concerns.** String interpolation and printing to stdout
   are fast enough for debug logging on desktop hardware.

## Files to Create

- [ ] `packages/soliplex_logging/lib/src/sinks/stdout_sink.dart`
- [ ] `packages/soliplex_logging/lib/src/sinks/stdout_sink_io.dart`
- [ ] `packages/soliplex_logging/lib/src/sinks/stdout_sink_web.dart`
- [ ] `packages/soliplex_logging/test/stdout_sink_test.dart`

## Files to Modify

- [ ] `packages/soliplex_logging/lib/soliplex_logging.dart` - Export StdoutSink
- [ ] `packages/soliplex_logging/lib/src/sinks/console_sink_web.dart` - Add
  `dart:developer` call for DevTools visibility
- [ ] `lib/core/logging/log_config.dart` - Add stdoutLoggingEnabled
- [ ] `lib/core/logging/logging_provider.dart` - Add stdoutSinkProvider
- [ ] `docs/planning/logging/OVERVIEW.md` - Add 03b to milestone list

### Web Console Sink Enhancement

Update `console_sink_web.dart` to also call `dart:developer log()`:

```dart
import 'dart:developer' as developer;
import 'dart:js_interop';

// ... existing imports and code ...

void writeToConsole(LogRecord record) {
  // 1. Write to browser JavaScript console (existing behavior)
  final msgString = formatLogMessage(record);
  // ... existing browser console code ...

  // 2. Also write to dart:developer for DevTools visibility (NEW)
  developer.log(
    msgString,
    name: record.loggerName,
    level: _mapLevel(record.level),
    time: record.timestamp,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}
```

This ensures logs are visible in both:

- Browser F12 Console (for web developers)
- Dart DevTools (when connected for debugging)

## Implementation Steps

### Step 1: Create StdoutSink with Conditional Import

- [ ] Create `stdout_sink.dart` with conditional import pattern
- [ ] Create `stdout_sink_io.dart` using `dart:io stdout` with ANSI colors
- [ ] Create `stdout_sink_web.dart` as no-op stub
- [ ] Reuse `log_format.dart` for message formatting

### Step 2: Export from Package

- [ ] Add `export 'src/sinks/stdout_sink.dart';` to `soliplex_logging.dart`

### Step 3: Add Configuration

- [ ] Add `stdoutLoggingEnabled` to `LogConfig`
- [ ] Add SharedPreferences persistence key
- [ ] Add setter method to `LogConfigNotifier`

### Step 4: Add Provider

- [ ] Create `stdoutSinkProvider` with `kIsWeb` and `defaultTargetPlatform`
- [ ] Wire up sink lifecycle management
- [ ] Ensure proper disposal

### Step 5: Add Tests

- [ ] Test StdoutSink enabled/disabled behavior
- [ ] Test platform detection logic (mock `defaultTargetPlatform`)
- [ ] Test provider lifecycle

## Validation Gate

### Automated Checks

- [ ] `dart format --set-exit-if-changed packages/soliplex_logging`
- [ ] `dart analyze --fatal-infos packages/soliplex_logging`
- [ ] `dart test packages/soliplex_logging` passes
- [ ] `flutter test` passes (app tests)
- [ ] `flutter build web` compiles without errors

### Manual Verification

- [ ] Run `flutter run -d macos` from terminal
- [ ] Verify logs appear in terminal stdout with ANSI colors
- [ ] Verify logs also appear in VS Code Debug Console
- [ ] Verify web build still compiles
- [ ] Verify mobile build still compiles

### Review Gates

- [x] Gemini review: PASS (2026-02-04)
- [ ] Codex review: PENDING

## Success Criteria

- [ ] Desktop logs appear in terminal when running `flutter run`
- [ ] Desktop logs also appear in IDE debug console
- [ ] Terminal output has colored level tags (ANSI)
- [ ] Mobile continues to work (dart:developer only)
- [ ] Web logs appear in browser F12 console
- [ ] Web logs appear in Dart DevTools when attached
- [ ] Web build compiles without dart:io errors
- [ ] Configuration persists between sessions
- [ ] Tests pass on all platforms
