# Phase B: Live Chat Tests (No-Auth)

**Status:** pending
**Depends on:** Phase A
**Logging level:** 2-3 (event-driven waits + structured assertions)

## Objective

Two tests against a `--no-auth-mode` backend: room listing and chat message
round-trip with streaming response. Tests use `harness.waitForLog()` for
event-driven waits and `harness.expectLog()` to verify internal pipeline
behavior — not just UI widgets.

## Pre-flight Checklist

- [ ] Confirm Phase A complete (smoke test passing with TestLogHarness)
- [ ] Backend running in `--no-auth-mode` with at least one room configured
- [ ] Identify exact widget types by reading source:
  - Room list items (`RoomListTile` or equivalent)
  - Chat input field (check Semantics label, likely "Chat message input")
  - Send button (check tooltip, likely "Send message")
  - Chat messages (`ChatMessageWidget` or equivalent)
  - New conversation button (text is "New Conversation", NOT "New Chat")
- [ ] Identify key log messages emitted by existing `Loggers.*` calls:
  - `Loggers.http` — what does it log on request/response?
  - `Loggers.activeRun` — what does it log on SSE connect, message, finish?
  - `Loggers.room` — what does it log on room list load?

## Deliverables

1. `integration_test/live_chat_test.dart` — Two Patrol tests

## Implementation Steps

### Step 1: Implement rooms-load test

**File:** `integration_test/live_chat_test.dart`

- [ ] Import `patrol_test_config.dart`, `test_log_harness.dart`, app widgets
- [ ] `patrolTest('rooms load from backend', ...)`
- [ ] Initialize `TestLogHarness` and get provider overrides
- [ ] Call `verifyBackendOrFail(backendUrl)`
- [ ] Call `ignoreKeyboardAssertions()`
- [ ] Pump test app with provider overrides (logging + no-auth + shellConfig)
- [ ] Navigate through connect flow (tap Connect on HomeScreen) OR
  override auth to skip directly to rooms — decide during implementation
- [ ] Use `waitForCondition` to wait for room list to render
- [ ] Assert at least one room list item widget is present
- [ ] **White-box assertion:** `harness.expectLog('HTTP', 'GET /api/v1/rooms')`
  to verify the HTTP call actually fired (not cached/stale data)
- [ ] On failure: `harness.dumpLogs()` automatically shows what happened

### Step 2: Implement chat send/receive test

**File:** `integration_test/live_chat_test.dart`

- [ ] `patrolTest('chat send and receive', ...)`
- [ ] Initialize `TestLogHarness`, provider overrides, preflight, keyboard fix
- [ ] Pump test app, navigate to rooms
- [ ] Wait for room list, tap first room
- [ ] Wait for chat view to render
- [ ] Tap **"New Conversation"** button to create a fresh thread
- [ ] Enter test message: `'patrol-test-${DateTime.now().millisecondsSinceEpoch}'`
- [ ] Submit message (tap send button)
- [ ] **Log-driven wait** (replaces `waitForCondition` polling):

```dart
// Wait for the SSE run to complete — exact and deterministic
await harness.waitForLog('ActiveRun', 'RunFinished',
    timeout: Duration(seconds: 30));
await $.tester.pump();
```

- [ ] Assert response `ChatMessageWidget` contains non-empty text
- [ ] **White-box assertions** to verify the full pipeline:

```dart
harness.expectLog('HTTP', 'POST /agui');        // thread/run created
harness.expectLog('ActiveRun', 'SSE connected'); // stream opened
harness.expectLog('ActiveRun', 'RunFinished');   // run complete
```

- [ ] Do NOT use `pumpAndSettle` anywhere
- [ ] On failure: `harness.dumpLogs()` shows the full internal timeline

### Step 3: Test isolation

- Each test creates a fresh thread via "New Conversation"
- Test messages include timestamp for uniqueness
- Each test gets its own `TestLogHarness` instance (fresh MemorySink)
- No explicit teardown needed (threads are cheap)

### Step 4: Run and verify

```bash
patrol test --target integration_test/live_chat_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

- [ ] Both tests pass against no-auth backend
- [ ] Log-driven waits are faster than fixed polling

## Key Logging Assertions

| Test | Log Assertion | Why |
|------|--------------|-----|
| rooms load | `HTTP` contains `GET /rooms` | Proves HTTP call fired, not cached |
| chat send | `HTTP` contains `POST /agui` | Proves thread/run was created |
| chat send | `ActiveRun` contains `SSE connected` | Proves stream was established |
| chat send | `ActiveRun` contains `RunFinished` | Proves run completed (wait trigger) |

## Out of Scope

- Authentication (deferred to Phase C)
- Tool calling tests (deferred)
- Structured event attributes on production log calls (nice-to-have, not required)
- Thread deletion/cleanup
- Multiple room navigation
- Error state testing

## Review Gate

**Tool:** `mcp__gemini__read_files` with `gemini-3-pro-preview`

**Files:** `integration_test/live_chat_test.dart`,
`integration_test/test_log_harness.dart`,
`integration_test/patrol_test_config.dart`,
`lib/core/logging/loggers.dart`,
`docs/planning/patrol/phase-b-live-chat.md`

**Prompt:**

```text
Review the live chat Patrol tests against the Phase B spec.

Check:
1. No pumpAndSettle used anywhere (streaming-safe)
2. harness.waitForLog() used for SSE completion (not polling)
3. harness.expectLog() verifies internal HTTP and ActiveRun pipeline
4. harness.dumpLogs() called on failure for diagnostics
5. Test messages include unique tokens for isolation
6. Fresh TestLogHarness per test (clean MemorySink)
7. Button text is "New Conversation" (not "New Chat")
8. Tests are deterministic — log-driven waits eliminate races

Report PASS or list specific issues.
```

## Success Criteria

- [ ] Room list test loads rooms and verifies HTTP log
- [ ] Chat test sends message, waits for `RunFinished` log, verifies response
- [ ] Log-driven waits replace polling where possible
- [ ] White-box assertions verify internal pipeline (HTTP, SSE, ActiveRun)
- [ ] Failures auto-dump log history to console
- [ ] Tests are isolated (unique tokens, fresh threads, fresh harness)
- [ ] Zero analyzer issues
