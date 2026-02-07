# Logfire Telemetry — Execution Plan

## How to Use This Plan

Each milestone is a single PR with its own file in this directory.
Phase 1 milestones are sequential (12.1→12.2→12.3, with 12.4 parallel
to 12.3). Phase 2 and 3 milestones can be worked independently once
their dependencies are met.

## Resumption Context

- **Branch:** `feat/otel`
- **Base:** `main`
- **Spec:** `docs/planning/logging/12-opentelemetry-integration.md`
- **Logfire:** Account ready, write token available via `LOGFIRE_TOKEN`
- **Backend repo:** `~/dev/soliplex` (Python ingest endpoint in 12.4)
- **Constraint:** DoD — no commercial SaaS. Self-hosted/open-source only.

---

## Milestones

### Phase 1 — Core (P0)

| # | Name | Milestone | Blocked by | Review |
|---|------|-----------|------------|--------|
| 12.1 | LogRecord attributes | [MILESTONE-12.1](./MILESTONE-12.1.md) | — | Gemini |
| 12.2 | BackendLogSink | [MILESTONE-12.2](./MILESTONE-12.2.md) | 12.1 | Gemini + Codex |
| 12.3 | App integration | [MILESTONE-12.3](./MILESTONE-12.3.md) | 12.2 | Gemini |
| 12.4 | Backend ingest | [MILESTONE-12.4](./MILESTONE-12.4.md) | 12.2 | Backend (no frontend gates) |

### Phase 2 — Enhanced Context (P1)

| # | Name | Milestone | Blocked by | Review |
|---|------|-----------|------------|--------|
| 12.5 | Breadcrumbs | [MILESTONE-12.5](./MILESTONE-12.5.md) | 12.2 | Gemini + Codex |
| 12.6 | Remote log level | [MILESTONE-12.6](./MILESTONE-12.6.md) | 12.3 | Gemini |
| 12.7 | Error fingerprinting | [MILESTONE-12.7](./MILESTONE-12.7.md) | 12.4 | Backend (no frontend gates) |

### Phase 3 — Diagnostics (P2)

| # | Name | Milestone | Blocked by | Review |
|---|------|-----------|------------|--------|
| 12.8 | RUM / performance | [MILESTONE-12.8](./MILESTONE-12.8.md) | 12.2 | Gemini + Codex |
| 12.9 | Screenshot on error | [MILESTONE-12.9](./MILESTONE-12.9.md) | 12.2 | Gemini |

---

## Gate Process

Every frontend milestone has automated gates and AI review gates.

### Automated Gates (every frontend milestone)

1. **Format:** `dart format --set-exit-if-changed .` — zero changes
2. **Analyze:** `dart analyze` — zero issues (errors, warnings, hints)
3. **Unit tests:** all pass, coverage ≥ 85% for changed files
4. **Integration tests:** all pass

### Gemini Review (every frontend milestone, up to 3 iterations)

Pass the milestone `.md` file and all relevant source `.dart` files to
Gemini Pro 3 via `mcp__gemini__read_files` (model: `gemini-3-pro-preview`).

- Gemini checks for: correctness, cross-document consistency, source
  code alignment, missed edge cases
- If Gemini finds blockers → fix and re-submit (up to 3 iterations)
- If Gemini passes on first review → no further iterations needed

### Codex Review (every other milestone, up to 3 iterations)

Milestones **12.2, 12.5, 12.8** get an additional Codex review after
Gemini passes.

- Codex checks for: cross-milestone consistency, architectural issues,
  contract mismatches
- If Codex finds blockers → fix and re-submit (up to 3 iterations)
- If Codex passes on first review → no further iterations needed

---

## Observability Gap Analysis

Comprehensive assessment of what this **pragmatic field-support logging
framework** covers after all phases. This is NOT a Crashlytics replacement
— the goal is: support engineer gets a bug report, queries Logfire,
reconstructs what happened.

### Coverage After Phase 1 (Core)

| Capability | Status | Notes |
|------------|--------|-------|
| Structured logging | Covered | LogRecord + attributes |
| Remote log export | Covered | BackendLogSink → Logfire |
| Dart crash capture | Covered | FlutterError + PlatformDispatcher hooks |
| Offline persistence | Covered | DiskQueue (JSONL write-ahead) |
| PII/classified redaction | Covered | LogSanitizer (P0 for DoD) |
| Session correlation | Covered | UUID sessionId + userId |
| Install ID (device Y) | Covered | Per-install UUID for cross-session queries |
| Session start marker | Covered | Device/app fingerprint on startup |
| Connectivity history | Covered | `network_changed` events logged |
| Server-received timestamp | Covered | Backend stamps server time (clock skew) |
| Poison pill protection | Covered | Bad batches discarded after 3 retries |
| Record size guard | Covered | Oversized records truncated at 64 KB |
| In-app log viewer | Covered | MemorySink + existing UI |
| Cross-platform support | Covered | Same endpoint all platforms |
| Lifecycle-aware flush | Covered | paused/hidden/visibilitychange |

### Coverage After Phase 2 (Enhanced Context)

| Capability | Status | Notes |
|------------|--------|-------|
| Categorized breadcrumbs | Covered | Last N logs with ui/network/system/user categories |
| Remote log level control | Covered | Backend config endpoint |
| Error grouping / fingerprinting | Covered | Backend-side (Python) |

### Coverage After Phase 3 (Diagnostics)

| Capability | Status | Notes |
|------------|--------|-------|
| Cold start timing | Covered | RUM metrics |
| Slow frame detection | Covered | SchedulerBinding callback |
| Route transition timing | Covered | NavigatorObserver |
| HTTP latency metrics | Covered | HttpObserver attributes |
| Screenshot on error | Covered | RepaintBoundary capture |

### Remaining Gaps (Accepted or Deferred)

| Capability | Status | Rationale |
|------------|--------|-----------|
| Native crash capture (SIGSEGV) | **Out of scope** | Not a Crashlytics replacement. Requires OS-level signal handlers (XL effort). Rely on `adb logcat` / Console.app. Most crashes are Dart-level and captured. |
| Session replay (video) | **Out of scope** | Not a Crashlytics replacement. Screenshot-on-error is the pragmatic substitute. |
| Distributed tracing (spans) | **Deferred** | Phase 1 is log-only. When Python backend adds tracing, can propagate `traceparent` headers from HTTP client and attach trace context to logs. Evaluate `dartastic_opentelemetry` if their SDK matures. |
| Metrics (counters, histograms) | **Deferred** | RUM captures basic timing as log attributes. True OTel metrics (counters, histograms, gauges) can be added when the Python backend supports metrics ingest. |
| Alerting | **Partial** | Error fingerprinting (12.7) enables threshold-based alerts on the backend. Not a Flutter-side concern. |
| Log search / analytics | **Delegated** | Logfire provides SQL-like querying on structured attributes. No Flutter-side work needed. |

### Field Support Readiness Grade: **B+**

**"User X on device Y had issue Z at time T" — can we reconstruct that?**

After all 3 phases: **Yes**, for Dart-level issues. The support engineer
can query Logfire by sessionId, see the session start marker (device,
app version, OS), connectivity history, categorized breadcrumbs leading
up to the error, the full stack trace, and the sanitized attributes.

For a DoD Flutter app with self-hosted constraints, this is a
**pragmatic field-support logging framework**.

---

## Progress Tracker

| Sub-Milestone | Phase | Status | PR |
|---------------|-------|--------|----|
| 12.1 LogRecord attributes | 1 | Pending | — |
| 12.2 BackendLogSink | 1 | Pending | — |
| 12.3 App integration | 1 | Pending | — |
| 12.4 Backend ingest | 1 | Pending | — |
| 12.5 Breadcrumbs | 2 | Pending | — |
| 12.6 Remote log level | 2 | Pending | — |
| 12.7 Error fingerprinting | 2 | Pending | — |
| 12.8 RUM / performance | 3 | Pending | — |
| 12.9 Screenshot on error | 3 | Pending | — |
