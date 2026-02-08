# Phase D: Log-Driven Test Hardening

**Status:** pending
**Depends on:** Phase C
**Logging level:** 5-7 (error sentinels, performance bounds, structured audit)

## Objective

Exploit the full `soliplex_logging` subsystem in Patrol tests. Phases A-C
used only 4 of 9 available loggers, never checked log levels, and ignored
timestamps. Phase D turns every silent failure into a test failure and
establishes performance baselines.

## Current Logging Coverage (Post Phase C)

| Logger | Used | How |
|--------|------|-----|
| `Auth` | No | - |
| `HTTP` | Partial | Route path assertions only |
| `ActiveRun` | Yes | Lifecycle events (RUN_STARTED, TEXT_START, RUN_FINISHED) |
| `Chat` | No | - |
| `Room` | Partial | "Rooms loaded:" assertion only |
| `Router` | Partial | "redirect called" assertion only |
| `Quiz` | No | - |
| `Config` | No | - |
| `UI` | No | - |

### Unused LogRecord Fields

- `level` — never checked (error vs warning vs info)
- `timestamp` — never used for timing
- `error` / `stackTrace` — never inspected
- Negative assertions — never assert something was NOT logged
- Count-based assertions — never check occurrence counts

## Deliverables

### 1. Error Sentinel — `expectNoErrors()`

Add to `TestLogHarness`:

```dart
void expectNoErrors({List<String> allowedPatterns = const []}) {
  final errors = sink.records.where((r) => r.level >= LogLevel.error);
  final unexpected = errors.where(
    (r) => !allowedPatterns.any((p) => r.message.contains(p)),
  );
  if (unexpected.isNotEmpty) {
    dumpLogs(last: 50);
    fail(
      '${unexpected.length} unexpected error(s):\n'
      '${unexpected.map((r) => '  [${r.loggerName}] ${r.message}').join('\n')}',
    );
  }
}
```

**Apply to:** Every test's `finally` block. Catches `LateInitializationError`,
unhandled exceptions, and any silent crash that swallows errors.

### 2. Auth Lifecycle Assertions (OIDC test)

Verify the `Auth` logger shows the expected state path:

- **No-auth tests:** `expectNoLog('Auth', ...)` — auth logger should be silent
  (proves `NoAuthNotifier` bypass is clean)
- **OIDC test:** `expectLog('Auth', 'Authenticated')` or verify auth state
  was set without triggering `_restoreSession`
- **Negative:** `expectNoLog('Auth', 'restore')` — proves
  `PreAuthenticatedNotifier` skipped the restore path

### 3. HTTP Audit Assertions

Assert no unexpected HTTP error responses during a test:

```dart
void expectNoHttpErrors({List<int> allowedStatuses = const [404]}) {
  final httpErrors = sink.records.where(
    (r) => r.loggerName == 'HTTP' && _isHttpError(r.message),
  );
  // ...
}
```

- No 401/403 in OIDC test (proves Bearer token valid throughout)
- No 5xx in any test (backend health)

### 4. Performance Bounds

Measure time between log events and fail if outside bounds:

```dart
Duration measureLogDelta(String startLogger, String startPattern,
    String endLogger, String endPattern) {
  final start = sink.records.firstWhere(
    (r) => r.loggerName == startLogger && r.message.contains(startPattern),
  );
  final end = sink.records.firstWhere(
    (r) => r.loggerName == endLogger && r.message.contains(endPattern),
  );
  return end.timestamp.difference(start.timestamp);
}
```

Use cases:

- `RUN_STARTED` to `RUN_FINISHED` < 30s (detect backend regressions)
- Room load time (HTTP request to "Rooms loaded") < 5s
- App boot to Router redirect < 3s

### 5. Negative Assertions — `expectNoLog()`

Add to `TestLogHarness`:

```dart
void expectNoLog(String loggerName, String messagePattern) {
  final found = sink.records.any(
    (r) => r.loggerName == loggerName && r.message.contains(messagePattern),
  );
  if (found) {
    dumpLogs(last: 30);
    fail('Unexpected log found: [$loggerName] containing "$messagePattern"');
  }
}
```

Use cases:

- `expectNoLog('Auth', 'LateInitializationError')` — in OIDC test
- `expectNoLog('Auth', 'Unhandled restore error')` — in all tests
- `expectNoLog('HTTP', '401')` — in OIDC test

### 6. Config Logger Assertions

Verify the app picked up the correct runtime configuration:

- `expectLog('Config', backendUrl)` — proves dart-define reached the app
- Useful for CI where misconfigured env vars silently use defaults

### 7. HTTP Inspector Navigation Test

Navigate to the Network Inspector screen and exercise the UI filters — a "meta"
test that validates the log viewer itself:

- Tap `Network Requests` tile in settings (text: `'Network Requests'`)
- Verify `'Requests (N)'` header shows a non-zero count
- Tap an `HttpEventTile` to open request detail
- Cycle through all 3 tabs: `'Request'`, `'Response'`, `'curl'`
- Verify the curl tab contains a copyable command
- Tap `'Clear all requests'` button and verify the list empties

Widget finders:

| Target | Finder |
|--------|--------|
| Network Requests tile | `find.text('Network Requests')` |
| Request count header | `find.textContaining('Requests (')` |
| Request tile | `find.byType(HttpEventTile)` |
| Tab: Request | `find.text('Request')` |
| Tab: Response | `find.text('Response')` |
| Tab: curl | `find.text('curl')` |
| Clear button | `find.byTooltip('Clear all requests')` |
| Empty state | `find.text('No HTTP requests yet')` |

## Implementation Order

| Step | Deliverable | Files | Effort |
|------|-------------|-------|--------|
| 1 | `expectNoErrors()` + apply to all tests | `test_log_harness.dart`, all `*_test.dart` | Small |
| 2 | `expectNoLog()` + negative assertions | `test_log_harness.dart`, `oidc_test.dart` | Small |
| 3 | Auth lifecycle assertions | `oidc_test.dart`, `smoke_test.dart` | Small |
| 4 | HTTP audit assertions | `test_log_harness.dart`, `oidc_test.dart` | Medium |
| 5 | `measureLogDelta()` + perf bounds | `test_log_harness.dart`, `live_chat_test.dart` | Medium |
| 6 | Config logger assertions | `smoke_test.dart` | Small |
| 7 | HTTP Inspector navigation test | `settings_test.dart` | Medium |

## Review Gate

| Gate | Tool | What |
|------|------|------|
| **Automated** | CLI | `flutter analyze` = 0, all 6 patrol tests green |
| **Sentinel** | Manual | Inject a deliberate `Loggers.auth.error(...)` call and verify `expectNoErrors()` catches it |
| **Perf** | Manual | Verify `measureLogDelta` produces reasonable values against live backend |

## Prerequisite: Structured HTTP Status Logging

The `HTTP` logger currently logs `debug('200 response')` — the status code is
embedded in a free-text message with no structured field. This makes it hard to
grep for 401/403 errors programmatically.

**Action:** Update `http_log_provider.dart` to include the status code as a
parseable prefix or add it to a structured log field:

```dart
// Before:
Loggers.http.debug('${event.statusCode} response');

// After:
Loggers.http.debug('HTTP ${event.statusCode} ${event.method} ${event.uri}');
```

This gives `expectNoLog('HTTP', 'HTTP 401')` a reliable pattern to match.

## Risks

- **False positives from `expectNoErrors()`** — some `error`-level logs may be
  expected (e.g., keychain unavailable in debug builds). Mitigated by
  `allowedPatterns` parameter.
- **Flaky perf bounds** — backend response times vary. Use generous thresholds
  (3x normal) and focus on detecting regressions, not absolute targets.
- **Log format coupling** — assertions depend on log message strings. If
  `Loggers.*` messages change, tests break. Acceptable tradeoff for white-box
  observability.
