# Logging Implementation Plan

This plan covers Milestones 01, 02, and 03 of the central logging architecture.
Claude acts as orchestrator, delegating implementation to Codex and review to Gemini.

## Branch Strategy

| Milestone | Branch | Base |
|-----------|--------|------|
| 01-essential-logging-api | `logging-slice-1` | `main` |
| 02-api-documentation | `logging-slice-2` | `logging-slice-1` |
| 03-migration-strategy | `logging-slice-3` | `logging-slice-2` |

## Tool Configuration

### Codex

- **Model:** `gpt-5.2`
- **Timeout:** 10 minutes
- **Sandbox:** `workspace-write`
- **Approval policy:** `on-failure`

### Gemini

- **Model:** `gemini-3-pro-preview`
- **Tool:** `mcp__gemini__read_files`
- **Requirement:** Pass ALL file paths (both `.md` and `.dart`) as absolute paths
- **File limit:** 15 files per call (batch if needed)

---

## Milestone 01: Essential Logging API

**Spec:** `docs/planning/logging/01-essential-logging-api.md`
**Branch:** `logging-slice-1`

### Task 1.1: Create branch

```bash
git checkout -b logging-slice-1 main
```

### Task 1.2: Create package structure (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create the soliplex_logging package structure. Read docs/planning/logging/01-essential-logging-api.md for the full spec. Create these files:\n\n1. packages/soliplex_logging/pubspec.yaml - SDK ^3.6.0, meta ^1.9.0, dev deps test and very_good_analysis\n2. packages/soliplex_logging/analysis_options.yaml - include very_good_analysis\n3. packages/soliplex_logging/lib/soliplex_logging.dart - barrel export\n4. packages/soliplex_logging/lib/src/log_level.dart - enum with trace(0), debug(100), info(200), warning(300), error(400), fatal(500)\n5. packages/soliplex_logging/lib/src/log_record.dart - immutable class with level, message, timestamp, loggerName, error, stackTrace, spanId, traceId\n6. packages/soliplex_logging/lib/src/log_sink.dart - abstract interface\n7. packages/soliplex_logging/lib/src/sinks/console_sink.dart - implementation using dart:developer\n8. packages/soliplex_logging/lib/src/logger.dart - facade class\n9. packages/soliplex_logging/lib/src/log_manager.dart - singleton\n\nRun dart format and dart analyze after creating files.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.3: Write package tests (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Write unit tests for soliplex_logging package. Read docs/planning/logging/01-essential-logging-api.md for requirements. Create:\n\n1. packages/soliplex_logging/test/log_level_test.dart - test comparisons\n2. packages/soliplex_logging/test/log_record_test.dart - test creation with span fields\n3. packages/soliplex_logging/test/console_sink_test.dart - test write behavior\n4. packages/soliplex_logging/test/logger_test.dart - test level filtering and span field passing\n5. packages/soliplex_logging/test/log_manager_test.dart - test singleton, sink management\n\nRun dart test packages/soliplex_logging to verify all pass.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.4: Create app integration files (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create Flutter app integration for soliplex_logging. Read docs/planning/logging/01-essential-logging-api.md for the full spec.\n\n1. Add soliplex_logging path dependency to pubspec.yaml\n2. Create lib/core/logging/loggers.dart - abstract final class Loggers with static fields: auth, http, activeRun, chat, room, router, quiz, config, ui\n3. Create lib/core/logging/log_config.dart - immutable LogConfig class with minimumLevel, consoleLoggingEnabled, copyWith, defaultConfig\n4. Create lib/core/logging/logging_provider.dart - LogConfigNotifier (AsyncNotifier), logConfigProvider, consoleSinkProvider with keepAlive and proper disposal\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.5: Write app integration tests (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Write tests for logging app integration. Read docs/planning/logging/01-essential-logging-api.md.\n\nCreate:\n1. test/core/logging/log_config_test.dart - test copyWith, defaultConfig\n2. test/core/logging/logging_provider_test.dart - test provider behavior, default while loading\n\nRun flutter test test/core/logging/ to verify.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.6: Validation checks

**Action:** Run these commands and verify all pass

```bash
dart format --set-exit-if-changed packages/soliplex_logging
dart analyze --fatal-infos packages/soliplex_logging
dart test packages/soliplex_logging
flutter analyze --fatal-infos
flutter test test/core/logging/
```

### Task 1.7: Gemini Review

**Action:** Use `mcp__gemini__read_files` with model `gemini-3-pro-preview`

**Dynamic file gathering:** At review time, collect all relevant files:

```bash
# Gather files for review (run these to get actual paths)
find docs/planning/logging/01-essential-logging-api.md
find packages/soliplex_logging -name "*.dart" -type f
find lib/core/logging -name "*.dart" -type f
find test/core/logging -name "*.dart" -type f
```

**Prompt:** "Review this logging implementation against the spec. Check: 1) Type-safe Loggers class, 2) Span-ready LogRecord with spanId/traceId, 3) Pure Dart (no Flutter imports in package), 4) Proper sink lifecycle in providers. Report any issues."

### Task 1.8: Codex Review

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Review the soliplex_logging implementation against docs/planning/logging/01-essential-logging-api.md. Check:\n1. Type-safe Loggers.x API (not string-based)\n2. LogRecord has spanId and traceId fields\n3. Package is pure Dart (no Flutter, no dart:io)\n4. consoleSinkProvider uses keepAlive and proper disposal\n5. No duplicate sink initialization\n6. All tests pass\n\nReport PASS or list issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

### Task 1.9: Commit and push

```bash
git add packages/soliplex_logging/ lib/core/logging/ test/core/logging/ pubspec.yaml
git commit -m "feat(logging): implement essential logging API (M01)

- Add soliplex_logging pure Dart package
- Type-safe Loggers class with static fields
- Span-ready LogRecord with spanId/traceId
- ConsoleSink using dart:developer
- LogConfigNotifier with SharedPreferences persistence
- consoleSinkProvider with proper lifecycle management"

git push -u origin logging-slice-1
```

---

## Milestone 02: API Documentation

**Spec:** `docs/planning/logging/02-api-documentation.md`
**Branch:** `logging-slice-2`

### Task 2.1: Create branch

```bash
git checkout -b logging-slice-2 logging-slice-1
```

### Task 2.2: Create package README (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create the README for soliplex_logging package. Read docs/planning/logging/02-api-documentation.md for requirements.\n\nCreate packages/soliplex_logging/README.md with:\n1. Package description (1-2 sentences)\n2. Installation instructions\n3. Quick start example showing raw LogManager API\n4. Note about type-safe Loggers.x usage in apps\n5. LogLevel reference table\n6. API reference for LogLevel, LogRecord (with span fields), LogSink, ConsoleSink, Logger, LogManager\n\nRun npx markdownlint-cli packages/soliplex_logging/README.md to verify.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 2.3: Create quickstart guide (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create the logging quickstart guide. Read docs/planning/logging/02-api-documentation.md for requirements.\n\nCreate docs/logging-quickstart.md with:\n1. Overview of logging architecture\n2. Type-safe Loggers.x usage examples\n3. List of available loggers (auth, http, activeRun, chat, room, router, quiz, config, ui)\n4. How to add a new logger\n5. Log level guidelines with examples table\n6. Span context for telemetry (future feature note)\n\nRun npx markdownlint-cli docs/logging-quickstart.md to verify.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 2.4: Add dartdoc comments (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Add dartdoc comments to all public APIs in soliplex_logging package. Read docs/planning/logging/02-api-documentation.md.\n\nUpdate these files with dartdoc:\n1. packages/soliplex_logging/lib/src/log_level.dart - document each level's purpose\n2. packages/soliplex_logging/lib/src/log_record.dart - document all fields including spanId/traceId\n3. packages/soliplex_logging/lib/src/log_sink.dart - document interface contract\n4. packages/soliplex_logging/lib/src/sinks/console_sink.dart - document configuration\n5. packages/soliplex_logging/lib/src/logger.dart - document each method\n6. packages/soliplex_logging/lib/src/log_manager.dart - document singleton usage\n\nRun dart doc packages/soliplex_logging to verify no warnings.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 2.5: Validation checks

**Action:** Run these commands and verify all pass

```bash
npx markdownlint-cli packages/soliplex_logging/README.md
npx markdownlint-cli docs/logging-quickstart.md
dart doc packages/soliplex_logging
dart analyze --fatal-infos packages/soliplex_logging
```

### Task 2.6: Gemini Review

**Action:** Use `mcp__gemini__read_files` with model `gemini-3-pro-preview`

**Dynamic file gathering:** At review time, collect all relevant files:

```bash
# Gather files for review (run these to get actual paths)
find docs/planning/logging/02-api-documentation.md
find packages/soliplex_logging/README.md
find docs/logging-quickstart.md
find packages/soliplex_logging/lib -name "*.dart" -type f
find lib/core/logging -name "*.dart" -type f
```

**Prompt:** "Review this documentation against the spec. Check: 1) README has both raw API and type-safe Loggers.x examples, 2) Quickstart covers all loggers, 3) All public APIs have dartdoc, 4) Log level guidelines are clear. Report any issues."

### Task 2.7: Codex Review

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Review the logging documentation against docs/planning/logging/02-api-documentation.md. Check:\n1. packages/soliplex_logging/README.md exists and is complete\n2. docs/logging-quickstart.md exists with Loggers.x usage guide\n3. All public APIs have dartdoc comments\n4. dart doc runs without errors\n5. Markdown linting passes\n\nReport PASS or list issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

### Task 2.8: Commit and push

```bash
git add packages/soliplex_logging/README.md docs/logging-quickstart.md packages/soliplex_logging/lib/
git commit -m "docs(logging): add API documentation (M02)

- Package README with installation and quick start
- Quickstart guide with type-safe Loggers.x usage
- Dartdoc comments on all public APIs
- Log level guidelines and examples"

git push -u origin logging-slice-2
```

---

## Milestone 03: Migration Strategy

**Spec:** `docs/planning/logging/03-migration-strategy.md`
**Branch:** `logging-slice-3`

### Task 3.1: Create branch

```bash
git checkout -b logging-slice-3 logging-slice-2
```

### Task 3.2: Migrate active_run_notifier.dart (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Migrate lib/core/providers/active_run_notifier.dart to use Loggers. Read docs/planning/logging/03-migration-strategy.md.\n\n1. Import lib/core/logging/loggers.dart\n2. Remove any _log() helper method\n3. Replace _log('message') with Loggers.activeRun.info('message')\n4. Use Loggers.activeRun.error('message', error: e, stackTrace: s) for errors\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 3.3: Migrate auth_notifier.dart (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Migrate lib/core/auth/auth_notifier.dart to use Loggers. Read docs/planning/logging/03-migration-strategy.md.\n\n1. Import lib/core/logging/loggers.dart\n2. Remove any _log() helper method\n3. Replace _log('message') with Loggers.auth.info('message')\n4. Use Loggers.auth.error('message', error: e, stackTrace: s) for errors\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 3.4: Integrate HTTP observer (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Integrate HTTP observer with Loggers. Read docs/planning/logging/03-migration-strategy.md.\n\nUpdate lib/core/providers/http_log_provider.dart:\n1. Import lib/core/logging/loggers.dart\n2. In onRequest: Loggers.http.debug('${event.method} ${event.uri}')\n3. In onResponse: Loggers.http.debug('${event.statusCode} ${event.method} ${event.uri}')\n4. In onError: Loggers.http.error('${event.method} ${event.uri}', error: event.exception)\n5. Keep existing HttpLogNotifier behavior alongside\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 3.5: Migrate router logging (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Migrate lib/core/router/app_router.dart to use Loggers. Read docs/planning/logging/03-migration-strategy.md.\n\n1. Import lib/core/logging/loggers.dart\n2. Replace any debugPrint with Loggers.router.debug()\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 3.6: Migrate feature files (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Migrate remaining feature files to use Loggers. Read docs/planning/logging/03-migration-strategy.md.\n\nSearch for and migrate:\n1. lib/features/home/home_screen.dart - use Loggers.ui\n2. lib/features/chat/*.dart - use Loggers.chat\n3. lib/features/room/*.dart - use Loggers.room\n4. lib/features/quiz/*.dart - use Loggers.quiz\n\nReplace debugPrint and _log patterns with appropriate Loggers.x calls.\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 3.7: Verify migration complete (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Verify logging migration is complete.\n\n1. Run: grep -r 'debugPrint' lib/ - should return no results (or only allowed cases)\n2. Run: grep -r 'void _log(' lib/ - should return no results\n3. Run: flutter analyze --fatal-infos\n4. Run: flutter test\n\nReport any remaining issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 3.8: Validation checks

**Action:** Run these commands and verify all pass

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
grep -r "debugPrint" lib/  # Should return nothing or only allowed cases
grep -r "void _log(" lib/  # Should return nothing
```

### Task 3.9: Gemini Review

**Action:** Use `mcp__gemini__read_files` with model `gemini-3-pro-preview`

**Dynamic file gathering:** At review time, collect all modified files:

```bash
# Gather files for review (run these to get actual paths)
find docs/planning/logging/03-migration-strategy.md
find lib/core/providers -name "*.dart" -type f
find lib/core/auth -name "*.dart" -type f
find lib/core/router -name "*.dart" -type f
find lib/features -name "*.dart" -type f | head -15
find lib/core/logging -name "*.dart" -type f
```

**Prompt:**

```text
Review the logging migration against the spec in 03-migration-strategy.md.

Check:
1. All _log() helper patterns replaced with Loggers.x calls
2. All debugPrint calls replaced with appropriate Loggers.x calls
3. HTTP observer uses Loggers.http for request/response/error logging
4. Correct log levels used (debug for requests, error for failures)
5. Error logging includes error and stackTrace parameters

Report PASS or list specific files/lines that still need migration.
```

### Task 3.10: Codex Review

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Final review of logging migration against docs/planning/logging/03-migration-strategy.md.\n\nVerify:\n1. grep -r 'debugPrint' lib/ returns no results\n2. grep -r 'void _log(' lib/ returns no results\n3. HTTP observer integrated with Loggers.http\n4. flutter analyze --fatal-infos passes\n5. flutter test passes\n\nReport PASS or list specific issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

### Task 3.11: Commit and push

```bash
git add lib/core/ lib/features/
git commit -m "refactor(logging): migrate to type-safe Loggers API (M03)

- Replace all _log() patterns with Loggers.x calls
- Replace all debugPrint calls with appropriate loggers
- Integrate HTTP observer with Loggers.http
- Use proper log levels (debug, info, error)"

git push -u origin logging-slice-3
```

---

## Completion Checklist

### Milestone 01

- [ ] Branch `logging-slice-1` created from `main`
- [ ] Package structure created (Task 1.2)
- [ ] Package tests written and passing (Task 1.3)
- [ ] App integration files created (Task 1.4)
- [ ] App integration tests passing (Task 1.5)
- [ ] Validation checks pass (Task 1.6)
- [ ] Gemini review: PASS (Task 1.7)
- [ ] Codex review: PASS (Task 1.8)
- [ ] Committed and pushed (Task 1.9)

### Milestone 02

- [ ] Branch `logging-slice-2` created from `logging-slice-1`
- [ ] Package README created (Task 2.2)
- [ ] Quickstart guide created (Task 2.3)
- [ ] Dartdoc comments added (Task 2.4)
- [ ] Validation checks pass (Task 2.5)
- [ ] Gemini review: PASS (Task 2.6)
- [ ] Codex review: PASS (Task 2.7)
- [ ] Committed and pushed (Task 2.8)

### Milestone 03

- [ ] Branch `logging-slice-3` created from `logging-slice-2`
- [ ] active_run_notifier.dart migrated (Task 3.2)
- [ ] auth_notifier.dart migrated (Task 3.3)
- [ ] HTTP observer integrated (Task 3.4)
- [ ] Router logging migrated (Task 3.5)
- [ ] Feature files migrated (Task 3.6)
- [ ] Migration verified complete (Task 3.7)
- [ ] Validation checks pass (Task 3.8)
- [ ] Gemini review: PASS (Task 3.9)
- [ ] Codex review: PASS (Task 3.10)
- [ ] Committed and pushed (Task 3.11)
