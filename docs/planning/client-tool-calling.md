# Client-Side Tool Calling — Smallest PR

## Context

PR #83 (`feat/client-tool-calling`) went stale. PR #236 (`feat/patrol-client-tools`)
is a compatible superset. Main already has tool-call event detection
(ToolCallStart/End) but no argument capture, execution, or continuation flow.
We need the minimal delta to make client-side tool calling work end-to-end,
plus a unit test.

- **Source:** Cherry-pick from `origin/feat/patrol-client-tools` (PR #236),
  tool-calling code only.
- **Branch:** `feat/client-tool-calling-v2` from `main`.

### Parallel work: AG-UI multiplexing

A separate effort (not this PR) is adding multiplexing so multiple AG-UI runs
can execute concurrently across the same thread, different threads, different
rooms, and even different servers. The user will be able to see multiple active
runs simultaneously. Design choices here must not paint us into a corner — in
particular, tool registration and execution must be decoupled from any single
notifier instance.

Multiplexing will convert `activeRunNotifierProvider` from a singleton to a
`NotifierProvider.family` keyed by `(roomId, threadId)`. Each visible run gets
its own notifier instance, stream subscription, and tool execution lifecycle.
The shared `ToolRegistry` provider is already safe for concurrent use
(immutable, stateless).

**What the multiplexing PR will need to change:**

1. Convert `activeRunNotifierProvider` to
   `NotifierProvider.family<..., ({String roomId, String threadId})>`
2. Update all UI consumers to pass the current room/thread key when watching
3. Update derived providers (`canSendMessageProvider`, `isStreamingProvider`,
   `messagesProvider`) to use the family key
4. Scope `AgUiClient` — currently singleton, may need per-server instances if
   hitting different backends
5. Ensure tool executors are safe for concurrent use (document this contract)

The tool calling infrastructure from this PR carries forward unchanged.

## Key Design Decision: Where to store `roomId`

The notifier needs `roomId` to call `_continueWithToolResults()`. Two options:

### Option A: Private internal state (recommended)

Store `roomId` in **`RunningInternalState`** (private notifier state). This
avoids updating 76 constructor calls across 10 test files — the single biggest
scope reduction.

### Option B: Public state classes

Add `roomId` to `RunningState` and `CompletedState`. More discoverable, but
requires updating every constructor call and test that builds these states
(~76 call sites across ~10 test files). Better long-term if other consumers
need `roomId`, but out of scope for this PR.

## Design Rationale: `streaming` status and `ToolRegistry`

External review suggested dropping `ToolCallStatus.streaming` (just use
`pending` everywhere) and replacing `ToolRegistry` with a raw
`Map<String, ToolExecutor>` inside the notifier. We keep both for these
reasons:

### Why keep `streaming`

- `streaming` = still receiving argument chunks via `ToolCallArgs` deltas.
  `pending` = arguments complete, ready to execute.
- Without the distinction, `ToolCallEnd` has no clean transition target — we
  would need a second meaning of `pending` or a separate "ready" flag.
- The UI can show different indicators: "receiving..." vs "ready to run."
- The enum ripple is real but bounded — a handful of test expectations to
  update, listed explicitly in the plan.

### Why keep `ToolRegistry`

- With multiplexing on the horizon, tool registration must be shareable across
  notifiers via a provider — not wired into a single notifier's private state.
- `ToolRegistry` is ~72 lines, trivially testable, immutable, and provides a
  clean lookup/execute API.
- A raw map would need to be duplicated or plumbed ad-hoc into each notifier
  that needs tool execution. The class costs almost nothing now and avoids a
  refactor later.

## Files (2 new, 9 modified, ~470 lines)

### New Files

| # | File | Description |
|---|------|-------------|
| 1 | `packages/soliplex_client/lib/src/application/tool_registry.dart` | Immutable `ToolRegistry` + `ClientTool` + `ToolExecutor` typedef (~72 lines) |
| 2 | `packages/soliplex_client/test/application/tool_registry_test.dart` | Unit tests: registry CRUD, immutability, execute, StateError (~100 lines, uses inline test tool) |

### Modified Files

| # | File | Changes |
|---|------|---------|
| 3 | `packages/soliplex_client/lib/src/domain/chat_message.dart` | Add `streaming` to `ToolCallStatus` enum (before `pending`) |
| 4 | `packages/soliplex_client/lib/src/application/agui_event_processor.dart` | 3 fixes: ToolCallStart -> `streaming` status, NEW ToolCallArgs handler (accumulate delta), ToolCallEnd -> mark `pending` instead of removing |
| 5 | `packages/soliplex_client/lib/src/api/agui_message_mapper.dart` | Emit `ToolMessage` for `failed` tool calls (error content sent to model) |
| 6 | `packages/soliplex_client/lib/soliplex_client.dart` | Export `tool_registry.dart` |
| 7 | `lib/core/providers/api_provider.dart` | Add `toolRegistryProvider` (empty registry, tools registered app-side) |
| 8 | `lib/core/providers/active_run_notifier.dart` | Add `_toolRegistry` field, pass `tools` to `SimpleRunAgentInput`, add `roomId` to `RunningInternalState`, add tool execution check in `_processEvent`, add `_executeToolsAndContinue()` + `_continueWithToolResults()` methods |
| 9 | `packages/soliplex_client/test/application/agui_event_processor_test.dart` | Update ToolCallEnd test (now marks pending, not removes), add ToolCallArgs test, update ToolCallStart test for streaming status |
| 10 | `packages/soliplex_client/test/api/agui_message_mapper_test.dart` | Add tests for failed tool call ToolMessage emission |
| 11 | `test/core/providers/active_run_notifier_test.dart` | Add `toolRegistryProvider` override to test containers |

## Implementation Order

1. **Create `tool_registry.dart`** — pure Dart, no dependencies beyond ag_ui
   `Tool` and `ToolCallInfo`
2. **Add `streaming` to `ToolCallStatus`** in `chat_message.dart`
3. **Fix event processor** — ToolCallStart (streaming status), ToolCallArgs
   (new handler), ToolCallEnd (mark pending)
4. **Fix message mapper** — emit `ToolMessage` for `failed` tool calls with
   error content so the model sees failures
5. **Export `tool_registry.dart`** from `soliplex_client.dart`
6. **Add `toolRegistryProvider`** in `api_provider.dart` (empty registry;
   concrete tools registered app-side in a follow-up)
7. **Wire into active_run_notifier** — roomId in internal state, tool registry
   watch, tool definitions in input, execution check + two new methods
8. **Create unit test** for tool_registry (uses inline test tool, not a
   package-shipped demo tool)
9. **Update existing tests** — event processor tests, mapper tests, notifier
   test container

## Tool Call Lifecycle (End-to-End)

```text
Server sends ToolCallStartEvent  -> status: streaming, ToolCallActivity in UI
Server sends ToolCallArgsEvent   -> arguments accumulate via delta
Server sends ToolCallEndEvent    -> status: pending (ready to execute)
  (repeat above for each tool call in this turn)
_processEvent detects all calls pending -> _executeToolsAndContinue()
  1. PAUSE stream subscription (Safety 3: no late events)
  2. Mark all pending calls -> executing
  3. Execute each tool in isolated try/catch, collect results
     (Future.wait with per-tool error handling — one failure
      does not abort the batch)
  4. if (!mounted) return (Safety 1: user navigated away)
  5. Mark each call -> completed/failed based on its own result
  6. Cancel old subscription
  7. try: api.createRun() with tool results in messages
     catch: transition to FailedState with error (recovery below)
  8. if (!mounted) return (Safety 1)
  9. Subscribe to new stream
  10. Swap RunningInternalState (new subscription + runId)
      Public state stays RunningState throughout (Safety 2)
```

## UX: Stream Transition During Tool Execution

From the user's perspective, tool calling involves two separate AG-UI runs
stitched together invisibly. The user should never see a loading flash, a
state reset, or a "conversation ended" blip between them.

### What the user sees

```text
User sends message
  -> assistant starts typing (Run 1 begins, RunningState)
  -> assistant says "Let me check that..."
  -> tool indicator appears (ToolCallStart, status: streaming)
  -> tool indicator shows "running..." (ToolCallEnd, status: executing)
  -> tool indicator shows "done" (status: completed)
       *** Run 1 ends, Run 2 starts — user sees NOTHING change ***
  -> assistant continues typing (Run 2, same RunningState)
  -> assistant delivers final answer
  -> conversation idle (CompletedState)
```

### What happens underneath

The transition between Run 1 and Run 2 is the critical UX moment. The public
`state` object exposed to the UI **never leaves `RunningState`** during this
window. Internally:

- Run 1's stream subscription is paused, then cancelled
- Run 2 is created via `api.createRun()` with tool results
- Run 2's stream subscription replaces Run 1's in `RunningInternalState`
- `runId` is swapped to Run 2's ID
- The UI's `RunningState` reference is never replaced with `IdleState`,
  `CompletedState`, or any non-running state

The user perceives a single continuous assistant turn. The only visible
artifact of tool calling is the tool indicator (streaming -> executing ->
completed), which is intentional UI feedback.

### Edge cases

- **User navigates away mid-execution:** `mounted` check after each `await`
  silently bails out. No crash, no orphaned state.
- **Tool execution fails:** Tool call status becomes `failed`, error content
  is sent to the model via `ToolMessage`. The model receives the error in
  Run 2 and can respond (e.g. "Sorry, I couldn't look that up").
- **Multiple tools in one turn:** All execute in parallel with per-tool error
  isolation. One tool failing does not abort the others. Results sent in a
  single continuation. User sees multiple tool indicators resolve, then the
  assistant continues.
- **Continuation run fails:** If `api.createRun()` throws after tools
  executed (network error, server down), transition to `FailedState` with
  the error. The user sees "Something went wrong" and can retry. Tool
  results are already in the message list so a retry re-sends them.
- **Single tool fails in a batch:** That tool is marked `failed` with error
  content. Other tools in the batch still complete normally. The model
  receives both successes and failures and can respond accordingly.

## Outstanding Questions

### Resolved

1. **~~Missing DTO file.~~** `SimpleRunAgentInput` (from `ag_ui` package,
   `lib/src/client/client.dart:511`) already has an optional `List<Tool>?
   tools` field. No new file needed — just pass `tools:` in the existing
   constructor call at `active_run_notifier.dart:198`.
2. **Tool failure propagation.** Decision: **Option A** — emit `ToolMessage`
   for `failed` status too, with error content. This is a ~3-line change in
   `agui_message_mapper.dart` (added to modified files list above). The model
   sees the error and can respond accordingly.

### Safety (resolved)

All three issues occur at the same moment: tool execution begins. They layer
on each other — #3 first (stop incoming events), #1 at every await boundary
(guard against disposal), #2 throughout (never break the UI).

1. **SSE race during execution.** Decision: **pause the subscription** as the
   first line of `_executeToolsAndContinue()`, before any `await`. Pause (not
   cancel) so we can resume on catastrophic failure. Once paused, no late
   events can call `_processEvent` while we are executing tools.
2. **Async disposal race.** Decision: check `mounted` after every `await` in
   `_executeToolsAndContinue` and `_continueWithToolResults`. If `false`, the
   user navigated away — return silently. No state mutation on a disposed
   notifier.
3. **Stream transition flash.** Decision: never emit a non-`Running` public
   state during the transition. Cancel the old subscription, create the new
   run, subscribe to the new stream, and swap `RunningInternalState` fields
   (subscription, runId) — all while keeping the public `state` as
   `RunningState`. The UI sees uninterrupted "running" throughout.

### Semantic (resolved)

1. **`activeToolCalls` accuracy.** Decision: filter by status.
   `activeToolCalls` returns only `streaming` + `pending` calls (the ones the
   server is still describing). Once a call moves to `executing`/`completed`/
   `failed` it drops out of that getter. All tool call state is in-memory on
   `ActiveRunState` — gone on app restart.
2. **Out-of-order `ToolCallArgs`.** Decision: log warning + ignore. This is a
   protocol violation (critical server-side bug) but crashing the client is
   worse. Log at warning level with the unknown `toolCallId`, drop the event.
3. **~~`get_secret_tool.dart` location.~~** Decided: no demo tool in
   `soliplex_client`. Tool definitions live app-side (e.g. `lib/core/tools/`).
   Unit tests use an inline test tool. Concrete tools registered in a
   follow-up PR.
4. **Multiple tool calls in one run.** The AG-UI spec supports multiple
   `ToolCallStart` events before any `ToolCallEnd`. Decision:
   `_executeToolsAndContinue` collects **all** pending tool calls, executes
   them in parallel (`Future.wait`), then sends all results in a **single**
   continuation request (the `tool_outputs` field is explicitly an array).

## Testing Strategy

The async stream lifecycle, `mounted` checks, and "no UI flash" invariant are
the hardest parts to test. These patterns keep tests focused on observable
behavior without coupling to implementation details.

### StateRecorder — verify state transition invariants

Record every state emission via `container.listen` and assert on the sequence.
This is how we prove "no UI flash": every state between tool execution start
and final completion must be `RunningState`.

```dart
class StateRecorder<T> {
  StateRecorder(this.container, this.provider) {
    subscription = container.listen<T>(
      provider, (_, next) => states.add(next),
      fireImmediately: true,
    );
  }
  final ProviderContainer container;
  final ProviderListenable<T> provider;
  late final ProviderSubscription<T> subscription;
  final states = <T>[];
  void dispose() => subscription.close();
}
```

### Completer — simulate disposal mid-await

Hold a `Future` hostage with a `Completer`, dispose the container while the
notifier is awaiting, then complete. Verify no further state changes or API
calls occurred.

```dart
final blocker = Completer<void>();
when(() => mockApi.createRun(...))
    .thenAnswer((_) async { await blocker.future; return runInfo; });

// trigger tool execution, then dispose while awaiting
container.dispose();
blocker.complete();

// verify: no run-2 started, no new states recorded
```

### StreamController callbacks — verify pause/cancel/swap

Use `onPause`, `onCancel`, `onListen` on `StreamController` to observe
subscription lifecycle without accessing private fields:

```dart
final controller1 = StreamController<BaseEvent>(
  onPause: () => paused = true,
  onCancel: () => cancelled = true,
);
final controller2 = StreamController<BaseEvent>(
  onListen: () => run2Listened = true,
);
```

### Per-tool error isolation — deterministic fake executors

Register tools with known outcomes (success vs throw) and assert on per-tool
status in the conversation state (`completed` vs `failed`), not on
`Future.wait` internals.

### Rules to avoid brittle tests

- Assert on public `ActiveRunState` and messages, not private
  `_internalState` fields
- Drive with `BaseEvent` sequences and verify state outcomes, not method
  call order
- Use `verify()` only for observable API calls (`createRun`, `runAgent`)
- Use `addTearDown(container.dispose)` in every test to prevent listener
  leaks

## Test Plan (18 tests)

### New: `tool_registry_test.dart` (7 tests)

| Test | Description |
|------|-------------|
| register adds tool to registry | Registering a ClientTool makes it available via lookup |
| register returns new registry (immutable) | Original registry unchanged after register |
| lookup returns tool by name | Retrieve a registered tool by name |
| lookup throws StateError for unknown tool | Unregistered name throws |
| execute runs the tool executor | Invokes ToolExecutor, returns result string |
| execute with failing executor returns error | Throwing executor produces error, not exception |
| toolDefinitions returns ag_ui Tool list | Exposes definitions for SimpleRunAgentInput |

### Updated: `agui_event_processor_test.dart` (4 tests)

| Test | Description |
|------|-------------|
| ToolCallStart sets status to streaming | Existing test updated (was pending, now streaming) |
| ToolCallArgs accumulates argument delta | New — args event appends to tool call arguments |
| ToolCallArgs for unknown id is ignored | New — out-of-order args logged and dropped |
| ToolCallEnd sets status to pending | Existing test updated (was removing, now marks pending) |

### Updated: `agui_message_mapper_test.dart` (2 tests)

| Test | Description |
|------|-------------|
| failed tool call emits ToolMessage with error | New — failed status produces ToolMessage |
| pending/executing tool calls skip ToolMessage | New — only completed and failed emit |

### Updated: `active_run_notifier_test.dart` (5 tests)

| Test | Description |
|------|-------------|
| toolRegistryProvider override in container | Existing container updated with registry |
| tool execution pauses subscription first | New — stream paused before any await |
| tool execution checks mounted after await | New — disposed notifier returns silently |
| multiple pending tools execute in parallel | New — Future.wait, single continuation |
| state stays RunningState during transition | New — no intermediate non-Running state |

## Excluded (keeping PR small)

- `patrol_run_tool.dart` — patrol-specific, separate PR
- `roomId` on public `RunningState`/`CompletedState` — 76 constructor calls
  avoided
- `threadSelectionProvider` listener — unrelated improvement
- UI changes for tool call display
- Integration/E2E tests
- Planning/skills docs
- AG-UI multiplexing — parallel effort, separate PRs

## Verification

1. `dart format .` — no changes
2. `flutter analyze --fatal-infos` — zero issues
3. `dart test` in `packages/soliplex_client/` — all pass (new + updated tests)
4. `flutter test` — all pass (notifier tests with provider override)
5. Manual: run app, verify tool registry wiring loads without errors (concrete
   tool registration and end-to-end execution tested in follow-up PR)
