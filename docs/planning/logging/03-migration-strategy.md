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

- [ ] **Gemini Review:** Run `mcp__gemini__read_files` with model
  `gemini-3-pro-preview` passing:
  - `docs/planning/logging/03-migration-strategy.md`
  - All modified `.dart` files listed in "Files to Modify"
- [ ] **Codex Review:** Run `mcp__codex__codex` to verify migration is complete
  and consistent

## Success Criteria

- [ ] All `_log()` patterns migrated to `Loggers.x`
- [ ] All `debugPrint` calls migrated (except Flutter-specific debug code)
- [ ] HTTP observer integrated with `Loggers.http`
- [ ] All tests pass
- [ ] No analyzer warnings
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
