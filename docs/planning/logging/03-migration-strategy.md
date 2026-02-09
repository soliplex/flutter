# Milestone 03: Migration Strategy

**Status:** pending
**Depends on:** 02-api-documentation

## Objective

Migrate all existing `_log()` helper methods and `debugPrint` calls to use the
type-safe `Loggers.x` API. Integrate HTTP observer with the logger.

Moving this milestone up ensures the codebase is standardized early. This stops
"bleeding" (adding new ad-hoc logs) and ensures the new system is tested during
development of the advanced features.

## Pre-flight Checklist

- [ ] M01 and M02 complete
- [ ] Type-safe Loggers class is available
- [ ] Documentation exists for developers to reference
- [ ] Review all files with existing log patterns

## Files to Modify

### Core Layer

- [ ] `lib/core/providers/active_run_notifier.dart` - Has `_log()` pattern
- [ ] `lib/core/auth/auth_notifier.dart` - Has `_log()` pattern
- [ ] `lib/core/providers/http_log_provider.dart` - HTTP observer
- [ ] `lib/core/router/app_router.dart` - Router logging

### Feature Layer

- [ ] `lib/features/home/home_screen.dart` - Connectivity logging
- [ ] `lib/features/chat/` - Chat feature files with logging
- [ ] `lib/features/room/` - Room feature files with logging
- [ ] `lib/features/quiz/` - Quiz feature files with logging

### Client Package

- [ ] `packages/soliplex_client/lib/src/api/mappers.dart` - Quiz warnings

## Implementation Steps

### Step 1: Migrate active_run_notifier.dart

**File:** `lib/core/providers/active_run_notifier.dart`

- [ ] Import `loggers.dart`
- [ ] Remove `void _log(String message) => debugPrint(...)`
- [ ] Replace `_log('message')` calls with `Loggers.activeRun.info('message')`
- [ ] Use `Loggers.activeRun.error()` for error cases with error and stackTrace

```dart
// Before
void _log(String message) => debugPrint('[ActiveRun] $message');
_log('Starting run');

// After
Loggers.activeRun.info('Starting run');
Loggers.activeRun.error('Run failed', error: e, stackTrace: s);
```

### Step 2: Migrate auth_notifier.dart

**File:** `lib/core/auth/auth_notifier.dart`

- [ ] Import `loggers.dart`
- [ ] Remove `_log()` helper pattern
- [ ] Use `Loggers.auth.info()` for auth events
- [ ] Use `Loggers.auth.error()` for failures

### Step 3: Integrate HTTP observer

**File:** `lib/core/providers/http_log_provider.dart`

- [ ] Import `loggers.dart`
- [ ] In `onRequest`: `Loggers.http.debug('${event.method} ${event.uri}')`
- [ ] In `onResponse`:
  `Loggers.http.debug('${event.statusCode} ${event.method} ${event.uri}')`
- [ ] In `onError`:
  `Loggers.http.error('${event.method} ${event.uri}', error: event.exception)`
- [ ] Keep existing HttpLogNotifier behavior (UI display) alongside central
  logger

### Step 4: Migrate router logging

**File:** `lib/core/router/app_router.dart`

- [ ] Import `loggers.dart`
- [ ] Use `Loggers.router.debug()` for route changes

### Step 5: Migrate home_screen.dart

**File:** `lib/features/home/home_screen.dart`

- [ ] Import `loggers.dart`
- [ ] Use `Loggers.ui.info()` for connectivity/startup logging

### Step 6: Migrate chat feature

**Files:** `lib/features/chat/*.dart`

- [ ] Search for `debugPrint` and `_log` patterns
- [ ] Replace with `Loggers.chat.x()` calls
- [ ] Use appropriate log levels

### Step 7: Migrate room feature

**Files:** `lib/features/room/*.dart`

- [ ] Search for `debugPrint` and `_log` patterns
- [ ] Replace with `Loggers.room.x()` calls
- [ ] Use appropriate log levels

### Step 8: Migrate quiz feature

**Files:** `lib/features/quiz/*.dart`

- [ ] Search for `debugPrint` and `_log` patterns
- [ ] Replace with `Loggers.quiz.x()` calls
- [ ] Use appropriate log levels

### Step 9: Migrate client mappers

**File:** `packages/soliplex_client/lib/src/api/mappers.dart`

- [ ] If logging needed: Add soliplex_logging dependency to soliplex_client
- [ ] Or remove debugPrint calls if they're temporary debug code

### Step 10: Search for remaining patterns

- [ ] Run `grep -r "debugPrint" lib/` to find remaining calls
- [ ] Run `grep -r "void _log(" lib/` to find remaining patterns
- [ ] Migrate or remove each one

### Step 11: Update tests

- [ ] Update any tests that mock or verify the old `_log()` pattern
- [ ] Ensure tests still pass with new logging

## Logger Mapping

| Old Pattern | New Pattern |
|-------------|-------------|
| `_log('...')` in ActiveRunNotifier | `Loggers.activeRun.info('...')` |
| `_log('...')` in AuthNotifier | `Loggers.auth.info('...')` |
| `debugPrint('[HTTP] ...')` | `Loggers.http.debug('...')` |
| `debugPrint('[Router] ...')` | `Loggers.router.debug('...')` |
| `debugPrint` in chat features | `Loggers.chat.x('...')` |
| `debugPrint` in room features | `Loggers.room.x('...')` |
| `debugPrint` in quiz features | `Loggers.quiz.x('...')` |

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze --fatal-infos`
- [ ] `flutter test` passes
- [ ] `grep -r "debugPrint" lib/` returns no results (or only allowed cases)
- [ ] `grep -r "void _log(" lib/` returns no results

### Manual Verification

- [ ] Run app and verify HTTP requests appear in console via `Loggers.http`
- [ ] Run app and verify auth events appear via `Loggers.auth`
- [ ] Trigger errors and verify they're logged with stack traces

### Review Gates

#### Gemini Review

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`
**File limit:** 15 files per call (batch if needed)

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
  "prompt": "Verify the logging migration is complete. Run these checks:\n\n1. grep -r 'debugPrint' lib/ - should return no results\n2. grep -r 'void _log(' lib/ - should return no results\n3. All files in lib/core/providers/, lib/core/auth/, lib/features/ use Loggers.x\n4. HTTP observer logs requests, responses, and errors via Loggers.http\n5. flutter analyze --fatal-infos passes\n6. flutter test passes\n\nReport PASS or list specific issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

- [ ] Codex review: PASS

## Success Criteria

- [ ] All `_log()` patterns migrated to `Loggers.x`
- [ ] All `debugPrint` calls migrated (except Flutter-specific debug code)
- [ ] HTTP observer integrated with `Loggers.http`
- [ ] All tests pass
- [ ] No analyzer warnings
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
