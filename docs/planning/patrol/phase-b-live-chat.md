# Phase B: Live Chat Tests (No-Auth)

**Status:** pending
**Depends on:** Phase A

## Objective

Two tests against a `--no-auth-mode` backend: room listing and chat message
round-trip with streaming response. After this phase, we have a real E2E test
that proves the full Patrol → Flutter → Backend → SSE pipeline works.

## Pre-flight Checklist

- [ ] Confirm Phase A complete (smoke test passing)
- [ ] Backend running in `--no-auth-mode` with at least one room configured
- [ ] Identify exact widget types for: room list items, chat input, send button,
  chat messages (read the source to confirm finders)

## Deliverables

1. `integration_test/live_chat_test.dart` — Two Patrol tests

## Implementation Steps

### Step 1: Implement rooms-load test

**File:** `integration_test/live_chat_test.dart`

- [ ] Import `patrol_test_config.dart` and app widgets
- [ ] `patrolTest('rooms load from backend', ...)`
- [ ] Call `verifyBackendOrFail(backendUrl)`
- [ ] Call `ignoreKeyboardAssertions()`
- [ ] Pump test app with no-auth provider overrides (same pattern as smoke test)
- [ ] Use `waitForCondition` to wait for room list to render
- [ ] Assert at least one `RoomListTile` (or equivalent) is present
- [ ] Assert room name text is visible

### Step 2: Implement chat send/receive test

**File:** `integration_test/live_chat_test.dart`

- [ ] `patrolTest('chat send and receive', ...)`
- [ ] Call `verifyBackendOrFail(backendUrl)` and `ignoreKeyboardAssertions()`
- [ ] Pump test app with no-auth provider overrides
- [ ] Wait for room list, tap first room
- [ ] Wait for chat view to render
- [ ] Tap "New Chat" button to create a fresh thread
- [ ] Enter test message: `'patrol-test-${DateTime.now().millisecondsSinceEpoch}'`
- [ ] Submit message (tap send button)
- [ ] Use `waitForCondition` to detect streaming response:
  - Condition: assistant `ChatMessageWidget` appears
  - Timeout: 30 seconds (SSE streaming can be slow)
- [ ] Assert response contains non-empty text
- [ ] Do NOT use `pumpAndSettle` anywhere

### Step 3: Test isolation

- Each test creates a fresh thread via "New Chat"
- Test messages include timestamp for uniqueness
- No explicit teardown needed

### Step 4: Run and verify

```bash
patrol test --target integration_test/live_chat_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000
```

- [ ] Both tests pass against no-auth backend

## Out of Scope

- Authentication (deferred to Phase C)
- Tool calling tests (deferred)
- Thread deletion/cleanup
- Multiple room navigation
- Message history scrolling
- Error state testing

## Review Gate

**Tool:** `mcp__gemini__read_files` with `gemini-3-pro-preview`

**Files:** `integration_test/live_chat_test.dart`,
`integration_test/patrol_test_config.dart`,
`docs/planning/patrol/phase-b-live-chat.md`

**Prompt:**

```text
Review the live chat Patrol tests against the Phase B spec.

Check:
1. No pumpAndSettle used anywhere (streaming-safe)
2. waitForCondition used with appropriate timeouts
3. Test messages include unique tokens for isolation
4. Fresh thread created per test
5. Tests are deterministic — no race conditions
6. No auth complexity (no-auth mode only)

Report PASS or list specific issues.
```

## Success Criteria

- [ ] Room list test loads rooms from no-auth backend
- [ ] Chat test sends message and receives streaming response
- [ ] No `pumpAndSettle` used anywhere
- [ ] Tests are isolated (unique tokens, fresh threads)
- [ ] Zero analyzer issues
