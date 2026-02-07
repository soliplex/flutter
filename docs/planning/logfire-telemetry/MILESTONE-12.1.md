# Milestone 12.1 — LogRecord Attributes

**Phase:** 1 — Core (P0)\
**Status:** Pending\
**Blocked by:** —\
**PR:** —

---

## Goal

Add structured attributes to `LogRecord` so log export can carry
contextual key-value pairs (e.g. `user_id`, `http_status`, `view_name`).

---

## Changes

**`packages/soliplex_logging/lib/src/log_record.dart`:**

- Add `final Map<String, Object> attributes` field with default `const {}`
- Add `copyWith(...)` method — `LogRecord` is `@immutable` with `final`
  fields, so `LogSanitizer` (12.2) needs `copyWith()` to return a new
  sanitized record. Returns a new `LogRecord` with overridden fields.
- Non-breaking: existing constructor call sites compile unchanged

**`packages/soliplex_logging/lib/src/logger.dart`:**

- Add optional `Map<String, Object>? attributes` parameter to `info()`,
  `debug()`, `warning()`, `error()`, `fatal()`, `trace()`
- Pass through to `LogRecord` constructor

**`packages/soliplex_logging/lib/src/log_record.dart` (toString):**

- Include non-empty attributes in `toString()` output for debug visibility

---

## Unit Tests

- `test/log_record_test.dart` — attributes stored, default empty, included
  in `toString()`, `copyWith` returns new record with overridden fields,
  `copyWith` with no args returns equivalent record
- `test/logger_test.dart` — attributes passed through to `LogRecord`

---

## Integration Tests

- `test/integration/attributes_through_sink_test.dart` — Log a message
  with attributes via `Logger`, verify the `LogRecord` captured by
  `MemorySink` carries the attributes intact. Confirms the full path:
  `Logger.info(attributes:) → LogManager → LogSink.write() → LogRecord`

---

## Acceptance Criteria

- [ ] `LogRecord` has `attributes` field, default `const {}`
- [ ] `LogRecord` has `copyWith(...)` method (required for sanitizer)
- [ ] All `Logger` methods accept optional `attributes`
- [ ] Existing call sites compile without changes
- [ ] Integration: attributes survive Logger → LogManager → sink pipeline

---

## Gates

All gates must pass before the milestone PR can merge.

### Automated

- [ ] **Format:** `dart format --set-exit-if-changed .` — zero changes
- [ ] **Analyze:** `dart analyze` — zero issues (errors, warnings, hints)
- [ ] **Unit tests:** all pass, coverage ≥ 85% for changed files
- [ ] **Integration tests:** all pass

### Gemini Review (up to 3 iterations)

Pass this file and all changed `.dart` source files to Gemini Pro 3
via `mcp__gemini__read_files` (model: `gemini-3-pro-preview`).

- [ ] Gemini passes with no blockers (or issues resolved within 3 iterations)
