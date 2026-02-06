# Milestone 04: Log Viewer UI

**Status:** completed
**Depends on:** 01-essential-logging-api

## Objective

Create an in-app log viewer screen accessible from Settings that displays,
filters, and live-updates log entries from the in-memory ring buffer (MemorySink).

## Pre-flight Checklist

- [x] M01 complete (essential logging API working)
- [x] MemorySink ring buffer implemented (M09)
- [x] memorySinkProvider exists in logging_provider.dart
- [x] 9 typed Loggers available

## Scope

**In scope:**

- Log viewer screen with filter bar and list
- LogLevelBadge color-coded widget
- LogRecordTile with expandable error/stackTrace
- Settings integration (tile with live count)
- Router integration (`/settings/logs`)

**Out of scope (deferred):**

- Log export/download functionality
- LogFormatter class (LogRecord.toString() suffices)
- Conditional imports for platform export

## Files to Create

### UI Files

- [x] `lib/features/log_viewer/widgets/log_level_badge.dart`
- [x] `lib/features/log_viewer/widgets/log_record_tile.dart`
- [x] `lib/features/log_viewer/log_viewer_screen.dart`
- [x] `test/features/log_viewer/log_viewer_screen_test.dart`
- [x] `test/features/log_viewer/widgets/log_level_badge_test.dart`

## Files to Modify

- [x] `lib/features/settings/settings_screen.dart` - Add `_LogViewerTile`
- [x] `lib/core/router/app_router.dart` - Add `/settings/logs` sub-route
- [x] `docs/planning/logging/04-log-viewer-ui.md` - This file

## Implementation Steps

### Step 1: Update milestone doc

- [x] Reflect simplified scope (no export, no LogFormatter)

### Step 2: LogLevelBadge widget

- [x] Container with colored background + label text
- [x] Color mapping via SymbolicColors extension

### Step 3: LogRecordTile widget

- [x] Layout: badge, timestamp, logger name, message
- [x] ExpansionTile for records with error/stackTrace

### Step 4: LogViewerScreen

- [x] ConsumerStatefulWidget with AppShell
- [x] Local filter state (levels, logger, search)
- [x] O(1) per-event filtering with `_filteredRecords` list
- [x] FilterChip widgets for level and logger
- [x] TextField for search
- [x] ListView.separated with newest-first ordering
- [x] Empty state matching NetworkInspector pattern

### Step 5: Settings integration

- [x] `_LogViewerTile` with StreamBuilder for live count

### Step 6: Router integration

- [x] `/settings/logs` sub-route with NoTransitionPage

### Step 7: Tests

- [x] log_viewer_screen_test.dart
- [x] log_level_badge_test.dart

### Step 8: Quality gates

- [ ] `dart format`
- [ ] `dart analyze` (0 issues)
- [ ] `flutter test` (all pass)
- [ ] Coverage >= 85% on new code

## Key Patterns Reused

- AppShell + ShellConfig (from network_inspector_screen.dart)
- Empty state (from network_inspector_screen.dart)
- SymbolicColors (from color_scheme_extensions.dart)
- _NetworkRequestsTile pattern (from settings_screen.dart)
- NoTransitionPage sub-route (from app_router.dart)

## Validation Gate

### Automated Checks

- [ ] `dart format --set-exit-if-changed .`
- [ ] `dart analyze --fatal-infos`
- [ ] `flutter test` passes
- [ ] Test coverage >= 85% on new code

### Manual Verification

- [ ] Navigate to Settings > View Logs
- [ ] Verify logs appear and update in real-time
- [ ] Test level filter works
- [ ] Test logger filter works
- [ ] Test search filter works
- [ ] Test clear button works

## Success Criteria

- [ ] Log viewer accessible from Settings > View Logs
- [ ] Level filter shows only matching logs
- [ ] Logger filter shows only matching logs
- [ ] Search filters by message content (case-insensitive)
- [ ] Live updates work (new logs appear via stream)
- [ ] Clear button empties list
- [ ] Expandable error/stackTrace on relevant entries
- [ ] All tests pass
