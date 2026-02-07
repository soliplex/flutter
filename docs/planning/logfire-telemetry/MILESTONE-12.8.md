# Milestone 12.8 — RUM / Performance Metrics

**Phase:** 3 — Diagnostics (P2)\
**Status:** Pending\
**Blocked by:** 12.2\
**PR:** —

---

## Goal

Capture basic performance metrics for the Flutter app.

---

## Changes

- **Cold start:** Measure `main()` to first frame via
  `WidgetsBinding.instance.addPostFrameCallback`
- **Slow frames:** `SchedulerBinding.instance.addTimingsCallback` to
  detect frames exceeding 16ms
- **Route transitions:** `NavigatorObserver` logs timestamps on
  `didPush`/`didPop`
- **HTTP latency:** Already have `HttpObserver` — log request duration
  as attributes

All metrics logged as `info` with `{"metric": "cold_start", "ms": 1200}`
style attributes. Backend/Logfire aggregates.

---

## Unit Tests

- `test/core/logging/cold_start_metric_test.dart`:
  - Cold start duration captured after first frame callback
  - Metric logged with correct attributes
- `test/core/logging/slow_frame_metric_test.dart`:
  - Frames exceeding threshold detected and logged
  - Frames under threshold not logged
- `test/core/logging/route_timing_test.dart`:
  - NavigatorObserver logs `didPush` with route name and timestamp
  - NavigatorObserver logs `didPop` with route name and timestamp

---

## Integration Tests

- `test/integration/rum_metrics_pipeline_test.dart` — Simulate cold
  start via post-frame callback. Verify metric record arrives at
  BackendLogSink mock with correct attributes.

---

## Acceptance Criteria

- [ ] Cold start time captured and logged
- [ ] Slow frames detected and logged (with threshold)
- [ ] Route transition timing logged
- [ ] HTTP latency logged as structured attributes

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
