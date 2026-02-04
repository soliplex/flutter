# Milestone 05: UI Documentation

**Status:** pending
**Depends on:** 04-log-viewer-ui

## Objective

Document the Log Viewer UI and Settings integration so users and developers
understand how to view, filter, and export logs.

## Pre-flight Checklist

- [ ] M04 complete (log viewer UI working)
- [ ] Log viewer is accessible and functional
- [ ] MemorySink with StreamController working

## Files to Create

- [ ] `docs/logging-viewer.md`

## Files to Modify

- [ ] `docs/logging-quickstart.md` - Add link to viewer docs
- [ ] `packages/soliplex_logging/README.md` - Add MemorySink documentation

## Implementation Steps

### Step 1: Create viewer documentation

**File:** `docs/logging-viewer.md`

- [ ] Overview of log viewer feature
- [ ] How to access: Settings > View Logs
- [ ] Filter controls:
  - Level filter (chips for each LogLevel)
  - Module/source filter (based on logger names like Auth, HTTP, Chat)
  - Search text (filters by message content)
- [ ] Export functionality:
  - Native: File saved to documents, path shown in snackbar
  - Web: Browser download triggered
- [ ] Screenshots or diagrams (optional, text description acceptable)
- [ ] Troubleshooting:
  - "No logs showing" - check log level setting in Settings
  - "Export failed" - check storage permissions (native only)
  - "Missing logs from startup" - ensure memorySinkProvider initialized early

### Step 2: Update quickstart guide

**File:** `docs/logging-quickstart.md`

- [ ] Add section: "Viewing Logs in the App"
- [ ] Link to `docs/logging-viewer.md`
- [ ] Brief mention of Settings > View Logs
- [ ] Explain that `Loggers.x` calls automatically appear in the viewer

### Step 3: Document MemorySink

**File:** `packages/soliplex_logging/README.md`

- [ ] Add MemorySink section:
  - Purpose: In-memory log buffer for UI display
  - Configuration: `maxRecords` parameter (default 2000)
  - Stream: `onRecord` stream for live UI updates
  - Usage: Accessing `records`, calling `clear()`
- [ ] Add LogFormatter section:
  - Purpose: Format LogRecord to string
  - Default format: `[LEVEL] loggerName: message`
  - Custom formatter example

```dart
// MemorySink usage
final sink = MemorySink(maxRecords: 1000);
LogManager.instance.addSink(sink);

// Access records
final logs = sink.records;

// Listen for live updates (pure Dart - uses StreamController)
sink.onRecord.listen((record) {
  print('New log: ${record.message}');
});

// Clear buffer
sink.clear();
```

### Step 4: Add dartdoc to new classes

**Files:** `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`,
`packages/soliplex_logging/lib/src/log_formatter.dart`

- [ ] MemorySink: Document buffer behavior, maxRecords, clear(), onRecord stream
- [ ] LogFormatter: Document format interface and default implementation

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `npx markdownlint-cli docs/logging-viewer.md`
- [ ] `npx markdownlint-cli docs/logging-quickstart.md`
- [ ] `npx markdownlint-cli packages/soliplex_logging/README.md`
- [ ] `dart doc packages/soliplex_logging` runs without errors

### Manual Verification

- [ ] Documentation is clear for non-technical users
- [ ] All links work
- [ ] Examples are accurate and match actual API
- [ ] StreamController usage is correctly documented (not ChangeNotifier)

### Review Gates

- [ ] **Gemini Review:** Run `mcp__gemini__read_files` with model
  `gemini-3-pro-preview` passing:
  - `docs/planning/logging/05-ui-documentation.md`
  - `docs/logging-viewer.md`
  - `docs/logging-quickstart.md`
  - `packages/soliplex_logging/README.md`
  - `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`
  - `packages/soliplex_logging/lib/src/log_formatter.dart`
- [ ] **Codex Review:** Run `mcp__codex__codex` to verify documentation
  completeness

## Success Criteria

- [ ] `docs/logging-viewer.md` exists and is complete
- [ ] Quickstart guide updated with viewer info
- [ ] Package README documents MemorySink and LogFormatter
- [ ] MemorySink stream usage correctly documented
- [ ] All dartdoc comments present
- [ ] Markdown linting passes
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
