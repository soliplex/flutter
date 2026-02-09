# Milestone 02: API Documentation

**Status:** pending
**Depends on:** 01-essential-logging-api

## Objective

Document the Logger API so developers can start using `Loggers.x` immediately.
This milestone ensures the team doesn't need to wait for all features before
adopting the logging system.

## Pre-flight Checklist

- [ ] M01 complete and passing all tests
- [ ] Logger API is stable and working
- [ ] Loggers class is defined with all initial loggers

## Files to Create

- [ ] `packages/soliplex_logging/README.md`
- [ ] `docs/logging-quickstart.md`

## Implementation Steps

### Step 1: Create package README

**File:** `packages/soliplex_logging/README.md`

- [ ] Package description (1-2 sentences)
- [ ] Installation instructions (pubspec.yaml snippet)
- [ ] Quick start example (raw API for package consumers):

```dart
import 'package:soliplex_logging/soliplex_logging.dart';

// Initialize (typically done once in main.dart)
LogManager.instance.addSink(ConsoleSink());

// Get a logger (raw API)
final log = LogManager.instance.getLogger('MyClass');

// Log messages
log.info('Application started');
log.debug('Processing item');
log.error('Failed to connect', error: e, stackTrace: s);

// With span context (for future telemetry)
log.info('Processing request', spanId: span.id, traceId: trace.id);
```

- [ ] Note about type-safe usage in applications:

```dart
// In the Soliplex app, prefer the type-safe Loggers class:
import 'package:soliplex_frontend/core/logging/loggers.dart';

Loggers.auth.info('User logged in');
Loggers.http.debug('GET /api/users');

// See docs/logging-quickstart.md for app-specific usage
```

- [ ] LogLevel reference table:

| Level | Value | Usage |
|-------|-------|-------|
| trace | 0 | Very detailed debugging |
| debug | 100 | Development debugging |
| info | 200 | Normal operations |
| warning | 300 | Recoverable issues |
| error | 400 | Errors affecting functionality |
| fatal | 500 | Unrecoverable errors |

- [ ] API reference for key classes:
  - LogLevel enum
  - LogRecord class (including spanId/traceId)
  - LogSink interface
  - ConsoleSink
  - Logger
  - LogManager

### Step 2: Create quickstart guide

**File:** `docs/logging-quickstart.md`

- [ ] Overview of logging architecture
- [ ] Type-safe Loggers usage:

```dart
import 'package:soliplex_frontend/core/logging/loggers.dart';

// Use predefined type-safe loggers
Loggers.auth.info('User logged in');
Loggers.http.debug('GET /api/users');
Loggers.chat.error('Message send failed', error: e);

// Available loggers:
// Loggers.auth      - Authentication events
// Loggers.http      - HTTP request/response
// Loggers.activeRun - AG-UI processing
// Loggers.chat      - Chat feature
// Loggers.room      - Room feature
// Loggers.router    - Navigation
// Loggers.quiz      - Quiz feature
// Loggers.config    - Configuration changes
// Loggers.ui        - General UI events
```

- [ ] Adding a new logger:

```dart
// In lib/core/logging/loggers.dart, add:
abstract final class Loggers {
  // ... existing loggers ...
  static final myFeature = LogManager.instance.getLogger('MyFeature');
}
```

- [ ] Log level guidelines with examples:

| Level | When to Use | Example |
|-------|-------------|---------|
| trace | Loop iterations, detailed flow | `Loggers.http.trace('Header: $key=$value')` |
| debug | State changes, request/response | `Loggers.http.debug('GET $url')` |
| info | User actions, lifecycle events | `Loggers.auth.info('User logged in')` |
| warning | Recoverable issues, deprecations | `Loggers.config.warning('Using fallback')` |
| error | Failures that affect functionality | `Loggers.chat.error('Send failed', error: e)` |
| fatal | Unrecoverable, app must restart | `Loggers.config.fatal('Corrupt state')` |

- [ ] How to change log level via Settings (preview - full UI in M04)
- [ ] Span context for telemetry (future feature note)
- [ ] Troubleshooting common issues

### Step 3: Add dartdoc to public APIs

**Files:** `packages/soliplex_logging/lib/src/*.dart`

- [ ] LogLevel: Document each level's intended use
- [ ] LogRecord: Document all fields including spanId/traceId
- [ ] LogSink: Document interface contract
- [ ] ConsoleSink: Document configuration options
- [ ] Logger: Document each method and parameters
- [ ] LogManager: Document singleton usage

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `npx markdownlint-cli packages/soliplex_logging/README.md`
- [ ] `npx markdownlint-cli docs/logging-quickstart.md`
- [ ] `dart doc packages/soliplex_logging` runs without errors

### Manual Verification

- [ ] README examples are copy-pasteable and work
- [ ] Quickstart guide is clear for new developers
- [ ] All public APIs have dartdoc comments
- [ ] Loggers class usage is well documented

### Review Gates

#### Gemini Review

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`
**File limit:** 15 files per call (batch if needed)

**Dynamic file gathering:** At review time, collect all relevant files:

```bash
# Gather files for review (run these to get actual paths)
find docs/planning/logging/02-api-documentation.md
find packages/soliplex_logging/README.md
find docs/logging-quickstart.md
find packages/soliplex_logging/lib -name "*.dart" -type f
find lib/core/logging -name "*.dart" -type f
```

**Prompt:**

```text
Review the logging documentation against the spec in 02-api-documentation.md.

Check:
1. README has both raw LogManager API and type-safe Loggers.x examples
2. Quickstart guide covers all loggers (auth, http, activeRun, chat, room, router, quiz, config, ui)
3. All public APIs have dartdoc comments
4. Log level guidelines are clear with examples
5. Span fields (spanId, traceId) are documented

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
  "prompt": "Review the logging documentation against docs/planning/logging/02-api-documentation.md.\n\nCheck:\n1. packages/soliplex_logging/README.md exists and is complete\n2. docs/logging-quickstart.md exists with Loggers.x usage guide\n3. All public APIs have dartdoc comments\n4. dart doc packages/soliplex_logging runs without errors\n5. npx markdownlint-cli passes on all markdown files\n\nReport PASS or list specific issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

- [ ] Codex review: PASS

## Success Criteria

- [ ] `packages/soliplex_logging/README.md` exists and is complete
- [ ] `docs/logging-quickstart.md` exists with usage guide
- [ ] All public APIs have dartdoc comments
- [ ] `dart doc` runs without errors
- [ ] Markdown linting passes
- [ ] Type-safe Loggers usage is documented
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
