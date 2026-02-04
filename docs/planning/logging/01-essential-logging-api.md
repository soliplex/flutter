# Milestone 01: Essential Logging API

**Status:** pending
**Depends on:** none

## Objective

Create the minimal `soliplex_logging` package and integrate it into the Flutter
application immediately. This provides the central type-safe `Loggers` API to
developers without waiting for complex file I/O implementation.

## Key Design: Type-Safe Loggers

```dart
// Type-safe usage - no string typos possible
Loggers.auth.info('User logged in');
Loggers.http.debug('GET /api/users');
Loggers.activeRun.error('Failed to process', error: e, stackTrace: s);

// Definition (compile-time enforced)
abstract final class Loggers {
  static final auth = LogManager.instance.getLogger('Auth');
  static final http = LogManager.instance.getLogger('HTTP');
  static final activeRun = LogManager.instance.getLogger('ActiveRun');
  static final chat = LogManager.instance.getLogger('Chat');
  static final room = LogManager.instance.getLogger('Room');
  static final router = LogManager.instance.getLogger('Router');
  static final quiz = LogManager.instance.getLogger('Quiz');
}
```

## Key Design: Span-Ready LogRecord

```dart
class LogRecord {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String loggerName;
  final Object? error;
  final StackTrace? stackTrace;

  // Future telemetry correlation (nullable for now)
  final String? spanId;
  final String? traceId;
}
```

## Pre-flight Checklist

- [ ] Confirm `packages/` directory exists
- [ ] Review existing package structure (`soliplex_client`) for conventions
- [ ] Verify `shared_preferences` is already a dependency (for config persistence)

## Deliverables

1. **Package `soliplex_logging`**: Pure Dart package
   - `LogLevel` (Enum)
   - `LogRecord` (Data class with span fields)
   - `LogSink` (Interface)
   - `ConsoleSink` (Implementation wrapping `dart:developer`)
   - `Logger` (Facade)
   - `LogManager` (Singleton)
2. **Flutter Integration**:
   - `Loggers` (Type-safe static class)
   - `LogConfig` (Riverpod State)
   - `logging_provider.dart` (Setup LogManager via single consoleSinkProvider)
   - `main.dart` initialization

## Files to Create

### Package Files

- [ ] `packages/soliplex_logging/pubspec.yaml`
- [ ] `packages/soliplex_logging/analysis_options.yaml`
- [ ] `packages/soliplex_logging/lib/soliplex_logging.dart`
- [ ] `packages/soliplex_logging/lib/src/log_level.dart`
- [ ] `packages/soliplex_logging/lib/src/log_record.dart`
- [ ] `packages/soliplex_logging/lib/src/log_sink.dart`
- [ ] `packages/soliplex_logging/lib/src/sinks/console_sink.dart`
- [ ] `packages/soliplex_logging/lib/src/logger.dart`
- [ ] `packages/soliplex_logging/lib/src/log_manager.dart`
- [ ] `packages/soliplex_logging/test/log_level_test.dart`
- [ ] `packages/soliplex_logging/test/log_record_test.dart`
- [ ] `packages/soliplex_logging/test/console_sink_test.dart`
- [ ] `packages/soliplex_logging/test/logger_test.dart`
- [ ] `packages/soliplex_logging/test/log_manager_test.dart`

### App Integration Files

- [ ] `lib/core/logging/loggers.dart`
- [ ] `lib/core/logging/log_config.dart`
- [ ] `lib/core/logging/logging_provider.dart`
- [ ] `test/core/logging/log_config_test.dart`
- [ ] `test/core/logging/logging_provider_test.dart`

## Implementation Steps

### Step 1: Create package structure

**File:** `packages/soliplex_logging/pubspec.yaml`

- [ ] Create pubspec with name `soliplex_logging`
- [ ] Set SDK constraint `^3.6.0`
- [ ] Add `meta: ^1.9.0` dependency
- [ ] Add dev_dependencies: `test: ^1.24.0`, `very_good_analysis: ^7.0.0`
- [ ] No Flutter dependencies (pure Dart)

### Step 2: Implement LogLevel enum

**File:** `packages/soliplex_logging/lib/src/log_level.dart`

- [ ] Create enum with values: trace(0), debug(100), info(200), warning(300),
  error(400), fatal(500)
- [ ] Add `value` property for numeric comparison
- [ ] Add `label` property for display (avoid conflict with Dart's `.name`)
- [ ] Implement comparison operators (`>=`, `<`)

### Step 3: Implement LogRecord class

**File:** `packages/soliplex_logging/lib/src/log_record.dart`

- [ ] Create immutable class with fields:
  - `level` (LogLevel)
  - `message` (String)
  - `timestamp` (DateTime)
  - `loggerName` (String)
  - `error` (Object?)
  - `stackTrace` (StackTrace?)
  - `spanId` (String?) - for future telemetry
  - `traceId` (String?) - for future telemetry
- [ ] Keep serialization simple (toJson/fromJson deferred to M06)

### Step 4: Implement LogSink interface

**File:** `packages/soliplex_logging/lib/src/log_sink.dart`

- [ ] Define abstract interface with: `write(LogRecord)`, `flush()`, `close()`

### Step 5: Implement ConsoleSink

**File:** `packages/soliplex_logging/lib/src/sinks/console_sink.dart`

- [ ] Implement LogSink using `dart:developer` `log()` function
- [ ] Format output as: `[LEVEL] loggerName: message`
- [ ] Include spanId/traceId in output if present
- [ ] Add `enabled` flag for conditional output

### Step 6: Implement Logger facade

**File:** `packages/soliplex_logging/lib/src/logger.dart`

- [ ] Create class with named constructor `Logger._(name, manager)`
- [ ] Implement level methods: trace, debug, info, warning, error, fatal
- [ ] All methods accept optional: `error`, `stackTrace`, `spanId`, `traceId`
- [ ] Filter logs below `manager.minimumLevel`

### Step 7: Implement LogManager singleton

**File:** `packages/soliplex_logging/lib/src/log_manager.dart`

- [ ] Create singleton with `LogManager.instance`
- [ ] Manage list of sinks with `addSink`, `removeSink`
- [ ] Expose `minimumLevel` getter/setter
- [ ] Implement `getLogger(name)` returning cached Logger instances
- [ ] Implement `emit(LogRecord)` to write to all sinks
- [ ] Implement `flush()` and `close()` for cleanup

### Step 8: Create barrel export

**File:** `packages/soliplex_logging/lib/soliplex_logging.dart`

- [ ] Export: LogLevel, LogRecord, LogSink, ConsoleSink, Logger, LogManager

### Step 9: Add package dependency to app

**File:** `pubspec.yaml`

- [ ] Add `soliplex_logging: path: packages/soliplex_logging`

### Step 10: Create type-safe Loggers class

**File:** `lib/core/logging/loggers.dart`

- [ ] Create `abstract final class Loggers` with static Logger fields:
  - `auth` - Authentication events
  - `http` - HTTP request/response logging
  - `activeRun` - AG-UI run processing
  - `chat` - Chat feature
  - `room` - Room feature
  - `router` - Navigation events
  - `quiz` - Quiz feature
  - `config` - Configuration changes
  - `ui` - General UI events
- [ ] Each field calls `LogManager.instance.getLogger('Name')`
- [ ] Document when to add new loggers vs reuse existing

### Step 11: Create LogConfig model

**File:** `lib/core/logging/log_config.dart`

- [ ] Create immutable class with: minimumLevel, consoleLoggingEnabled
- [ ] Set sensible defaults: LogLevel.info, true
- [ ] Implement copyWith method
- [ ] Create `LogConfig.defaultConfig` constant for use before prefs load

### Step 12: Create logging providers

**File:** `lib/core/logging/logging_provider.dart`

- [ ] Create `LogConfigNotifier` extending **AsyncNotifier**<LogConfig>
- [ ] In `build()`: Load from SharedPreferences, return default while loading
- [ ] Persist config to SharedPreferences (keys: `log_level`, `console_logging`)
- [ ] Create `logConfigProvider` AsyncNotifierProvider
- [ ] Create `consoleSinkProvider` that:
  - Watches logConfigProvider (use `.when()` to handle loading state)
  - Uses default config while AsyncValue is loading
  - Adds/removes ConsoleSink based on consoleLoggingEnabled
  - **Single source of truth** - no duplicate sink initialization elsewhere
  - On dispose: removes sink from LogManager
- [ ] Apply minimumLevel to LogManager when config changes
- [ ] Use `ref.keepAlive()` to ensure provider stays active

### Step 13: Initialize logging in main

**File:** `lib/main.dart`

- [ ] Call `WidgetsFlutterBinding.ensureInitialized()` first
- [ ] Initialize LogManager (singleton is ready)
- [ ] Add default ConsoleSink immediately for early logging (before providers)
- [ ] Providers will take over sink management once initialized
- [ ] Log app startup: `Loggers.config.info('App starting')`

### Step 14: Write unit tests

**Files:** `packages/soliplex_logging/test/*.dart`

- [ ] Test LogLevel comparisons
- [ ] Test LogRecord creation with span fields
- [ ] Test Logger respects minimum level
- [ ] Test Logger passes span fields to LogRecord
- [ ] Test LogManager singleton behavior
- [ ] Test multiple sinks receive records

**Files:** `test/core/logging/*.dart`

- [ ] Test LogConfig copyWith
- [ ] Test LogConfig.defaultConfig
- [ ] Test LogConfigNotifier persists and loads settings
- [ ] Test consoleSinkProvider uses default while loading

## Out of Scope (Deferred)

- `MemorySink` (Moved to M04)
- `LogFormatter` complexity (Moved to M04)
- `FileSink` / `soliplex_logging_io` (Moved to M06)
- Rotation logic (Moved to M06)
- JSON serialization (Moved to M06)
- Span creation/management (Future milestone)

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `dart format --set-exit-if-changed packages/soliplex_logging`
- [ ] `dart analyze --fatal-infos packages/soliplex_logging`
- [ ] `dart test packages/soliplex_logging` passes
- [ ] Test coverage >= 85% on package
- [ ] `flutter analyze --fatal-infos` passes on main app
- [ ] `flutter test` passes on main app

### Manual Verification

- [ ] Add `Loggers.config.info('Test message')` in `lib/main.dart`
- [ ] Run app and verify log appears in IDE debug console
- [ ] Change log level in LogConfig and verify filtering works
- [ ] Verify no duplicate log lines (sink management is correct)

### Review Gates

#### Gemini Review

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`
**File limit:** 15 files per call (batch if needed)

**Dynamic file gathering:** At review time, collect all relevant files:

```bash
# Gather files for review (run these to get actual paths)
find docs/planning/logging/01-essential-logging-api.md
find packages/soliplex_logging -name "*.dart" -type f
find lib/core/logging -name "*.dart" -type f
find test/core/logging -name "*.dart" -type f
```

**Prompt:**

```text
Review this logging implementation against the spec in 01-essential-logging-api.md.

Check:
1. Type-safe Loggers class with static fields (not string-based getLogger)
2. Span-ready LogRecord with spanId and traceId fields
3. Pure Dart package (no Flutter imports, no dart:io in soliplex_logging)
4. Proper sink lifecycle in providers (keepAlive, onDispose)
5. No duplicate sink initialization

Report PASS or list specific issues to fix.
```

- [ ] Gemini review: PASS

#### Codex Review

**Tool:** `mcp__codex__codex`
**Model:** `gpt-5.2`
**Timeout:** 10 minutes
**Sandbox:** `read-only`
**Approval policy:** `on-failure`

**Prompt:**

```json
{
  "prompt": "Review the soliplex_logging implementation against docs/planning/logging/01-essential-logging-api.md.\n\nCheck:\n1. Type-safe Loggers.x API exists (not string-based)\n2. LogRecord has spanId and traceId fields\n3. Package is pure Dart (no Flutter, no dart:io)\n4. consoleSinkProvider uses ref.keepAlive() and ref.onDispose()\n5. No duplicate sink initialization in main.dart\n6. All tests pass with dart test packages/soliplex_logging\n\nReport PASS or list specific issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

- [ ] Codex review: PASS

## Success Criteria

- [ ] Package compiles with zero analyzer issues
- [ ] All unit tests pass
- [ ] Test coverage >= 85%
- [ ] `Loggers.config.info('Test')` prints to IDE console
- [ ] `LogConfig` provider exists and can toggle console output
- [ ] No duplicate sinks (only consoleSinkProvider manages ConsoleSink)
- [ ] LogRecord includes spanId/traceId fields
- [ ] Loggers class provides type-safe access to all loggers
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
