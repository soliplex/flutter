# Central Logging Architecture - Milestone Overview (Accelerated)

## Strategy

This plan prioritizes **API availability**. We implement the Logging Interface
and Console output first, integrate it into the app, document it, then layer on
additional features. Documentation milestones are inserted after major features
so developers can use each capability immediately.

## Key Design Decisions

### Type-Safe Logger API

Instead of error-prone string-based logger names:

```dart
// OLD - avoid (typos possible)
getLogger('ActiveRunNotifier').info('message');

// NEW - type-safe
Loggers.activeRun.info('message');
```

All loggers are defined in a single `Loggers` class. Adding a new logger requires
adding a static field - enforced at compile time.

### Span-Ready for Telemetry

LogRecord includes optional `spanId` and `traceId` fields for future correlation
with distributed tracing. Span implementation is deferred but the data model
supports it from day one.

## Progress

- [ ] 01-essential-logging-api
- [ ] 02-api-documentation
- [ ] 03-migration-strategy
- [ ] 04-log-viewer-ui
- [ ] 05-ui-documentation
- [ ] 06-advanced-io-persistence
- [ ] 07-feedback-submission
- [ ] 08-final-documentation

## Review Process

Each milestone must pass two reviews before completion:

1. **Gemini Review** - Use `mcp__gemini__read_files` with model
   `gemini-3-pro-preview`, passing all related `.md` specs and `.dart` files
2. **Codex Review** - Use `mcp__codex__codex` to analyze the implementation
   against the spec

**File Limit:** Both Gemini and Codex have a limit of **15 files** per call.
If a milestone requires reviewing more than 15 files, batch the reviews:

- Batch 1: Core package files (`.dart` in `packages/*/lib/`)
- Batch 2: Test files (`.dart` in `packages/*/test/` and `test/`)
- Batch 3: App integration files (`lib/core/`, `lib/features/`)
- Final batch: Planning docs (`.md` files)

Each batch must pass before proceeding to the next.

## Milestones

### 01-essential-logging-api

- **Focus:** Interface & Integration
- **Objective:** Establish `soliplex_logging` package with type-safe `Loggers`
  class and Flutter Providers.
- **Outcome:** `Loggers.x.info()` is available in the codebase. Logs appear in
  debug console.
- **File:** [01-essential-logging-api.md](./01-essential-logging-api.md)

---

### 02-api-documentation

- **Focus:** Developer Enablement
- **Depends on:** 01-essential-logging-api
- **Objective:** Document the Logger API so developers can use it immediately.
- **Outcome:** README with usage examples, log level guidelines.
- **File:** [02-api-documentation.md](./02-api-documentation.md)

---

### 03-migration-strategy

- **Focus:** Adoption
- **Depends on:** 02-api-documentation
- **Objective:** Migrate all `debugPrint` and `_log` patterns to the new
  type-safe `Loggers.x` API.
- **Outcome:** Codebase is standardized. No more ad-hoc logging.
- **File:** [03-migration-strategy.md](./03-migration-strategy.md)

---

### 04-log-viewer-ui

- **Focus:** Visibility
- **Depends on:** 01-essential-logging-api
- **Objective:** Implement `MemorySink` in core package and the Log Viewer Screen
  in Settings.
- **Outcome:** Logs are visible on-device (Settings -> Logs).
- **File:** [04-log-viewer-ui.md](./04-log-viewer-ui.md)

---

### 05-ui-documentation

- **Focus:** User Guidance
- **Depends on:** 04-log-viewer-ui
- **Objective:** Document the Log Viewer UI and Settings integration.
- **Outcome:** User guide for viewing/filtering/exporting logs.
- **File:** [05-ui-documentation.md](./05-ui-documentation.md)

---

### 06-advanced-io-persistence

- **Focus:** Infrastructure
- **Depends on:** 01-essential-logging-api
- **Objective:** Create `soliplex_logging_io` package (FileSink, Rotation,
  Compression) and attach it to the existing Providers.
- **Outcome:** Logs are persisted to disk on native platforms.
- **File:** [06-advanced-io-persistence.md](./06-advanced-io-persistence.md)

---

### 07-feedback-submission

- **Focus:** Remote
- **Depends on:** 04-log-viewer-ui, 06-advanced-io-persistence
- **Objective:** Implement feedback form and log compression/upload service.
- **Outcome:** Users can send logs to backend.
- **File:** [07-feedback-submission.md](./07-feedback-submission.md)

---

### 08-final-documentation

- **Focus:** Polish
- **Depends on:** 07-feedback-submission
- **Objective:** Finalize all docs, add dartdoc comments, architecture overview.
- **File:** [08-final-documentation.md](./08-final-documentation.md)

---

## Dependency Graph

```text
01-essential-logging-api
├── 02-api-documentation
│   └── 03-migration-strategy
├── 04-log-viewer-ui
│   └── 05-ui-documentation
└── 06-advanced-io-persistence

04-log-viewer-ui + 06-advanced-io-persistence
└── 07-feedback-submission
    └── 08-final-documentation
```

## Future: Span/Tracing Support

The logging system is designed to support distributed tracing correlation:

```dart
// Future API (not implemented in these milestones)
final span = Tracer.startSpan('processMessage');
try {
  Loggers.chat.info('Processing message', spanContext: span.context);
  await doWork();
} finally {
  span.end();
}
```

LogRecord already includes `spanId` and `traceId` fields. A future milestone
can add:

- Span creation/management API
- Context propagation through async boundaries
- OpenTelemetry-compatible export

## Cross-Platform Verification (Final)

After all milestones complete, verify on each platform:

| Test | macOS | Windows | Linux | iOS | Android | Web |
|------|-------|---------|-------|-----|---------|-----|
| App launches | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Logs appear in console | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Log viewer shows entries | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Log files created | [ ] | [ ] | [ ] | [ ] | [ ] | N/A |
| Log rotation works | [ ] | [ ] | [ ] | [ ] | [ ] | N/A |
| Feedback submission | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Log level persists | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Local download | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

## Notes

- Started: 2026-01-20
- Reorganized: 2026-02-04 (accelerated for faster API availability)
- Revised: 2026-02-04 (type-safe API, span-ready design)
- Key constraint: Uses existing network transport (SoliplexApi, HttpTransport)
- No new HTTP clients or sockets
- Web platform uses memory buffer only (no file I/O)
- Native export writes directly to app documents directory (no file picker or
  share plugins)
