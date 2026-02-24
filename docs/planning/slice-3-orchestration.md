# Slice 3: Tool Execution Orchestration in ActiveRunNotifier

**Branch:** `feat/client-tool-calling-v3/slice-3` (stacked on `slice-2`)
**PR:** `feat/client-tool-calling-v3/slice-3` -> `feat/client-tool-calling-v3/slice-2`

---

## Goal

When a run's stream completes (`onDone`) and pending tool calls exist, execute
them via `ToolRegistry` and start a continuation run. Multi-hop (Run 2 triggers
more tools -> Run 3) works automatically.

## Deliverable

End-to-end client-side tool execution is live. A developer can write a Dart
function (GPS lookup, local DB query, device API call), register it via
`toolRegistryProvider.overrideWithValue(...)`, and the LLM will request it,
wait for the result, and respond with context. Multi-hop works automatically.
The UI shows "Calling: ..." during streaming, "Executing: ..." during
execution, and then the LLM's response.

---

## Implementation

Refer to the [Orchestration Design](client-tool-calling-v3-reference.md#orchestration-design-detailed)
in the master plan for the full state transition diagram, safety checks, and
concurrency analysis. Below is a summary of what gets implemented.

### 1. `ExecutingToolsState` -- new `ActiveRunState` subclass

**File:** `lib/core/models/active_run_state.dart`

```dart
@immutable
class ExecutingToolsState extends ActiveRunState {
  const ExecutingToolsState({
    required this.conversation,
    required this.pendingTools,
  });
  final Conversation conversation;
  final List<ToolCallInfo> pendingTools;

  @override
  bool get isRunning => true; // Keeps UI indicators active
}
```

### 2. `RunContinued` lifecycle event

**File:** `lib/core/models/run_lifecycle_event.dart`

```dart
class RunContinued extends RunLifecycleEvent {
  const RunContinued({required super.key});
}
```

**Consumer contract:** `_lifecycleSub` in ActiveRunNotifier filters on
`RunCompleted` for unread-run logic. `RunContinued` is intentionally NOT
handled -- continuations are not "new runs" and should not trigger unread
indicators.

### 3. `replaceRun` on `RunRegistry` -- atomic CAS

**File:** `lib/core/services/run_registry.dart`

```dart
Future<bool> replaceRun(RunHandle oldHandle, RunHandle newHandle) async {
  _checkNotDisposed();
  if (_runs[oldHandle.key] != oldHandle) return false;
  _runs[newHandle.key] = newHandle;            // new handle in place first
  _controller.add(RunContinued(key: newHandle.key));
  try {
    await oldHandle.dispose();                  // then dispose old
  } catch (e, st) {
    // Swap already committed — messy cleanup must not fail the operation
    _log.warning('Error disposing old handle', e, st);
  }
  return true;
}
```

### 4. Modify `_handleDoneForRun(handle)`

**File:** `lib/core/providers/active_run_notifier.dart`

Before transitioning to `CompletedState`, check
`handle.state.conversation.toolCalls` for any with `status: pending`.
If found: set `handle.state = ExecutingToolsState(...)`, sync UI, call
`_executeToolsAndContinue(handle)`.

### 5. `_executeToolsAndContinue(handle, {depth})` -- the core orchestration method

**File:** `lib/core/providers/active_run_notifier.dart`

Full implementation per the state transition diagram in the reference doc.
All 8 safety checks from the consolidated table (including circuit breaker).
Every code path exits to a terminal state or hands off to new handle.

Key details:

- **Circuit breaker:** `depth >= _maxContinuationDepth` (default 10) aborts
  with `FailedResult('Max tool continuation depth exceeded')`
- **`ToolCallMessage.fromExecuted`:** Uses the domain helper from Slice 2
  to synthesize the tool result message before starting the continuation run
- **`_abortToCompleted`:** Clears `conversation.toolCalls` so UI never
  renders stranded "pending" tools on a failed run

### 6. `_establishSubscription(handle, eventStream)` -- extracted helper

**File:** `lib/core/providers/active_run_notifier.dart`

Shared by `startRun` and `_executeToolsAndContinue`. Creates
`StreamSubscription` with `_processEventForRun`, `onError`, `onDone` handlers.

### 7. `StatusIndicator` update

**File:** `lib/features/chat/widgets/status_indicator.dart`

Add pattern match for `ExecutingToolsState` to show "Executing: tool1, tool2".

### 8. Auto-scroll on `RunContinued` -- resolved by `fix/scroll`

The `fix/scroll` branch replaced auto-scroll-to-bottom with a
scroll-to-target-on-send system (`ScrollToMessageSession` +
`ScrollButtonController`). This **automatically handles `RunContinued`**:

- `_lastScrolledId` prevents re-scrolling to the same user message on
  continuation runs (same message ID, `shouldScrollTo()` returns false)
- `targetScrollOffset` persists across run boundaries so the dynamic spacer
  keeps shrinking as continuation text streams in
- No auto-scroll-to-bottom means continuations render smoothly without jarring
  viewport jumps

**No explicit `RunContinued` scroll handling needed.** Verify with a widget
test that continuation text appears below the pinned user message without
triggering a re-scroll.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/core/models/active_run_state.dart` | Add `ExecutingToolsState` |
| `lib/core/models/run_lifecycle_event.dart` | Add `RunContinued` |
| `lib/core/services/run_registry.dart` | Add `replaceRun` |
| `lib/core/providers/active_run_notifier.dart` | `_handleDoneForRun` check, `_executeToolsAndContinue`, `_establishSubscription`, `_abortToCompleted` |
| `lib/features/chat/widgets/status_indicator.dart` | `ExecutingToolsState` display |
| Tests (see Testing below) | |

---

## Testing

This slice has the most extensive test suite. Tests use the **mock LLM harness
from Slice 2** (`FakeAgUiClient`, `buildMockEventStream`) to run full
orchestration flows without any network.

### Autonomous test commands

```bash
# Run orchestration tests only (fast, targeted)
flutter test test/core/providers/active_run_notifier_tool_call_test.dart

# Run all related model/service tests
flutter test test/core/models/active_run_state_test.dart
flutter test test/core/services/run_registry_test.dart

# Run full suite (verify no regressions)
flutter test
```

### Test file: `test/core/providers/active_run_notifier_tool_call_test.dart`

Uses `ProviderContainer` with mocked auth + `FakeAgUiClient` from Slice 2.

#### Happy path tests

| # | Test | Setup | Assert |
|---|------|-------|--------|
| 1 | **Single tool call -> continuation -> response** | Run 1: 1 tool call. Run 2: text response. | Final state: `CompletedState`. Conversation has UserMessage, ToolCallMessage (completed), TextMessage. |
| 2 | **Two tool calls -> continuation -> response** | Run 1: 2 sequential tool calls. Run 2: text with both results. | `ToolCallMessage.toolCalls.length == 2`, both `completed`. |
| 3 | **Multi-hop: Run 2 triggers more tools** | Run 1: tool A. Run 2: tool B. Run 3: text. | `FakeAgUiClient.runAgentCallCount == 3`. Three runs complete. |
| 4 | **Text + tool calls in same run** | Run 1: text message then tool calls. | TextMessage AND ToolCallMessage in conversation after Run 1. |

#### Failure path tests

| # | Test | Setup | Assert |
|---|------|-------|--------|
| 5 | **Tool throws -> failed status -> Run 2 starts** | Tool executor throws. | `ToolCallInfo.status == failed`. Run 2 still starts (model sees error via ToolMessage). |
| 6 | **All tools fail -> Run 2 starts** | All executors throw. | All `failed`. Run 2 starts. Model responds to error content. |
| 7 | **api.createRun fails** | Mock API throws on continuation. | `CompletedState` with `FailedResult`. NOT stuck in `ExecutingToolsState`. `conversation.toolCalls` is empty. |
| 8 | **Stream error with pending tools** | `onError` fires mid-stream with accumulated tool calls. | `CompletedState(Failed)`. Pending tools abandoned (correct -- backend run is broken). |
| 8b | **Abort clears pending toolCalls** | Any abort path triggers `_abortToCompleted`. | `CompletedState.conversation.toolCalls` is empty -- no stranded "pending" tools in UI. |

#### Cancellation tests

| # | Test | Setup | Assert |
|---|------|-------|--------|
| 9 | **Cancel during tool execution** | Cancel token triggered while `Future.wait` in progress. | `CompletedState` with `CancelledResult`. |
| 10 | **Cancel after tool execution, before continuation** | Cancel between execution and `api.createRun`. | `CompletedState(CancelledResult)`. |

#### Concurrency tests

| # | Test | Setup | Assert |
|---|------|-------|--------|
| 11 | **Stale handle: user re-sends during execution** | `startRun` called on same ThreadKey while executing tools. | Old execution aborts (`replaceRun` returns false). New run proceeds. |
| 12 | **Concurrent threads execute tools simultaneously** | Two handles with different ThreadKeys, both in `ExecutingToolsState`. | Both complete independently. No cross-thread interference. |
| 13 | **Navigation during execution** | `_currentHandle` points to Thread A; Thread B finishes execution. | `_currentHandle` NOT overwritten. Thread B runs in background. |

#### Circuit breaker tests

| # | Test | Setup | Assert |
|---|------|-------|--------|
| 14 | **Max depth exceeded aborts** | Mock LLM always returns tool calls (11 hops). | After 10 continuations: `CompletedState(FailedResult('Max tool continuation depth exceeded'))`. |
| 15 | **Depth increments per hop** | Run 1 -> tools -> Run 2 -> tools -> Run 3 -> text. | `runAgentCallCount == 3`. Depth tracked correctly. |

#### State transition tests

| # | Test | Setup | Assert |
|---|------|-------|--------|
| 16 | **ExecutingToolsState.isRunning is true** | Construct state. | `isRunning == true`. |
| 17 | **replaceRun fails if handle is stale** | Replace with wrong oldHandle. | Returns `false`. Map unchanged. |
| 18 | **replaceRun emits RunContinued** | Successful replace. | `RunContinued` event on lifecycle stream. |
| 19 | **replaceRun disposes old AFTER registering new** | Successful replace. | New handle in map before old dispose callback. |
| 20 | **replaceRun swallows disposal errors** | `oldHandle.dispose()` throws. | Returns `true`. New handle in map. Error logged, not thrown. |

### Test file: `test/core/models/active_run_state_test.dart`

| # | Test | Assert |
|---|------|--------|
| 1 | `ExecutingToolsState` equality | Same conversation + pendingTools -> equal |
| 2 | `ExecutingToolsState.isRunning` | `true` |
| 3 | Pattern match exhaustiveness | Switch on `ActiveRunState` covers all subclasses including `ExecutingToolsState` |

### Test file: `test/core/services/run_registry_test.dart`

| # | Test | Assert |
|---|------|--------|
| 1 | `replaceRun` happy path | Returns `true`, new handle in map, old disposed |
| 2 | `replaceRun` stale handle | Returns `false`, map unchanged |
| 3 | `replaceRun` emits `RunContinued` | Lifecycle stream has event |
| 4 | `replaceRun` on disposed registry | Throws |

### Test file: `test/features/chat/widgets/status_indicator_test.dart`

| # | Test | Assert |
|---|------|--------|
| 1 | Shows "Executing: tool1, tool2" for `ExecutingToolsState` | Correct text displayed |
| 2 | Shows "Calling: tool1" during `StreamingState` with `ToolCallActivity` | Existing behavior preserved |

---

## Safety invariant verification

Every code path in `_executeToolsAndContinue` must reach a terminal state.
These tests verify no path leaves `ExecutingToolsState` as the final state:

| Exit path | Test # | Terminal state |
|-----------|--------|---------------|
| Max continuation depth exceeded | 14 | `CompletedState(FailedResult('Max tool continuation depth exceeded'))` |
| Notifier disposed (`!ref.mounted`) | -- | No state update (already gone) |
| Cancel token triggered | 9, 10 | `CompletedState(CancelledResult)` |
| Handle stale (new run replaced it) | 11 | Return silently (new run owns state) |
| `replaceRun` CAS fails | 11 | Dispose new handle, return |
| `api.createRun` throws | 7 | `CompletedState(FailedResult)`. `toolCalls` cleared. |
| Tool execution throws (all) | 6 | Run 2 still starts with failed results |
| Unhandled exception | 7 | `_abortToCompleted(FailedResult)`. `toolCalls` cleared. |

---

## Acceptance Criteria

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues
- [ ] `flutter test` -- all pass
- [ ] `onDone` with pending tools triggers execution, not completion
- [ ] Tools execute in parallel with per-tool error isolation
- [ ] `ToolCallMessage` synthesized and appended before continuation
- [ ] Continuation run starts with tool results in AG-UI messages
- [ ] UI shows "Calling: ..." during streaming, "Executing: ..." during execution
- [ ] All 8 safety checks implemented (including circuit breaker); every path reaches terminal state
- [ ] `_abortToCompleted` clears `conversation.toolCalls` -- no stranded pending tools
- [ ] Circuit breaker aborts after `maxContinuationDepth` hops
- [ ] `replaceRun` swallows disposal errors (logged, not thrown)
- [ ] `replaceRun` prevents TOCTOU race (new registered before old disposed)
- [ ] `_currentHandle` guard prevents background thread UI overwrite
- [ ] `RunContinued` event emitted; unread-run logic ignores it
- [ ] Multi-hop works (Run 2 -> tools -> Run 3)
- [ ] All existing notifier tests still pass

---

## Review Gate

After implementation, before merging:

1. **Codex review** -- safety invariant (every path reaches terminal state),
   concurrency correctness, `replaceRun` CAS semantics
2. **Gemini review** (`gemini-3.1-pro-preview`) -- orchestration completeness, edge cases,
   test coverage vs safety table alignment
3. Both reviews addressed before moving to Slice 4
