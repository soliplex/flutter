# Client-Side Tool Calling v3 — Reference

## Context

Client-side tool calling was partially implemented on `feat/client-tool-calling-v2`
(PRs #282, #290, #291, #294) but the branch went stale — 25 commits behind `main`
with major architectural drift. The `ActiveRunNotifier` was narrowed to presentation
and run lifecycle moved to `RunRegistry` + `RunHandle`.

### What landed on v3 (cherry-picked from v2)

- `ToolRegistry` — immutable, provider-shared registry (`register`, `lookup`, `execute`)
- `ToolCallStatus.streaming` — new enum value for argument accumulation phase
- `agui_message_mapper` fixes — normalize empty args to `'{}'`, emit `ToolMessage`
  for failed tool calls, add `id` to `ToolMessage`

### What's still needed

1. Wire `ToolRegistry` into providers (provider + registration)
2. Event processor changes for `ToolCallArgs` accumulation and `ToolCallEnd` → `pending`
3. Orchestration: detect ready tool calls, execute, create continuation run
4. Integration tests with **mock LLM** (no external backend dependency)
5. Clean up stale PRs (#290, #291, #294)

### Architecture on main

```text
ActiveRunNotifier (presentation, UI state sync)
  └── RunRegistry (tracks concurrent runs across rooms/threads)
       └── RunHandle (key, runId, cancelToken, subscription, state)
            └── ActiveRunState (IdleState | RunningState | CompletedState)

Event flow:
  SSE stream → ActiveRunNotifier._processEventForRun(handle, event)
    → processEvent(conversation, streaming, event)  [pure function]
    → _mapResultForRun(handle, prev, result)
    → handle.state = newState | registry.completeRun(handle, completed)
    → _syncUiState(handle, newState)
```

Key files:

- `lib/core/providers/active_run_notifier.dart` — startRun, event dispatch, UI sync
- `lib/core/services/run_registry.dart` — multi-run tracking
- `lib/core/models/run_handle.dart` — per-run resource bundle
- `packages/soliplex_client/lib/src/application/agui_event_processor.dart` — pure event → state
- `packages/soliplex_client/lib/src/application/tool_registry.dart` — tool definitions + execution
- `packages/soliplex_client/lib/src/api/agui_message_mapper.dart` — ChatMessage → AG-UI Message
- `packages/soliplex_client/lib/src/domain/chat_message.dart` — ToolCallInfo, ToolCallMessage

### Stale PRs to close

| PR  | Branch | Reason |
|-----|--------|--------|
| #290 | refactor/notifier-test-container | Independent test cleanup — can merge standalone or redo |
| #291 | test/patrol-tool-calling | Depends on stale v2 orchestration; replace with mock-LLM tests |
| #294 | refactor/notifier-stream-setup | Refactors code that no longer exists on main |

---

## Orchestration Design (detailed)

This section spells out exactly how tool execution works end-to-end. It is the
core design that Slices 1–4 implement incrementally.

### Why NOT intercept ToolCallEndEvent

The v2 branch detected tool-call readiness after `ToolCallEndEvent` and
immediately paused the stream. This is **wrong** — the LLM may emit tool calls
sequentially within a single run:

```text
ToolCallStart(A) → ToolCallArgs(A) → ToolCallEnd(A)
  → ToolCallStart(B) → ToolCallArgs(B) → ToolCallEnd(B)
  → RunFinished
```

Pausing after `ToolCallEnd(A)` would miss Tool B entirely.

### Correct trigger: RunFinished / onDone

Tool execution is triggered in `_handleDoneForRun(handle)` (the `onDone`
callback of the stream subscription). When the stream completes:

1. Check `handle.state.conversation.toolCalls` for any with `status: pending`
2. If pending tools exist → execute them and start a continuation run
3. If no pending tools → transition to `CompletedState` as usual

This naturally supports **multi-hop tool calling**: Run 2's `onDone` re-checks
for pending tools and can trigger Run 3, Run 4, etc. No special recursion
needed — the same `onDone` logic fires for every run.

### State transitions

```text
Run 1 starts
  │
  ▼
SSE events arrive:
  ToolCallStart → ToolCallInfo added (status: streaming)
  ToolCallArgs  → arguments accumulated on ToolCallInfo
  ToolCallEnd   → status: streaming → pending (stays in list)
  RunFinished   → stream closes
  │
  ▼
_handleDoneForRun(handle):
  if conversation.toolCalls has pending tools:
    │
    ▼  ──── don't transition to CompletedState ────
    │
    handle.state = ExecutingToolsState(conversation, pendingTools)
    _syncUiState(handle) → UI shows "Executing tools..."
    │
    ▼
    _executeToolsAndContinue(handle):
      1. Execute all pending tools via Future.wait (per-tool error isolation)
      2. Check ref.mounted + cancelToken.isCancelled
      3. Check stale handle: registry.getHandle(handle.key) == handle
      4. Mark each ToolCallInfo → completed or failed
      5. Synthesize ToolCallMessage from completed toolCalls
      6. Append ToolCallMessage to conversation.messages
      7. Clear conversation.toolCalls list
      8. Create new run via api.createRun(roomId, threadId)
      9. Check ref.mounted + cancelToken.isCancelled (TOCTOU gap)
     10. Check stale handle again (user may have re-sent during API call)
     11. Convert messages via convertToAgui() (includes tool results)
     12. Call _agUiClient.runAgent() for Run 2
     13. Create new RunHandle with fresh runId + subscription
     14. Atomic replace: registry.replaceRun(oldHandle, newHandle)
         - Returns false if oldHandle was replaced → abort
     15. Guard _currentHandle: only update if identical to oldHandle
      │
      ▼
    Run 2 streams → same _processEventForRun(newHandle, event) logic
      │
      ▼
    Run 2's onDone fires → same check → tools? execute(depth+1) : complete
      │
      ▼
    Circuit breaker: if depth >= maxContinuationDepth → abort
```

### Where things live

| Concern | Location | Rationale |
|---------|----------|-----------|
| Tool-call readiness detection | `_handleDoneForRun` in ActiveRunNotifier | Already the terminal handler; adding a conditional branch is minimal |
| Tool execution + continuation | `_executeToolsAndContinue(handle)` in ActiveRunNotifier | Needs `_agUiClient`, `ref`, `_registry`, `_toolRegistry` — too many deps to extract |
| Execution phase state | `ExecutingToolsState` subclass of `ActiveRunState` | Stream is dead at this point — using StreamingState would imply active streaming |
| Stream subscription setup | `_establishSubscription(handle, eventStream)` private helper in ActiveRunNotifier | Shared by `startRun` and `_executeToolsAndContinue`; avoids duplication |
| Continuation run registration | `registry.replaceRun(oldHandle, newHandle)` — atomic CAS | Prevents TOCTOU race where user re-sends during API call |
| Continuation lifecycle event | `RunContinued` event (not `RunStarted`) | Prevents UI flash and unread-run logic from firing on continuations |

### ExecutingToolsState — a new ActiveRunState subclass

**Why not StreamingState?** When `onDone` fires, the SSE stream is permanently
closed. `StreamingState` (`AwaitingText`, `TextStreaming`) represents ephemeral
parsing state for an active AG-UI stream. Placing tool execution state there
would violate the semantic contract — there is no stream to parse.

Add to `active_run_state.dart`:

```dart
/// Tools are being executed between Run N and Run N+1.
///
/// The AG-UI stream has completed but the interaction is not done —
/// tool results must be sent back and a continuation run started.
@immutable
class ExecutingToolsState extends ActiveRunState {
  const ExecutingToolsState({
    required this.conversation,
    required this.pendingTools,
  });

  /// The conversation so far (includes messages up to Run N).
  final Conversation conversation;

  /// Tool calls being executed.
  final List<ToolCallInfo> pendingTools;

  @override
  bool get isRunning => true; // Keeps UI indicators active

  // ... equality, hashCode, toString
}
```

The UI's `StatusIndicator` pattern-matches on `ActiveRunState`:

```dart
case ExecutingToolsState(:final pendingTools):
  'Executing: ${pendingTools.map((tc) => tc.name).join(', ')}';
```

### RunRegistry.replaceRun — atomic compare-and-swap

The plan originally used `registerRun()` for continuation runs, but this has
two problems:

1. **TOCTOU race:** Between checking `registry[handle.key] == handle` and
   calling `registerRun`, the user could re-send (calling `startRun`), which
   registers a new handle. The continuation's `registerRun` would then
   overwrite the user's new run.

2. **Lifecycle event:** `registerRun` emits `RunStarted`, which triggers
   unread-run logic and could cause UI flashes on continuations.

**Solution:** Add `replaceRun` to `RunRegistry`:

```dart
/// Atomically replaces oldHandle with newHandle if oldHandle is still
/// the registered handle for its key. Returns false if stale.
///
/// Emits [RunContinued] (not [RunStarted]) to distinguish system
/// continuations from user-initiated runs.
Future<bool> replaceRun(RunHandle oldHandle, RunHandle newHandle) async {
  _checkNotDisposed();
  if (_runs[oldHandle.key] != oldHandle) return false;
  await oldHandle.dispose();
  _runs[newHandle.key] = newHandle;
  _controller.add(RunContinued(key: newHandle.key));
  return true;
}
```

And add `RunContinued` to `run_lifecycle_event.dart`:

```dart
/// A run was replaced by a continuation run (tool result submission).
///
/// Distinguished from [RunStarted] so consumers can differentiate
/// user-initiated runs from system continuations.
class RunContinued extends RunLifecycleEvent {
  const RunContinued({required super.key});
}
```

### _currentHandle guard for background threads

When `_executeToolsAndContinue` completes in a background thread, it must NOT
blindly overwrite `_currentHandle`. The user may have navigated to a different
thread during tool execution.

```dart
// In _executeToolsAndContinue, after replaceRun succeeds:
if (identical(_currentHandle, oldHandle)) {
  _currentHandle = newHandle;
  state = newHandle.state;
}
// Otherwise: newHandle runs silently in the background.
// User sees it when they navigate back via _syncCurrentHandle().
```

### ToolCallMessage synthesis (critical step)

Before starting the continuation run, the orchestrator must:

1. Create a `ToolCallMessage` containing the executed `ToolCallInfo` list
   (with `status: completed/failed` and `result` populated)
2. Append it to `conversation.messages`
3. Clear `conversation.toolCalls`

This is required because `agui_message_mapper.convertToAgui()` reads
`ToolCallMessage` from the messages list to produce `AssistantMessage`
(with toolCalls) + `ToolMessage` (with results) for the backend.

### onError path: pending tools on stream failure

The plan triggers tool execution on `onDone`. But what if the stream terminates
via `onError` while tool calls have accumulated? The existing
`_handleFailureForRun` transitions to `CompletedState(Failed)` — pending
tool calls are abandoned.

**This is correct behavior.** If the backend errored mid-stream, the run is
broken. Tool results from a partial run would be meaningless — the backend
won't accept a continuation run for a failed run. The error message in
`CompletedState` tells the user what happened.

No special handling needed — `_handleFailureForRun` already covers this.

### Error handling and abort transitions in _executeToolsAndContinue

The entire continuation path must be wrapped in try/catch. **Every early
return must transition to a terminal state** — no path may leave the handle
stranded in `ExecutingToolsState`.

```dart
/// Max continuation depth to prevent infinite tool-call loops.
/// If the LLM keeps requesting tools beyond this depth, abort.
static const _maxContinuationDepth = 10;

Future<void> _executeToolsAndContinue(RunHandle handle, {int depth = 0}) async {
  try {
    // 0. Circuit breaker — prevent infinite multi-hop loops
    if (depth >= _maxContinuationDepth) {
      _abortToCompleted(
        handle,
        const FailedResult(errorMessage: 'Max tool continuation depth exceeded'),
      );
      return;
    }

    // 1. Execute tools
    final results = await Future.wait(...);

    // 2. Bail-out checks — each transitions to a terminal state
    if (!ref.mounted) return; // Notifier disposed — no state to update
    if (handle.cancelToken.isCancelled) {
      _abortToCompleted(handle, const CancelledResult(reason: 'User cancelled'));
      return;
    }
    if (_registry.getHandle(handle.key) != handle) {
      return; // Stale — new run already replaced us, nothing to clean up
    }

    // 3. Synthesize ToolCallMessage, create continuation run...
    final runInfo = await api.createRun(roomId, threadId);

    // 4. Post-API bail-out checks (same pattern)
    if (!ref.mounted) return;
    if (handle.cancelToken.isCancelled) {
      _abortToCompleted(handle, const CancelledResult(reason: 'User cancelled'));
      return;
    }

    // 5. Register continuation, start streaming...
    final replaced = await _registry.replaceRun(handle, newHandle);
    if (!replaced) {
      // Stale — dispose the new handle we just created
      await newHandle.dispose();
      return;
    }

    // 6. Guard _currentHandle for background threads
    if (identical(_currentHandle, handle)) {
      _currentHandle = newHandle;
      state = newHandle.state;
    }

  } catch (e, st) {
    _abortToCompleted(
      handle,
      FailedResult(errorMessage: e.toString(), stackTrace: st),
    );
  }
}

void _abortToCompleted(RunHandle handle, RunResult result) {
  final conv = (handle.state is ExecutingToolsState)
      ? (handle.state as ExecutingToolsState).conversation
      : handle.state.conversation;
  final completed = CompletedState(
    // Clear pending toolCalls so UI doesn't render stranded "pending" tools
    conversation: conv
        .copyWith(toolCalls: [])
        .withStatus(domain.Failed(error: result.toString())),
    result: result,
  );
  _registry.completeRun(handle, completed);
  _syncUiState(handle, completed);
}
```

**Key invariant:** every code path in `_executeToolsAndContinue` either:
(a) starts a continuation run, (b) calls `_abortToCompleted`, or
(c) returns because the handle is stale (new run already owns the state).
No path leaves `ExecutingToolsState` as the terminal state.

### replaceRun disposal ordering

`replaceRun` must NOT dispose the old handle before confirming the new
handle is ready. The correct order:

1. CAS check: `_runs[oldHandle.key] == oldHandle` → false means abort
2. Register new handle: `_runs[newHandle.key] = newHandle`
3. Emit lifecycle event
4. Dispose old handle **after** new handle is registered

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

If `_executeToolsAndContinue` fails after creating the new handle but
before calling `replaceRun`, the catch block disposes the new handle.

### Safety checks (consolidated)

| # | Check | When | Abort transition |
|---|-------|------|-----------------|
| 0 | `depth >= maxContinuationDepth` | Entry to `_executeToolsAndContinue` | `_abortToCompleted(handle, FailedResult('Max tool continuation depth exceeded'))` |
| 1 | Per-tool try/catch | Inside `Future.wait` | Mark individual tool as `failed`; continue with others |
| 2 | `ref.mounted` | After each async gap | Return silently (notifier disposed, no state to update) |
| 3 | `cancelToken.isCancelled` | After each async gap | `_abortToCompleted(handle, CancelledResult)` |
| 4 | `registry.getHandle(key) == handle` | After tool execution | Return silently (new run owns the state) |
| 5 | `registry.replaceRun(old, new)` | Before streaming Run 2 | Dispose new handle, return (new run owns the state) |
| 6 | `identical(_currentHandle, oldHandle)` | Before updating `_currentHandle` | Skip — continuation runs in background |
| 7 | try/catch around entire method | `_executeToolsAndContinue` | `_abortToCompleted(handle, FailedResult)` |

### Concurrency: tool calls across multiple threads

`RunRegistry` supports concurrent runs in different rooms/threads. Each
`RunHandle` is keyed by `ThreadKey(roomId, threadId)` and has its own
independent `StreamSubscription`. This means:

**Scenario:** Room A's Run 1 and Room B's Run 1 both finish with pending
tool calls at the same time.

```text
Thread A: Run 1 onDone → _handleDoneForRun(handleA)
                          → _executeToolsAndContinue(handleA)
                            → Future.wait(toolsA)
                            → api.createRun(roomA, threadA)  ← independent API call
                            → Run 2A streams

Thread B: Run 1 onDone → _handleDoneForRun(handleB)     (concurrent)
                          → _executeToolsAndContinue(handleB)
                            → Future.wait(toolsB)
                            → api.createRun(roomB, threadB)  ← independent API call
                            → Run 2B streams
```

**Why this is safe:**

| Concern | Why it works |
|---------|-------------|
| `ToolRegistry` | Immutable, stateless — `execute()` calls the executor function; concurrent calls are safe |
| `RunHandle` state | Each handle is scoped to its own thread; no shared mutable state between handles |
| `_currentHandle` | Only ONE handle drives UI state. `_syncUiState` checks `identical(handle, _currentHandle)` — background threads update their handles silently. Continuation guard prevents overwrite. |
| `api.createRun()` | Independent network calls to different threads; no shared lock |
| `_isStarting` guard | Only protects `startRun()`, not `_executeToolsAndContinue()` — no bottleneck |
| `registry.replaceRun()` | Keyed by ThreadKey; Thread A's replacement doesn't affect Thread B |

**What the user sees:**

- If viewing Thread A: UI shows "Executing tools..." → Run 2A text streams in
- Thread B executes tools in the background; its state updates on `handle.state`
- When user navigates to Thread B, `_syncCurrentHandle()` picks up Thread B's
  current state (which may be mid-tool-execution, streaming Run 2, or completed)

**Edge case — same thread, rapid re-send:**

If the user sends a new message in Thread A while tool execution is in progress:

- `startRun()` is called with the same ThreadKey
- `_registry.registerRun(newHandle)` disposes the old handle (cancels its
  subscription and cancel token)
- The in-flight `_executeToolsAndContinue` hits the `replaceRun` CAS check →
  returns false → aborts cleanly

**Test scenarios (Slice 3):**

- Concurrent tool execution: two handles with different ThreadKeys both
  execute tools simultaneously; verify both complete independently
- Stale handle: start new run on same thread during tool execution; verify
  old execution aborts and new run proceeds
- Navigation during execution: user switches threads while tools execute;
  verify `_currentHandle` is not overwritten

### Edge cases

| Case | Behavior |
|------|----------|
| Zero-argument tool | `ToolCallArgsEvent` never arrives; `ToolCallInfo.arguments` stays `''`; mapper normalizes to `'{}'` |
| Tool executor throws | `ToolCallInfo.status = failed`, `result = 'Error: ...'`; model receives error via `ToolMessage` |
| Stream errors with pending tools | `_handleFailureForRun` → `CompletedState(Failed)`; pending tools abandoned (backend run is broken) |
| User cancels during execution | `cancelToken.isCancelled` → `_abortToCompleted(CancelledResult)` |
| User navigates away during execution | `ref.mounted` false → return silently (notifier disposed) |
| User re-sends during execution | `replaceRun` CAS fails; old execution aborts, new run proceeds |
| User switches thread during execution | `identical(_currentHandle, oldHandle)` is false; continuation runs in background |
| Multi-hop (Run 2 triggers tools) | `onDone` for Run 2 checks toolCalls → same path → Run 3 (depth incremented) |
| Multi-hop infinite loop | Circuit breaker: `depth >= maxContinuationDepth` → `_abortToCompleted(FailedResult('Max tool continuation depth exceeded'))` |
| All tools fail | Continuation run still starts; model sees all `ToolMessage`s with error content and can respond |
| LLM emits text AND tool calls in same run | Text finalized via `TextMessageEnd`, tool calls accumulated separately; both coexist in conversation |
| Concurrent threads with tools | Each thread's tool execution is independent; `ToolRegistry` is stateless; no cross-thread interference |
| api.createRun fails during continuation | try/catch transitions to `CompletedState(Failed)`; no stuck ExecutingToolsState |
| RunContinued scroll behavior | `fix/scroll` branch: `ScrollToMessageSession._lastScrolledId` prevents re-scroll on continuation (same user message ID). `targetScrollOffset` persists so dynamic spacer keeps shrinking. No explicit handling needed. |

---

## Vertical Slices

### Slice 1: Wire ToolRegistry provider, tool registration, + event processor args accumulation

**Goal:** ToolRegistry is available app-wide with a clear registration path;
ToolCallArgs events accumulate arguments on ToolCallInfo; ToolCallEnd
transitions to `pending` (not removal).

**Deliverable:** White-label apps can define and inject custom tools via
`toolRegistryProvider.overrideWithValue(...)`. The UI accurately shows
"Calling: [tool_name]" while the LLM streams tool requests (existing
`ToolCallActivity` support). Tool arguments are correctly accumulated.
Execution doesn't happen yet — that's Slice 3.

**Tool registration design:**

Tools are registered at app startup via `ProviderScope.overrides` in
`runSoliplexApp()`. This follows the existing pattern for `shellConfigProvider`,
`preloadedPrefsProvider`, etc. (`lib/run_soliplex_app.dart:107-117`).

```dart
// lib/core/providers/api_provider.dart
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  // Default: empty registry. Override in ProviderScope for real tools.
  return const ToolRegistry();
});
```

```dart
// lib/run_soliplex_app.dart — in ProviderScope.overrides:
toolRegistryProvider.overrideWithValue(
  const ToolRegistry()
      .register(someClientTool)
      .register(anotherClientTool),
),
```

White-label apps call `runSoliplexApp()` with their own `main.dart` and can
register their own tool sets — same extensibility as `SoliplexConfig`.

Tool definitions are passed to the backend via `SimpleRunAgentInput.tools`
so the model knows which client-side tools are available. This wiring happens
in Slice 3 when `_executeToolsAndContinue` builds the continuation run input.

**Files changed:**

- `lib/core/providers/api_provider.dart` — add `toolRegistryProvider` (empty default)
- `lib/run_soliplex_app.dart` — document override pattern in docstring
  (no actual tools registered yet — concrete tools come in follow-up PRs)
- `packages/soliplex_client/lib/src/application/agui_event_processor.dart`:
  - `ToolCallStartEvent` → create `ToolCallInfo` with `status: streaming`
  - `ToolCallArgsEvent` → find matching ToolCallInfo, append delta to `arguments`
  - `ToolCallEndEvent` → transition matching ToolCallInfo to `status: pending`
    (keep in conversation.toolCalls, do NOT remove)
- Tests:
  - `packages/soliplex_client/test/application/agui_event_processor_test.dart` — new
    cases: args accumulation across multiple deltas, status transitions
    (streaming → pending), zero-arg tool (no ToolCallArgs events)

**Acceptance:**

- `flutter analyze --fatal-infos` clean
- All `soliplex_client` tests pass
- `toolRegistryProvider` exists and returns empty `ToolRegistry` by default
- ToolCallArgs events update ToolCallInfo.arguments
- ToolCallEnd leaves ToolCallInfo in conversation.toolCalls with `pending` status
- Zero-arg tools end up with empty arguments (mapper handles normalization)

---

### Slice 2: Mock LLM harness + secret-number integration tests

**Goal:** Create a lightweight mock AG-UI event stream for offline testing,
then use it to prove multi-tool-call execution works end-to-end.

**Deliverable:** The team can write deterministic tool-call tests without a
live backend, API keys, or network latency. The mock harness becomes shared
test infrastructure for all future tool-related work.

**Mock approach:** A single `buildMockEventStream(List<BaseEvent>)` factory
that wraps `Stream.fromIterable`. No framework, no scenario-builder classes —
tests compose event lists inline. A lightweight `MockAgUiClient` stub accepts
a callback `Stream<BaseEvent> Function(String, SimpleRunAgentInput)` so tests
can return different streams per run.

**Mock stream scenarios to cover in tests:**

1. Sequential tool calls: `RunStarted → Start(A) → Args(A) → End(A) → Start(B) → Args(B) → End(B) → RunFinished`
2. Zero-arg tool: `RunStarted → ToolCallStart → ToolCallEnd → RunFinished`
3. Text + tool calls: `RunStarted → TextStart → TextContent → TextEnd → ToolCallStart → ... → RunFinished`
4. Continuation run (Run 2): `RunStarted → TextStart → TextContent → TextEnd → RunFinished`

**Secret-number scenario (happy path):**

1. User sends "What are the secret numbers?"
2. Mock Run 1 emits 2 tool calls:
   `get_secret_number(name: "alice")` and `get_secret_number(name: "bob")`
3. Run 1 stream completes (`RunFinished`)
4. `onDone` detects 2 pending tool calls
5. Client executes both tools, returns `"42"` and `"7"`
6. Orchestrator synthesizes `ToolCallMessage`, starts Run 2
7. Mock Run 2 emits text: "Alice's number is 42, Bob's is 7"
8. Run 2 stream completes → `CompletedState`
9. Assert: conversation has UserMessage, ToolCallMessage (2 calls, both
   `completed`), TextMessage containing "42" and "7". Zero network calls.

**Additional test scenarios:**

- **Tool failure:** One tool throws, other succeeds → Run 2 still starts
- **Cancellation:** Cancel during execution → `CompletedState(CancelledResult)`
- **API failure:** api.createRun throws → `CompletedState(Failed)`, not stuck
- **Stale handle:** New `startRun` on same thread during execution → old aborts

**Files changed:**

- `test/helpers/mock_agui_stream.dart` — `buildMockEventStream(List<BaseEvent>)`
- `test/helpers/test_helpers.dart` — `MockAgUiClient` stub
- `test/core/providers/tool_call_integration_test.dart` — all scenarios above

**Acceptance:**

- All scenarios pass with zero network calls
- Mock streams are composable inline (no predefined scenario classes)
- Verifies multi-tool execution, continuation run, failure isolation,
  cancellation safety, API failure recovery, stale handle detection

---

### Slice 3: Tool execution orchestration in ActiveRunNotifier

**Goal:** When a run's stream completes (`onDone`) and pending tool calls
exist, execute them and start a continuation run.

**Deliverable:** End-to-end client-side tool execution is live. A developer
can write a Dart function (GPS lookup, local DB query, device API call),
register it via `toolRegistryProvider.overrideWithValue(...)`, and the LLM
will request it, wait for the result, and respond with context. Multi-hop
(LLM calls tool → result → LLM calls another tool) works automatically.

**Implementation (see Orchestration Design section above for full details):**

1. **Add `ExecutingToolsState` to `ActiveRunState`** (`active_run_state.dart`)
   - New sealed subclass with `conversation` and `pendingTools`
   - `isRunning => true` to keep UI indicators active

2. **Add `RunContinued` lifecycle event** (`run_lifecycle_event.dart`)
   - Distinguishes continuation from user-initiated `RunStarted`
   - **Consumer contract:** `_lifecycleSub` in ActiveRunNotifier filters on
     `RunCompleted` for unread-run logic (line 59-66). `RunContinued` is
     intentionally NOT handled there — continuations are not "new runs" and
     should not trigger unread indicators. If future consumers need it, they
     can add a case for `RunContinued`.

3. **Add `replaceRun` to `RunRegistry`** (`run_registry.dart`)
   - Atomic CAS: only replaces if oldHandle is still registered
   - Registers new handle BEFORE disposing old (safe ordering)
   - Emits `RunContinued` (not `RunStarted`)
   - Returns bool for success/failure

4. **Modify `_handleDoneForRun(handle)`** (`active_run_notifier.dart`)
   - Before transitioning to `CompletedState`, check
     `handle.state.conversation.toolCalls` for any with `status: pending`
   - If found: set `handle.state = ExecutingToolsState(...)`, sync UI,
     call `_executeToolsAndContinue(handle)`

5. **Add `_executeToolsAndContinue(handle)`** (`active_run_notifier.dart`)
   - Full implementation per the state transition diagram above
   - All 7 safety checks from the consolidated table
   - Every code path exits to a terminal state or hands off to new handle
   - `_currentHandle` guard for background threads

6. **Extract `_establishSubscription(handle, eventStream)`**
   - Shared by `startRun` and `_executeToolsAndContinue`
   - Creates `StreamSubscription` with `_processEventForRun`, `onError`,
     `onDone` handlers
   - Returns the subscription for the caller to store in RunHandle

7. **Update `StatusIndicator`** (`status_indicator.dart`)
   - Add pattern match for `ExecutingToolsState` (only needed here — the
     existing `ToolCallActivity` in `StreamingState` already shows
     "Calling: ..." during the streaming phase in Slice 1)

**Files changed:**

- `lib/core/models/active_run_state.dart` — add `ExecutingToolsState`
- `lib/core/models/run_lifecycle_event.dart` — add `RunContinued`
- `lib/core/services/run_registry.dart` — add `replaceRun`
- `lib/core/providers/active_run_notifier.dart`:
  - `_handleDoneForRun` — tool-call readiness check
  - `_executeToolsAndContinue` — execution + continuation + `_abortToCompleted`
  - `_establishSubscription` — extracted helper
- `lib/features/chat/widgets/status_indicator.dart` — `ExecutingToolsState` display
- Tests:
  - `test/core/providers/active_run_notifier_tool_call_test.dart`:
    - Happy path: Run 1 emits tools → executed → Run 2 returns text → CompletedState
    - Failure path: tool throws → ToolCallInfo.failed → Run 2 still starts
    - Cancel path: user cancels during execution → `CompletedState(CancelledResult)`
    - Multi-hop: Run 2 emits tools → Run 3 returns text
    - Concurrent threads: two ThreadKeys execute tools simultaneously → both complete
    - Stale handle: new startRun on same thread during execution → old aborts
    - Navigation during execution: `_currentHandle` not overwritten
    - API failure during continuation: `CompletedState(Failed)`
  - `test/core/models/active_run_state_test.dart` — `ExecutingToolsState` tests
  - `test/core/services/run_registry_test.dart` — `replaceRun` tests

**Acceptance:**

- `onDone` with pending tools triggers execution, not completion
- Tools execute in parallel with per-tool error isolation
- `ToolCallMessage` synthesized and appended before continuation
- Continuation run starts with tool results in AG-UI messages
- UI shows "Calling: ..." during streaming, "Executing: ..." during execution
- All 7 safety checks implemented; every path reaches terminal state
- `replaceRun` prevents TOCTOU race (new handle registered before old disposed)
- `_currentHandle` guard prevents background thread UI overwrite
- `RunContinued` event emitted; unread-run logic ignores it
- Multi-hop works (Run 2 → tools → Run 3)
- All existing notifier tests still pass

---

### Slice 4: Cleanup stale branches and PRs

**Goal:** Close stale PRs with rationale, delete remote branches.

**Actions:**

- Close #291 (test/patrol-tool-calling) — replaced by mock-LLM tests in Slice 2
- Close #294 (refactor/notifier-stream-setup) — superseded by Slice 3's
  `_establishSubscription` extraction
- Review #290 (refactor/notifier-test-container) — keep separate, merge if
  still useful after Slice 2's test harness is in place
- Delete remote branches: `feat/client-tool-calling-v2`,
  `test/patrol-tool-calling`, `refactor/notifier-stream-setup`

---

## Dependency Graph

```text
Slice 1 (provider + event processor)
  ↓
Slice 2 (mock LLM harness + secret-number tests)  ←  depends on Slice 1
  ↓
Slice 3 (orchestration)  ←  depends on Slice 1 + Slice 2
  ↓
Slice 4 (cleanup)  ←  after all slices merged
```

## Resolved Design Decisions

1. **`_establishSubscription` location:** Private helper on `ActiveRunNotifier`.
   It requires `_agUiClient`, `ref`, `_registry`, and internal logging — too
   many dependencies to extract meaningfully.

2. **Execution phase state:** `ExecutingToolsState` subclass of `ActiveRunState`
   (not `StreamingState`, not a flag on `RunHandle`). The AG-UI stream is dead
   when tools execute — using `StreamingState` would violate its semantic
   contract. `ActiveRunState` is the right level because the UI already
   pattern-matches on it for status display.

3. **Continuation run registration:** Atomic `replaceRun` CAS on `RunRegistry`
   (not `registerRun`). Prevents TOCTOU race with user re-send. Emits
   `RunContinued` instead of `RunStarted` to avoid UI flashes and incorrect
   unread-run notifications.

4. **PR #290 (test container refactor):** Keep separate from this work. It's
   an independent test cleanup that can be reviewed on its own merits.

5. **Multi-hop tool calling:** Supported by design. The `onDone` handler
   checks for pending tools on every run completion. Run 2 → tools → Run 3
   works with zero additional code.

6. **`_currentHandle` guard:** Background tool execution must NOT overwrite
   `_currentHandle`. Check `identical(_currentHandle, oldHandle)` before
   updating. If user navigated away, continuation runs silently in the
   background and becomes visible when user navigates back.
