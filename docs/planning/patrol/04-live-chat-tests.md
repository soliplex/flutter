# Milestone 04: Live Chat Tests (Authenticated)

**Status:** pending
**Depends on:** 03-oidc-auth-flow

## Objective

Implement the two core user-flow tests: room listing and chat message
round-trip. Both run against a Keycloak-protected backend after OIDC login
using the `performKeycloakLogin` helper from M03.

## Pre-flight Checklist

- [ ] Confirm M03 complete (OIDC auth flow passing)
- [ ] Verify backend has at least one room configured
- [ ] Identify exact widget type/key for room list items (e.g., `RoomListTile`)
- [ ] Identify exact widget type/key for "New Chat" button (e.g., `IconButton`
  with `Icons.add` in AppBar, or text button — document the specific finder)
- [ ] Identify exact widget type for chat response (e.g., `ChatMessageWidget`)
- [ ] Identify exact widget type/key for chat input field and send button

## Deliverables

1. **`integration_test/live_chat_test.dart`** — Two Patrol tests

## Files to Create

- [ ] `integration_test/live_chat_test.dart`

## Implementation Steps

### Step 1: Implement live.rooms.load

**File:** `integration_test/live_chat_test.dart`

- [ ] Import `patrol_test_base.dart`
- [ ] Use `patrolTestWithScreenshot('live.rooms.load', ...)`
- [ ] Call `verifyBackendOrFail(backendUrl)`
- [ ] Call `ignoreKeyboardAssertions()`
- [ ] Pump test app in OIDC mode via `buildTestApp()`
- [ ] Call `performKeycloakLogin($)` to authenticate
- [ ] Rooms load automatically after login — already verified by M03
- [ ] Assert at least one `RoomListTile` widget is present
- [ ] Verify room name text is visible (non-empty)

### Step 2: Implement live.chat.send_receive

**File:** `integration_test/live_chat_test.dart`

- [ ] Use `patrolTestWithScreenshot('live.chat.send_receive', ...)`
- [ ] Call `verifyBackendOrFail(backendUrl)` and `ignoreKeyboardAssertions()`
- [ ] Pump test app, call `performKeycloakLogin($)`
- [ ] Wait for room list, tap first room
- [ ] Wait for chat view to render
- [ ] Tap "New Chat" button (use exact finder identified in pre-flight, e.g.,
  `find.byIcon(Icons.add)` or `find.byKey(Key('new-chat'))`) to create a
  fresh thread
- [ ] Enter test message with unique token:
  `'patrol-test-${DateTime.now().millisecondsSinceEpoch}'`
- [ ] Submit message (tap send button or simulate enter)
- [ ] Use `waitForCondition` to detect streaming response:
  - Condition: `ChatMessageWidget` count increases (assistant response appears)
  - Timeout: 30 seconds (SSE streaming can be slow)
- [ ] Assert response widget contains non-empty text
- [ ] Do NOT use `pumpAndSettle` at any point

### Step 3: Test isolation

- [ ] Each test creates a fresh thread via "New Chat" (no shared state)
- [ ] Test messages include timestamp for uniqueness
- [ ] No explicit teardown needed (threads are cheap)

### Step 4: Run and verify

```bash
patrol test --target integration_test/live_chat_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=oidc \
  --dart-define SOLIPLEX_OIDC_USERNAME=testuser \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass
```

- [ ] Both tests pass against Keycloak-protected backend
- [ ] Screenshots generated on forced failure

## Out of Scope

- Thread deletion/cleanup (backend handles retention)
- Multiple room navigation
- Message history scrolling
- Attachment or media messages
- Error state testing (network failures, timeouts)
- No-auth variant of these tests (covered by smoke test in M02)

## Validation Gate

### Automated Checks

- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] `patrol test --target integration_test/live_chat_test.dart` passes
- [ ] Existing `flutter test` suite unaffected

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `integration_test/live_chat_test.dart`,
`integration_test/patrol_test_base.dart`,
`docs/planning/patrol/04-live-chat-tests.md`,
`docs/patrol-analysis.md`

**Prompt:**

```text
Review the live chat Patrol tests against the spec in
04-live-chat-tests.md and source analysis in patrol-analysis.md.

Check:
1. No pumpAndSettle used anywhere (streaming-safe)
2. waitForCondition used with appropriate timeouts
3. Test messages include unique tokens for isolation
4. performKeycloakLogin called before each test
5. patrolTestWithScreenshot wrapper used consistently
6. Fresh thread created per test (not reusing existing threads)
7. Tests are deterministic — no race conditions
8. ignoreKeyboardAssertions called in setup

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] Room list test loads rooms from authenticated backend
- [ ] Chat test sends message and receives streaming response
- [ ] No `pumpAndSettle` used anywhere
- [ ] Tests are isolated (unique tokens, fresh threads)
- [ ] OIDC login via `performKeycloakLogin` before each test
- [ ] Screenshots captured on failure
- [ ] Gemini critique: PASS
