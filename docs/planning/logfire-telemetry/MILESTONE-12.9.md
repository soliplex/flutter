# Milestone 12.9 — Screenshot on Error

**Phase:** 3 — Diagnostics (P2)\
**Status:** Pending\
**Blocked by:** 12.2\
**PR:** —

---

## Goal

Capture a screenshot when an error occurs for visual debugging.

---

## Changes

- Wrap `MaterialApp` in `RepaintBoundary` with `GlobalKey`
- On ERROR/FATAL, capture via `toImage()` → PNG bytes
- **Encode in background isolate** — base64 encoding a retina screenshot
  (5MB+) on the UI thread causes visible jank. Use `compute()` for
  PNG-to-base64 conversion.
- Upload screenshot as separate POST (reference by ID in error log) —
  embedding large base64 in JSON payload bloats the log pipeline
- Thumbnail option: downscale to 480p before encoding (reduces to ~50 KB)

---

## Unit Tests

- `test/core/logging/screenshot_capture_test.dart`:
  - Capture returns PNG bytes from RepaintBoundary
  - Graceful failure when RepaintBoundary unavailable (returns null)
  - Thumbnail downscale produces smaller image
- `test/core/logging/screenshot_upload_test.dart`:
  - Screenshot uploaded as separate POST
  - Error log references screenshot by ID
  - Upload failure does not block error log delivery

---

## Integration Tests

- `test/integration/screenshot_error_flow_test.dart` — Trigger an error
  with RepaintBoundary present. Verify screenshot uploaded to mock
  endpoint and error log payload contains screenshot reference ID.

---

## Acceptance Criteria

- [ ] Screenshot captured on error
- [ ] PNG-to-base64 runs in background isolate (not UI thread)
- [ ] Image uploaded separately, referenced by ID in error log
- [ ] Does not crash if RepaintBoundary unavailable
- [ ] Does not jank the UI on capture

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
