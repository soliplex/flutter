# Milestone 12.6 — Remote Log Level Control

**Phase:** 2 — Enhanced Context (P1)\
**Status:** Pending\
**Blocked by:** 12.3\
**PR:** —

---

## Goal

Allow the backend to control the app's minimum log level without pushing
an app update.

---

## Changes

### Backend endpoint

`GET /api/v1/config/logging` — see [BACKEND.md](./BACKEND.md)
for the backend specification.

```json
{
  "min_level": "debug",
  "modules": {"http": "trace", "auth": "debug"}
}
```

### Flutter client

**`lib/core/logging/remote_log_config_provider.dart` (new):**

- On startup and every 10 minutes, fetch config from backend
- Update `LogManager.minimumLevel` and per-logger overrides via Riverpod
- Graceful fallback: if endpoint unreachable, use local defaults
- No crash or error on network failure

---

## Unit Tests

- `test/core/logging/remote_log_config_provider_test.dart`:
  - Config fetched on initialization
  - LogManager.minimumLevel updated from response
  - Per-module overrides applied to individual loggers
  - Fallback to local defaults on network error
  - Periodic refresh (advance fake timer 10 min → re-fetch)
  - Invalid JSON response handled gracefully

---

## Integration Tests

- `test/integration/remote_log_level_test.dart` — Mock backend returns
  `min_level: "error"`. Verify debug logs are filtered out by LogManager.
  Update mock to return `min_level: "trace"`. Trigger refresh. Verify
  trace logs now pass through.

---

## Acceptance Criteria

- [ ] App fetches log config on startup
- [ ] Log level changes without app restart
- [ ] Per-module overrides supported
- [ ] Graceful fallback if endpoint unreachable

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
