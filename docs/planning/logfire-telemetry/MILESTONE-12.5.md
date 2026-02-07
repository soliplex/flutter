# Milestone 12.5 — Breadcrumbs

**Phase:** 2 — Enhanced Context (P1)\
**Status:** Pending\
**Blocked by:** 12.2\
**PR:** —

---

## Goal

When a crash or error occurs, attach the last N log records as
contextual breadcrumbs to help reconstruct what happened.

---

## Changes

- On ERROR/FATAL, `BackendLogSink` reads last 20 records from its
  injected `MemorySink` instance (ring buffer already exists). The
  `memorySink` parameter is set via `backendLogSinkProvider` in 12.3.
- Attaches as `"breadcrumbs": [...]` array in the crash payload
- Each breadcrumb includes: timestamp, level, logger, message, **category**
- **Categories** help support filter noise:
  - `ui` — navigation, taps, screen transitions
  - `network` — HTTP requests, connectivity changes
  - `system` — lifecycle events, permission changes
  - `user` — login, logout, explicit user actions
- Category is derived from `loggerName` convention (e.g. `Router.*` → `ui`,
  `Http.*` → `network`) or from an explicit `breadcrumb_category` attribute

### Breadcrumb JSON structure

```json
{
  "timestamp": "2026-02-06T11:59:50.000Z",
  "level": "info",
  "logger": "Router",
  "message": "Navigated to /chat",
  "category": "ui"
}
```

---

## Unit Tests

- `test/sinks/backend_log_sink_breadcrumb_test.dart`:
  - ERROR log attaches last 20 breadcrumbs from MemorySink
  - FATAL log attaches breadcrumbs
  - INFO log does not attach breadcrumbs
  - Category derived from loggerName (Router → ui, Http → network)
  - Explicit `breadcrumb_category` attribute overrides derived category
  - Fewer than 20 records in MemorySink → all attached
  - Empty MemorySink → empty breadcrumbs array

---

## Integration Tests

- `test/integration/breadcrumb_crash_payload_test.dart` — Log 25
  records via Logger, then log an ERROR. Verify the HTTP payload
  includes exactly 20 breadcrumbs with correct categories.

---

## Acceptance Criteria

- [ ] Crash payloads include last 20 breadcrumb records
- [ ] Breadcrumbs categorized (ui/network/system/user)
- [ ] Breadcrumbs come from existing MemorySink (no duplication)
- [ ] Tests verify breadcrumb attachment and categorization on fatal log

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

### Codex Review (up to 3 iterations)

After Gemini passes, submit to Codex for cross-milestone consistency.

- [ ] Codex passes with no blockers (or issues resolved within 3 iterations)
