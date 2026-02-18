# Plan: Export Logs Feature

## Context

The log viewer screen has no way to export logs off-device. Users on mobile,
desktop, or web can view logs in-app but can't share them for debugging or
support. We'll add a download button next to the existing "clear logs" button
that exports the currently **filtered** log records as JSONL. Native platforms
get gzipped output via the OS share sheet; web gets a raw `.jsonl` browser
download.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Native export | OS share sheet via `share_plus` | Standard platform UX |
| Web export | Blob + anchor download (`package:web`) | No new dependency |
| Compression | gzip on native; raw on web | Web capped at ~400 KB / 2000 records |
| Format | JSONL (one JSON object per line) | Grep-friendly, streaming-parseable |
| Scope | Filtered records only | Respects level/logger/search filters |
| Serialization | Extension method in feature layer | Keeps `soliplex_logging` model lean |
| File saver | Abstract class + factory + Riverpod provider | Matches `auth_storage.dart` pattern; enables test mocking |
| Export order | Chronological (oldest-first) | Standard for log analysis tools (`jq`, aggregators) |
| iPad / macOS | Pass `sharePositionOrigin` from button `RenderBox` | Required for popover positioning; crash without it |

## Resolved Review Findings

Issues identified by Codex, Claude, and Gemini reviews — all addressed in
the milestone plans below.

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | High | iPad/macOS crash — missing `sharePositionOrigin` | `LogFileSaver.save()` accepts `Rect? shareOrigin`; screen computes from `RenderBox` |
| 2 | High | Patrol E2E hangs — OS share sheet blocks test | Mock saver via `logFileSaverProvider` override; E2E only asserts button state, does not tap export |
| 3 | Medium | `share_plus` API wrong | Verify installed version; use `Share.shareXFiles` or `SharePlus.instance.share(ShareParams(...))` per actual API |
| 4 | Medium | `utf8.encode` returns `List<int>`, not `Uint8List` | Use `Uint8List.fromList(utf8.encode(...))` |
| 5 | Medium | Pending records missed on export | Call `_flushPending()` at start of `exportFilteredAsJsonlBytes()` |
| 6 | Medium | Facade uses top-level function, not class | Abstract `LogFileSaver` + `createLogFileSaver()` factory + `logFileSaverProvider` |
| 7 | Low | `toExportJson()` on core model | Extension method in `lib/features/log_viewer/` instead |
| 8 | Low | Filename colons illegal on Windows/Android | Use `YYYY-MM-DD_HH-mm-ss` format (underscores + dashes) |
| 9 | Low | Async gap — widget may unmount before SnackBar | `mounted` check after `await saveLogFile(...)` |

## Milestones

```text
Milestone 1 ─── Milestone 2 ─── Milestone 3
serialization    UI + platform    patrol E2E
(pure Dart)      (share_plus)     (integration)
```

---

### M1: Serialization ([details](milestone-1-serialization.md))

**Branch**: `feat/log-export-serialization`

- [x] Create `lib/features/log_viewer/log_record_export.dart` — extension with `toExportJson()` + `_safeAttributes`/`_coerceValue` helpers
- [x] Edit `lib/features/log_viewer/log_viewer_controller.dart` — add `exportFilteredAsJsonlBytes()`, flush pending before export
- [x] Create `test/features/log_viewer/log_record_export_test.dart` — shape, UTC, null omission, attribute coercion, error toString
- [x] Create `test/features/log_viewer/log_viewer_controller_test.dart` — valid JSONL, respects filters, empty state, flush, chronological order
- [x] **Gate: pre-commit hooks pass** (dart format, flutter analyze, dart analyze packages, pymarkdown, gitleaks)
- [x] **Gate: `dart test` in `packages/soliplex_logging/`** — no regressions
- [x] **Gate: `flutter test`** — full suite passes
- [ ] PR created, reviewed, merged to `main`

---

### M2: Platform File Saver + UI Button ([details](milestone-2-platform-ui.md))

**Branch**: `feat/log-export-ui` (from `main` after M1 merged)

- [x] Edit `pubspec.yaml` — add `share_plus` dependency
- [x] Run `flutter pub get` — resolves cleanly
- [x] Create `lib/features/log_viewer/log_file_saver.dart` — abstract `LogFileSaver` class + `createLogFileSaver()` factory + `logFileSaverProvider`
- [x] Create `lib/features/log_viewer/log_file_saver_native.dart` — gzip + share sheet + `sharePositionOrigin`
- [x] Create `lib/features/log_viewer/log_file_saver_web.dart` — Blob + anchor download + `URL.revokeObjectURL`
- [x] Edit `lib/features/log_viewer/log_viewer_screen.dart` — add `Icons.download` button in `Builder`, `_exportLogs()` with `RenderBox` origin, `mounted` check, filesystem-safe timestamp
- [x] Edit `test/features/log_viewer/log_viewer_screen_test.dart` — button disabled when empty, enabled with records, correct icon/tooltip, `FakeLogFileSaver` override
- [x] Verify `share_plus` API against installed version (finding #3)
- [x] **Gate: pre-commit hooks pass** (dart format, flutter analyze, dart analyze packages, pymarkdown, gitleaks)
- [x] **Gate: `flutter test`** — full suite passes (no regressions from new provider)
- [ ] **Gate: manual — Chrome** — browser downloads `.jsonl` with filtered content
- [x] **Gate: manual — macOS** — saves `.jsonl.gz` to Downloads, snackbar with copy path
- [ ] **Gate: manual — iPad** (if available) — share sheet popover anchored to button
- [ ] PR created, reviewed, merged to `main`

---

### M3: Patrol E2E Test ([details](milestone-3-patrol-e2e.md))

**Branch**: `test/log-export-e2e` (from `main` after M2 merged)

- [ ] Edit `integration_test/patrol_helpers.dart` — add `NoOpLogFileSaver` + `logFileSaverProvider` override in both `pumpTestApp` and `pumpAuthenticatedTestApp`
- [ ] Edit `integration_test/settings_test.dart` — append `patrolTest('settings - log viewer export button (no-auth)', ...)`
- [ ] E2E test verifies: button enabled with boot logs, button disabled after clear, `expectNoErrors()` — does NOT tap export (avoids share sheet hang)
- [ ] **Gate: pre-commit hooks pass** (dart format, flutter analyze, dart analyze packages, pymarkdown, gitleaks)
- [ ] **Gate: `flutter test`** — full unit/widget suite passes
- [ ] **Gate: existing Patrol tests pass** — `dart pub global run patrol_cli test -t "smoke"`, `dart pub global run patrol_cli test -t "settings - navigate"`, `dart pub global run patrol_cli test -t "settings - network"`
- [ ] **Gate: new Patrol test passes** — `dart pub global run patrol_cli test -t "log viewer export"` (no-auth backend)
- [ ] PR created, reviewed, merged to `main`

---

## Pre-commit Hooks Reference

These hooks run automatically on every `git commit` via `.pre-commit-config.yaml`:

| Hook | What it checks |
|------|----------------|
| `no-commit-to-branch` | Blocks direct commits to `main`/`master` |
| `check-merge-conflict` | No leftover conflict markers |
| `check-toml` / `check-yaml` | Config file syntax |
| `gitleaks` | No secrets or credentials committed |
| `dart format --set-exit-if-changed` | Formatting (excludes generated schema) |
| `flutter analyze --fatal-infos` | Zero warnings/hints/errors (main app) |
| `dart analyze packages` (`tool/analyze_packages.py`) | Zero issues in `soliplex_client`, `soliplex_logging`, etc. |
| `pymarkdown` | Markdown lint on all `.md` files |

All milestone gate checkboxes marked "pre-commit hooks pass" require ALL of
the above to succeed.

---

## Future: Migration to DiskQueue Export

The current implementation exports from `MemorySink` (in-memory ring buffer,
~2000 records). A future enhancement could export from `DiskQueue` for access
to persisted logs (~10 MB / thousands of records surviving app restarts).

### Why not now

`DiskQueue` has no read-all API — it exposes only `drain(count)` / `confirm()`
(a streaming consume pattern designed for reliable backend shipping). Reading
all records without consuming them requires either:

- A new `snapshot()` or `readAll()` method on the abstract `DiskQueue` class
  (+ implementations in `disk_queue_io.dart` and `disk_queue_web.dart`)
- Or directly reading the `log_queue.jsonl` file (bypasses the abstraction)

### What changes per layer

| Layer | Change needed | Effort |
|-------|---------------|--------|
| `log_record_export.dart` | **None** — DiskQueue records are already `Map<String, Object?>`, same shape as `toExportJson()` output. Could skip the extension entirely. | Zero |
| `log_viewer_controller.dart` | Replace `_filteredRecords.map(toExportJson)` with DiskQueue read. Filtering needs adaptation (Maps, not `LogRecord`). | Small |
| `log_file_saver*.dart` | **None** — accepts `Uint8List`, source-agnostic | Zero |
| `log_viewer_screen.dart` | **None** — calls controller, gets bytes | Zero |
| `DiskQueue` abstract API | Add `Future<List<Map<String, Object?>>> snapshot()` method + implementations | Medium |
| `disk_queue_io.dart` | Read `log_queue.jsonl` without advancing confirmed pointer | Small |
| `disk_queue_web.dart` | Return copy of in-memory queue | Trivial |

**Estimated total: ~1-2 days.**

### Shortcut: raw file export

The native `DiskQueue` already writes `log_queue.jsonl` — the exact same
format we export. A future "export full disk log" could just gzip and share
the raw file without any JSON re-serialization:

```dart
// Hypothetical — zero serialization cost
final file = File('${dir.path}/log_queue.jsonl');
final bytes = await file.readAsBytes();
await saver.save(filename: 'soliplex_full_log.jsonl', bytes: bytes);
```

This bypasses filtering but gives maximum coverage for support/debugging.

### Design note

The M1-M3 architecture was deliberately chosen to make this migration cheap:

- The `LogFileSaver` abstraction (M2) is byte-agnostic — it doesn't care
  where the bytes come from
- The `toExportJson()` extension (M1) is additive — DiskQueue export can
  coexist alongside MemorySink export (user picks "export visible" vs
  "export all persisted")
- The UI button (M2) can offer both options via a popup menu in a future PR
