# Milestone 05: Live Tool Calling Tests (Authenticated)

**Status:** pending
**Depends on:** 03-oidc-auth-flow

## Objective

Implement a Patrol test that verifies client-side tool execution end-to-end:
send a message that triggers a tool call, and confirm the final assistant
response reflects the tool's output. Verification focuses on the observable
outcome, not internal event sequences.

## Pre-flight Checklist

- [ ] Confirm M03 complete (OIDC auth flow passing)
- [ ] Identify a registered client tool in `ToolRegistry` and its expected output
- [ ] Identify a prompt that reliably triggers the chosen tool
- [ ] Review `ChatMessageWidget` for how tool results surface in the UI

## Deliverables

1. **`integration_test/live_tool_calling_test.dart`** — Patrol test for tool flow

## Files to Create

- [ ] `integration_test/live_tool_calling_test.dart`

## Implementation Steps

### Step 1: Identify target tool and trigger prompt

Before writing the test, document:

- [ ] **Tool name:** (e.g., `get_device_info`, `get_current_time`)
- [ ] **Trigger prompt:** A specific message that reliably causes the LLM to
  invoke the tool (e.g., `"What time is it right now?"`)
- [ ] **Expected output pattern:** What the tool returns and how the assistant
  incorporates it (e.g., response contains a timestamp or device model)

### Step 2: Implement live.tools.client_execution

**File:** `integration_test/live_tool_calling_test.dart`

- [ ] Import `patrol_test_base.dart`
- [ ] Use `patrolTestWithScreenshot('live.tools.client_execution', ...)`
- [ ] Call `verifyBackendOrFail(backendUrl)` and `ignoreKeyboardAssertions()`
- [ ] Pump test app, call `performKeycloakLogin($)`
- [ ] Tap first room (same as M04 — all rooms support tool calling)
- [ ] Tap "New Chat" button (use exact finder from M04 pre-flight) to create
  a fresh thread
- [ ] Send the trigger prompt
- [ ] Use `waitForCondition` to detect the **final** assistant response:
  - Condition: assistant message appears containing expected output pattern
  - Timeout: 60 seconds (tool execution + LLM response adds latency)
- [ ] Assert the response text matches the expected output pattern
  (e.g., contains a time string, device info, etc.)

**Verification strategy:** Assert on the final observable outcome only. The
full cycle (message -> tool call -> tool result -> response) is verified
implicitly if the assistant's response contains tool-generated data. Internal
events (`ToolCallStartEvent`, executor invocation) are covered by unit tests.

### Step 3: Run and verify

```bash
patrol test --target integration_test/live_tool_calling_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=oidc \
  --dart-define SOLIPLEX_OIDC_USERNAME=testuser \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass
```

- [ ] Test passes against Keycloak-protected backend with tool-capable room
- [ ] Screenshot generated on forced failure

## Out of Scope

- Internal event sequence verification (unit-tested in `active_run_notifier_test`)
- Multiple concurrent tool calls
- Tool call error handling/retry
- Tool call cancellation
- Server-side tool execution (only client-side tools tested)
- Custom tool registration for tests (uses app's registered tools)

## Validation Gate

### Automated Checks

- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] `patrol test --target integration_test/live_tool_calling_test.dart` passes
- [ ] Existing `flutter test` suite unaffected

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `integration_test/live_tool_calling_test.dart`,
`integration_test/patrol_test_base.dart`,
`docs/planning/patrol/05-live-tool-calling-tests.md`,
`docs/patrol-analysis.md`

**Prompt:**

```text
Review the live tool calling Patrol test against the spec in
05-live-tool-calling-tests.md and source analysis in patrol-analysis.md.

Check:
1. No pumpAndSettle used (streaming-safe)
2. Timeout is generous enough for tool execution (>=60s)
3. Test verifies the final outcome, not internal events
4. Trigger prompt is documented and likely to be deterministic
5. Expected output pattern is specific enough to validate
6. Test is isolated (fresh thread, unique prompt)
7. performKeycloakLogin called for authenticated session

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] Tool call test sends trigger prompt and receives tool-augmented response
- [ ] Verification is outcome-based (assistant response contains tool output)
- [ ] No `pumpAndSettle` used
- [ ] Generous timeout for tool execution latency (60s)
- [ ] OIDC login via `performKeycloakLogin`
- [ ] Screenshot captured on failure
- [ ] Gemini critique: PASS
