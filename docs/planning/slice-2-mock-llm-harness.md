# Slice 2: Mock LLM Harness + Secret-Number Integration Tests

**Branch:** `feat/client-tool-calling-v3/slice-2` (stacked on `slice-1`)
**PR:** `feat/client-tool-calling-v3/slice-2` -> `feat/client-tool-calling-v3/slice-1`

---

## Goal

Create a lightweight mock AG-UI event stream for offline testing, then use it
to prove multi-tool-call scenarios work end-to-end. This harness becomes shared
infrastructure for all future tool-related work.

## Deliverable

The team can write deterministic tool-call tests without a live backend, API
keys, or network latency. A `MockAgUiClient` stub + `buildMockEventStream()`
factory give full control over AG-UI event sequences. The secret-number test
proves the complete tool-call flow (accumulate -> pending -> execute ->
continuation run -> final response) works with zero network calls.

---

## Implementation

### 1. Mock event stream factory

**File:** `test/helpers/mock_agui_stream.dart`

```dart
/// Build a mock AG-UI event stream from a list of events.
/// Wraps Stream.fromIterable with optional per-event delay for timing tests.
Stream<BaseEvent> buildMockEventStream(
  List<BaseEvent> events, {
  Duration? interEventDelay,
});
```

No scenario-builder classes, no framework. Tests compose event lists inline.

### 2. MockAgUiClient enhancement

**File:** `test/helpers/test_helpers.dart` (extend existing `MockAgUiClient`)

Add a callback-based stub so tests can return different streams per run:

```dart
class FakeAgUiClient implements AgUiClient {
  /// Callback invoked for each runAgent call.
  /// (threadId, input) -> event stream
  /// Tests set this to return different streams for Run 1 vs Run 2.
  Stream<BaseEvent> Function(String threadId, SimpleRunAgentInput input)?
      onRunAgent;

  int runAgentCallCount = 0;

  @override
  Stream<BaseEvent> runAgent(String threadId, SimpleRunAgentInput input) {
    runAgentCallCount++;
    if (onRunAgent != null) return onRunAgent!(threadId, input);
    return const Stream.empty();
  }
}
```

### 3. `ToolCallMessage.fromExecuted` -- domain synthesis helper

**File:** `packages/soliplex_client/lib/src/domain/chat_message.dart`

A pure domain factory that converts executed `ToolCallInfo` entries into a
`ToolCallMessage`. This keeps synthesis logic in the domain layer so Slice 3's
notifier can reuse it without duplicating test-only code.

```dart
/// Creates a ToolCallMessage from a list of executed tool calls.
///
/// Used after client-side tool execution to append results to the
/// conversation before starting a continuation run.
factory ToolCallMessage.fromExecuted({
  required String id,
  required List<ToolCallInfo> toolCalls,
}) {
  return ToolCallMessage(
    id: id,
    createdAt: DateTime.now(),
    toolCalls: toolCalls,
  );
}
```

### 4. Secret-number integration test

**File:** `test/core/providers/tool_call_integration_test.dart`

The "secret number" scenario exercises the full pipeline without orchestration
(Slice 3). At this stage, it tests event processing, `ToolCallMessage.fromExecuted`
synthesis, and mapper output -- proving the data layer is ready for orchestration.

---

## Files Changed

| File | Change |
|------|--------|
| `test/helpers/mock_agui_stream.dart` | New -- `buildMockEventStream()` factory |
| `test/helpers/test_helpers.dart` | Add `FakeAgUiClient` with `onRunAgent` callback |
| `packages/soliplex_client/lib/src/domain/chat_message.dart` | Add `ToolCallMessage.fromExecuted` factory |
| `packages/soliplex_client/test/domain/chat_message_test.dart` | Tests for `fromExecuted` |
| `test/core/providers/tool_call_integration_test.dart` | New -- all test scenarios below |

---

## Testing

All tests are **offline, deterministic, zero-network**. They run via
`flutter test` (app-level) since they use Riverpod providers.

### Autonomous test commands

```bash
# Run only Slice 2 tests (fast, targeted)
flutter test test/core/providers/tool_call_integration_test.dart

# Run fromExecuted domain tests
dart test packages/soliplex_client/test/domain/chat_message_test.dart

# Run full suite (verify no regressions)
flutter test
```

### Mock stream event sequences

Each test constructs an inline event list. Common patterns:

```dart
// Sequential tool calls in one run
final run1Events = [
  RunStartedEvent(threadId: 't1', runId: 'run-1'),
  ToolCallStartEvent(toolCallId: 'tc-1', toolCallName: 'get_secret_number'),
  ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{"name":"alice"}'),
  ToolCallEndEvent(toolCallId: 'tc-1'),
  ToolCallStartEvent(toolCallId: 'tc-2', toolCallName: 'get_secret_number'),
  ToolCallArgsEvent(toolCallId: 'tc-2', delta: '{"name":"bob"}'),
  ToolCallEndEvent(toolCallId: 'tc-2'),
  RunFinishedEvent(threadId: 't1', runId: 'run-1'),
];
```

### Test scenarios

#### Happy path: secret-number round trip

| Step | What happens | Assert |
|------|-------------|--------|
| 1 | User sends "What are the secret numbers?" | UserMessage in conversation |
| 2 | Mock Run 1 emits 2 tool calls (`get_secret_number` for alice, bob) | `conversation.toolCalls.length == 2`, both `status: pending` |
| 3 | Run 1 stream completes | `onDone` fires |
| 4 | Process pending tool calls through `ToolRegistry.execute()` | Returns `"42"` and `"7"` |
| 5 | Synthesize `ToolCallMessage` | Message has 2 `ToolCallInfo`, both `status: completed` |
| 6 | Convert via `convertToAgui()` | Produces `AssistantMessage` (with toolCalls) + 2 `ToolMessage`s |
| 7 | Mock Run 2 emits text response | "Alice's number is 42, Bob's is 7" |
| 8 | Run 2 completes | Final conversation has UserMessage, ToolCallMessage, TextMessage |

#### Tool failure isolation

| Step | What happens | Assert |
|------|-------------|--------|
| 1 | Run 1 emits 2 tool calls | Both pending |
| 2 | Tool A throws, Tool B succeeds | A: `status: failed`, B: `status: completed` |
| 3 | Both produce `ToolMessage` in `convertToAgui()` | Failed tool has error content |

#### ToolCallMessage synthesis correctness

| Step | What happens | Assert |
|------|-------------|--------|
| 1 | Process tool calls through registry | Results populated |
| 2 | Create `ToolCallMessage.create(toolCalls: executedCalls)` | `user == ChatUser.assistant` |
| 3 | `convertToAgui([toolCallMessage])` | Produces `AssistantMessage` + N `ToolMessage`s |
| 4 | Verify `ToolMessage.content` matches execution results | Exact match |
| 5 | Verify `ToolMessage.toolCallId` matches `ToolCall.id` | Exact match |

#### Mapper round-trip for edge cases

| # | Case | Input | Expected output |
|---|------|-------|----------------|
| 1 | Empty args | `ToolCallInfo(arguments: '')` | `FunctionCall(arguments: '{}')` |
| 2 | Failed tool | `ToolCallInfo(status: failed, result: 'Error: ...')` | `ToolMessage(content: 'Error: ...')` |
| 3 | Zero-result completed tool | `ToolCallInfo(status: completed, result: '')` | `ToolMessage(content: '')` |

#### FakeAgUiClient multi-run callback

| Step | What happens | Assert |
|------|-------------|--------|
| 1 | `onRunAgent` returns Run 1 stream on first call | `runAgentCallCount == 1` |
| 2 | `onRunAgent` returns Run 2 stream on second call | `runAgentCallCount == 2`, different events |
| 3 | Run 2 events processed correctly | Text message in final conversation |

---

## Acceptance Criteria

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues
- [ ] `flutter test` -- all pass
- [ ] `buildMockEventStream()` produces deterministic AG-UI event streams
- [ ] `FakeAgUiClient.onRunAgent` supports per-call stream responses
- [ ] Secret-number happy path passes with zero network calls
- [ ] Tool failure isolation proven (one fails, other succeeds, both produce ToolMessages)
- [ ] `ToolCallMessage.fromExecuted` factory creates correct message from executed tools
- [ ] `convertToAgui()` round-trip verified for all edge cases
- [ ] No scenario-builder classes -- event lists composed inline

---

## Review Gate

After implementation, before merging:

1. **Codex review** -- mock fidelity vs real AG-UI protocol, test coverage gaps
2. **Gemini review** (`gemini-3.1-pro-preview`) -- harness ergonomics, missing edge cases
3. Both reviews addressed before moving to Slice 3
