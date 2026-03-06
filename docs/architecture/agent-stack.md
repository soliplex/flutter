# Agent Runtime Stack Architecture

The Soliplex agent stack lives in `packages/soliplex_agent/` and provides
a layered orchestration framework for running AI agents. It depends only
on `soliplex_client` and `soliplex_logging` -- no Flutter imports allowed.

## Layer Overview

```text
Consumer (Flutter / CLI / TUI / Tests)
    |
AgentRuntime
    * session pool, concurrency guards
    * ephemeral thread lifecycle
    |
AgentSession
    * auto tool-execute loop
    * signals (runState, sessionState, lastExecutionEvent)
    * parent-child graph
    |
RunOrchestrator
    * AG-UI SSE state machine
    * tool yield/resume loop (max 10 depth)
    * error classification
    |
soliplex_client (transport)
    * SoliplexApi (REST)
    * AgUiStreamClient (SSE)
```

Data flows downward as commands (spawn, cancel, submit tools) and upward
as state changes (signals, streams, futures). Each layer owns a single
responsibility:

**AgentRuntime** is the top-level facade. It spawns `AgentSession`
instances, enforces platform concurrency limits, manages ephemeral thread
cleanup, and tracks active sessions via a signal.

**AgentSession** wraps a `RunOrchestrator` and automatically executes
client-side tool calls via the `runToCompletion` callback. It implements
`ToolExecutionContext` so tools can access cancellation, child spawning,
event emission, and session-scoped extensions. Sessions form a
parent-child tree for cascading cancellation and disposal.

**RunOrchestrator** drives a single AG-UI run lifecycle. It subscribes
to the SSE stream from `AgUiStreamClient`, processes events into a `RunState`
sealed hierarchy, and manages the tool yield/resume loop with a depth
limit of 10.

**soliplex_client** provides the transport layer: `SoliplexApi` for REST
(thread/run creation, deletion) and `AgUiStreamClient` for SSE streaming.
See `docs/architecture/http-stack.md` for transport details.

## Key Types Quick Reference

| Type | Description | File |
|------|-------------|------|
| `AgentRuntime` | Top-level facade; spawns and manages sessions | `runtime/agent_runtime.dart` |
| `AgentSession` | Single autonomous interaction; auto tool loop | `runtime/agent_session.dart` |
| `AgentSessionState` | Lifecycle enum: spawning, running, completed, failed, cancelled | `runtime/agent_session_state.dart` |
| `RunOrchestrator` | AG-UI SSE state machine; tool yield/resume | `orchestration/run_orchestrator.dart` |
| `RunState` | Sealed: IdleState, RunningState, ToolYieldingState, CompletedState, FailedState, CancelledState | `orchestration/run_state.dart` |
| `AgentResult` | Sealed: AgentSuccess, AgentFailure, AgentTimedOut | `models/agent_result.dart` |
| `FailureReason` | Enum: serverError, authExpired, networkLost, rateLimited, toolExecutionFailed, internalError, cancelled | `models/failure_reason.dart` |
| `ThreadKey` | Typedef record `({String serverId, String roomId, String threadId})` | `models/thread_key.dart` |
| `ExecutionEvent` | Sealed: 13 variants for UI observability | `orchestration/execution_event.dart` |
| `ToolRegistry` | Immutable registry of tool definitions and executors | `tools/tool_registry.dart` |
| `ClientTool` | Tool definition paired with its executor function | `tools/tool_registry.dart` |
| `ToolRegistryResolver` | Typedef: `Future<ToolRegistry> Function(String roomId)` | `tools/tool_registry_resolver.dart` |
| `ToolExecutionContext` | Interface: cancelToken, spawnChild, emitEvent, getExtension | `tools/tool_execution_context.dart` |
| `SessionExtension` | Interface: onAttach, tools, onDispose | `runtime/session_extension.dart` |
| `SessionExtensionFactory` | Typedef: `Future<List<SessionExtension>> Function()` | `runtime/session_extension.dart` |
| `PlatformConstraints` | Interface: parallelism, concurrency, re-entrancy flags | `host/platform_constraints.dart` |
| `HostApi` | Interface: platform boundary (DataFrames, charts, invoke) | `host/host_api.dart` |
| `AgentApi` | Interface: sub-agent spawning from scripting (integer handles) | `host/agent_api.dart` |
| `FormApi` | Interface: dynamic form creation from scripting | `host/form_api.dart` |
| `ServerConnection` | Immutable value object: serverId + api + agUiStreamClient | `runtime/server_connection.dart` |
| `ServerRegistry` | Mutable registry of ServerConnection instances | `runtime/server_registry.dart` |
| `MultiServerRuntime` | Coordinator wrapping per-server AgentRuntime instances | `runtime/multi_server_runtime.dart` |

All paths above are relative to `packages/soliplex_agent/lib/src/`.

### Core Interfaces

```dart
class AgentRuntime {
  AgentRuntime({
    required ServerConnection connection,
    required ToolRegistryResolver toolRegistryResolver,
    required PlatformConstraints platform,
    required Logger logger,
    SessionExtensionFactory? extensionFactory,
  });

  ReadonlySignal<List<AgentSession>> get sessions;
  List<AgentSession> get activeSessions;
  AgentSession? getSession(ThreadKey key);

  Future<AgentSession> spawn({
    required String roomId,
    required String prompt,
    String? threadId,
    Duration? timeout,
    bool ephemeral = true,
    AgentSession? parent,
  });

  Future<List<AgentResult>> waitAll(List<AgentSession> sessions, {Duration? timeout});
  Future<AgentResult> waitAny(List<AgentSession> sessions, {Duration? timeout});
  Future<void> cancelAll();
  Future<void> dispose();
}
```

```dart
class AgentSession implements ToolExecutionContext {
  final String id;
  final ThreadKey threadKey;
  final bool ephemeral;
  List<AgentSession> get children;
  AgentSessionState get state;
  Future<AgentResult> get result;

  ReadonlySignal<RunState> get runState;
  ReadonlySignal<AgentSessionState> get sessionState;
  ReadonlySignal<ExecutionEvent?> get lastExecutionEvent;

  Future<AgentResult> awaitResult({Duration? timeout});
  void cancel();
  void dispose();

  // ToolExecutionContext
  CancelToken get cancelToken;
  Future<AgentSession> spawnChild({required String roomId, required String prompt});
  void emitEvent(ExecutionEvent event);
  T? getExtension<T extends SessionExtension>();
}
```

## Session Lifecycle

### Spawn to Terminal State

```text
runtime.spawn(roomId, prompt)
  |
  +-- _guardNotDisposed()
  +-- _guardWasmReentrancy()     // WASM: reject if any session active
  +-- _guardConcurrency()        // reject if >= maxConcurrentBridges
  |
  +-- _resolveThread(roomId, threadId)
  |     |-- threadId provided? -> reuse existing thread
  |     +-- threadId null? -> api.createThread(roomId) -> new ThreadKey
  |
  +-- _buildSession(key, roomId, ephemeral)
  |     |-- toolRegistryResolver(roomId) -> base ToolRegistry
  |     |-- extensionFactory() -> List<SessionExtension>
  |     |-- merge extension tools into registry
  |     +-- create RunOrchestrator + AgentSession
  |
  +-- _trackSession(session)     // add to _sessions map, emit signal
  +-- parent?.addChild(session)  // register in parent-child graph
  |
  +-- session.start(userMessage, existingRunId)
  |     |-- _attachExtensions()  // call onAttach on each extension
  |     |-- subscribe to orchestrator.stateChanges
  |     +-- orchestrator.runToCompletion(key, userMessage, _executeAll)
  |
  +-- _scheduleCompletion(session, timeout)
        |-- on result: delete ephemeral thread, dispose session, remove
```

### Resuming Conversations

To resume an existing conversation, pass `threadId` to `spawn`:

```dart
final session = await runtime.spawn(
  roomId: 'weather',
  prompt: 'What about tomorrow?',
  threadId: existingThreadId,  // reuses the thread
);
```

When `threadId` is provided, `_resolveThread` skips thread creation and
builds a `ThreadKey` directly. The backend appends the new message to the
existing conversation history.

### Ephemeral Cleanup

When `ephemeral: true` (the default), the runtime deletes the thread via
`api.deleteThread()` after the session completes or if `spawn` fails
before the session starts. Thread deletion errors are logged but
swallowed. The `_deletedThreadIds` set prevents double-deletion.

### Cancellation Cascade

Cancelling a session cascades to all children depth-first:

```text
parent.cancel()
  +-- child1.cancel()
  |     +-- grandchild.cancel()
  |           +-- orchestrator.cancelRun()
  +-- child2.cancel()
  |     +-- orchestrator.cancelRun()
  +-- orchestrator.cancelRun()   // parent's own orchestrator
```

`cancelRun()` fires the `CancelToken`, cancels the SSE subscription, and
emits `CancelledState`. If the orchestrator is in `ToolYieldingState`,
the transition is immediate (no stream to cancel).

### Dispose Cascade

Disposing follows the same depth-first pattern but also releases
resources:

```text
session.dispose()
  +-- children.dispose() (each)
  +-- _disposeExtensions()       // call onDispose on each extension
  +-- _subscription.cancel()
  +-- _orchestrator.dispose()
  +-- _completeIfPending()       // complete result with AgentFailure
  +-- signal.dispose() (all 3)
```

If the session was not yet terminal when disposed, the result completer
is completed with `AgentFailure(reason: internalError)`.

## Signals vs Streams

`AgentSession` exposes three reactive signals for synchronous UI reads:

| Signal | Type | Updates When |
|--------|------|-------------|
| `runState` | `ReadonlySignal<RunState>` | Every `RunState` change from the orchestrator |
| `sessionState` | `ReadonlySignal<AgentSessionState>` | Lifecycle transitions (spawning -> running -> terminal) |
| `lastExecutionEvent` | `ReadonlySignal<ExecutionEvent?>` | Each tool execution start/complete, text delta, terminal event |

`AgentRuntime` exposes one signal:

| Signal | Type | Updates When |
|--------|------|-------------|
| `sessions` | `ReadonlySignal<List<AgentSession>>` | Sessions spawned or removed |

Signals are synchronous, require no subscription management, and are
composable via the `signals_core` library. They are the recommended
API for reactive consumers.

### Deprecated Stream APIs

`AgentSession.stateChanges` (`Stream<RunState>`) and
`AgentRuntime.sessionChanges` (`Stream<List<AgentSession>>`) still exist
but are deprecated in favor of the signal equivalents. Both delegate to
the same underlying data.

### Barrel Re-exports

`soliplex_agent.dart` re-exports `ReadonlySignal` and `Signal` from
`signals_core` so consumers do not need a direct dependency on
`package:signals_core`.

> **Note:** No consumer currently reads these signals. CLI uses
> `awaitResult()` (Future). TUI uses `stateChanges` (Stream). The
> integration guide describes the intended signal-based patterns.

## ExecutionEvent System

`ExecutionEvent` is a sealed class with 13 variants for fine-grained UI
observability. Events are emitted via the `lastExecutionEvent` signal on
`AgentSession`.

| Variant | Fields | Emitted When |
|---------|--------|-------------|
| `TextDelta` | `delta: String` | Streamed assistant text fragment |
| `ThinkingStarted` | -- | Model enters reasoning phase |
| `ThinkingContent` | `delta: String` | Streamed thinking text fragment |
| `ServerToolCallStarted` | `toolName, toolCallId` | Server-side tool execution begins |
| `ServerToolCallCompleted` | `toolCallId, result` | Server-side tool execution ends |
| `ClientToolExecuting` | `toolName, toolCallId` | Client-side tool execution begins |
| `ClientToolCompleted` | `toolCallId, result, status` | Client-side tool execution ends |
| `RunCompleted` | -- | Run finished successfully |
| `RunFailed` | `error: String` | Run failed |
| `RunCancelled` | -- | Run cancelled |
| `StateUpdated` | `aguiState: Map<String, dynamic>` | AG-UI state update from backend |
| `StepProgress` | `stepName: String` | Pipeline step progress |
| `CustomExecutionEvent` | `type: String, payload: Map` | Extension point for plugins |

`CustomExecutionEvent` allows `SessionExtension` implementations to emit
domain-specific events (e.g., `'monty.execution_started'`) without
modifying the sealed hierarchy.

## Tool Execution

### ToolRegistry

`ToolRegistry` is an immutable, copy-on-write registry of client-side
tools. Each `register()` call returns a new registry instance.

```dart
var registry = const ToolRegistry();
registry = registry.register(ClientTool.simple(
  name: 'get_weather',
  description: 'Get current weather',
  executor: (toolCall, context) async => '{"temp": 72}',
));
```

### ClientTool

A `ClientTool` pairs an AG-UI `Tool` definition (sent to the backend)
with a `ToolExecutor` function:

```dart
typedef ToolExecutor = Future<String> Function(
  ToolCallInfo toolCall,
  ToolExecutionContext context,
);
```

The `ClientTool.simple` constructor provides sensible defaults --
`parameters` defaults to `emptyToolParameters`:

```dart
const Map<String, Object> emptyToolParameters = {
  'type': 'object',
  'properties': <String, Object>{},
};
```

### Aliases

`ToolRegistry.alias()` maps alternative names to canonical tool names.
Aliases are used for lookup and execution but are not included in
`toolDefinitions` (the list sent to the backend). This handles cases
where the backend sends tool calls using a short name but the tool is
registered under its full name.

### ToolRegistryResolver

```dart
typedef ToolRegistryResolver = Future<ToolRegistry> Function(String roomId);
```

The runtime calls this at spawn time to get the tool registry for a
room. The Flutter app implements it as a closure capturing a Riverpod
`ref`.

### ToolExecutionContext

```dart
abstract interface class ToolExecutionContext {
  CancelToken get cancelToken;
  Future<AgentSession> spawnChild({required String roomId, required String prompt});
  void emitEvent(ExecutionEvent event);
  T? getExtension<T extends SessionExtension>();
}
```

`AgentSession` implements this interface. Tools access cancellation
tokens, spawn child agents, emit progress events, and retrieve
session-scoped extensions through this context.

### Execution Flow

When the orchestrator yields tool calls, `AgentSession._executeAll`
runs all pending tools in parallel via `Future.wait`:

```text
_executeAll(pendingTools)
  +-- Future.wait(pendingTools.map(_executeSingle))
        |
        +-- emitEvent(ClientToolExecuting)
        +-- toolRegistry.execute(toolCall, this).timeout(60s)
        +-- emitEvent(ClientToolCompleted)
        |
        +-- on error: log warning, return failed status
```

Tool timeout is 60 seconds (`_toolTimeout`). Errors are isolated per
tool -- a failing tool does not abort sibling tools. The error message
is forwarded to the model as the tool result.

## RunOrchestrator State Machine

```text
                    startRun / runToCompletion
  IdleState ─────────────────────────────────────> RunningState
                                                    |
                           ┌────────────────────────┤
                           |                        |
                           v                        v
                    (RunFinishedEvent)        (RunErrorEvent /
                           |                  stream error /
                    ┌──────┴──────┐           onDone w/o terminal)
                    |             |                  |
              pending tools?  no tools              v
                    |             |            FailedState
                    v             v
            ToolYieldingState  CompletedState
                    |
            ┌───────┼─────────┐
            |       |         |
         execute  depth>10  cancelRun
         tools      |         |
            |       v         v
            |  FailedState  CancelledState
            v
     submitToolOutputs -> new RunningState (new backend run)

  Any state ──> cancelRun() ──> CancelledState
```

### Key Implementation Details

**`runToCompletion`** is the recommended entry point. It drives the full
tool yield/resume loop internally via `_driveToolLoop`. While active,
`startRun` and `submitToolOutputs` throw `StateError`.

**`_maxToolDepth = 10`** -- if the tool yield/resume cycle exceeds 10
iterations, the orchestrator transitions to `FailedState` with
`FailureReason.toolExecutionFailed`.

**Stale subscription guard** -- `_subscriptionEpoch` increments on each
new SSE subscription. The `onDone` callback checks the epoch to ignore
stale stream completions from previous runs.

**`CancelToken` lifecycle** -- a fresh `CancelToken` is created per SSE
subscription in `_subscribeToStream`. When `cancelRun()` fires the
token, the SSE stream emits `CancellationError`, which the error handler
maps to `CancelledState`.

**SSE endpoint format** -- `rooms/{roomId}/agui/{threadId}/{runId}`.

## Error Classification

The `classifyError` function maps exceptions to `FailureReason`:

| Exception | FailureReason | Notes |
|-----------|--------------|-------|
| `AuthException` | `authExpired` | 401/403 from REST or SSE |
| `NetworkException` | `networkLost` | Connection failures, timeouts |
| `TransportError` (401/403) | `authExpired` | AG-UI transport errors |
| `TransportError` (429) | `rateLimited` | Too Many Requests |
| `TransportError` (other) | `serverError` | Other HTTP errors |
| Any other `Object` | `internalError` | Catch-all |

### Consumer Action Table

| FailureReason | Recommended Action |
|--------------|--------------------|
| `serverError` | Show error message, offer retry |
| `authExpired` | Trigger token refresh, then retry |
| `networkLost` | Show offline indicator, auto-retry on reconnect |
| `rateLimited` | Back off, show "busy" indicator |
| `toolExecutionFailed` | Log tool error, show partial result if available |
| `internalError` | Log full error, show generic failure message |
| `cancelled` | No action (user-initiated) |

## Platform Constraints

`PlatformConstraints` is an abstract interface with two implementations:

| Property | `NativePlatformConstraints` | `WebPlatformConstraints` |
|----------|----|-----|
| `supportsParallelExecution` | `true` | `false` |
| `supportsAsyncMode` | `false` | `false` |
| `maxConcurrentBridges` | 4 (default, configurable) | 1 |
| `supportsReentrantInterpreter` | `true` | `false` |

### WASM Deadlock Scenario

On web, the WASM interpreter is single-threaded and non-reentrant. If a
running Python script calls `wait_all()` to spawn sub-agents, and those
sub-agents need to execute Python tools, the interpreter cannot re-enter.
`AgentRuntime._guardWasmReentrancy()` prevents this by rejecting
`spawn()` when `supportsReentrantInterpreter` is false and any session
is active.

`_guardConcurrency()` enforces `maxConcurrentBridges` on all platforms.
On native (4 bridges), this allows parallel agent sessions each with
their own Isolate-backed interpreter. On web (1 bridge), it serializes
all sessions.

## Parent-Child Sessions

Sessions form a tree via `AgentSession.addChild` / `removeChild`.
The `spawnChild` method on `ToolExecutionContext` delegates to
`AgentRuntime.spawn` with `parent: this`:

```dart
Future<AgentSession> spawnChild({
  required String roomId,
  required String prompt,
  String? threadId,
  Duration? timeout,
  bool ephemeral = true,
}) {
  return _runtime.spawn(
    roomId: roomId,
    prompt: prompt,
    threadId: threadId,
    timeout: timeout,
    ephemeral: ephemeral,
    parent: this,
  );
}
```

**Cancellation cascade** -- `cancel()` iterates children depth-first
before cancelling its own orchestrator.

**Dispose cascade** -- `dispose()` iterates children depth-first,
disposes extensions, cancels subscription, disposes orchestrator.

**Isolated failure** -- a child failure does not automatically fail the
parent. The parent receives `AgentFailure` when it calls
`awaitResult()` on the child, and decides how to handle it.

**Cleanup on spawn failure** -- if `session.start()` throws, the
runtime removes the child from the parent, removes it from tracking,
deletes the ephemeral thread, and disposes the session.

## Session Extensions

Extensions are capabilities bound to the lifecycle of a single
`AgentSession`. They provide tools and resources that are created when
the session starts and released when it ends.

### Interface

```dart
abstract interface class SessionExtension {
  Future<void> onAttach(AgentSession session);
  List<ClientTool> get tools;
  void onDispose();
}
```

**`onAttach`** is called after session creation, before the run starts.
The session reference enables extensions to spawn children, emit events,
or access other extensions.

**`tools`** returns `ClientTool` instances that are merged into the
session's `ToolRegistry` during `_buildSession`. The tool list must be
stable after `onAttach` completes.

**`onDispose`** is called when the session is disposed. Must be
idempotent.

### Factory

```dart
typedef SessionExtensionFactory = Future<List<SessionExtension>> Function();
```

Passed to `AgentRuntime` at construction. Called once per `spawn()` to
create extensions for the new session.

### Tool Merging

During `_buildSession`, the runtime resolves the base `ToolRegistry`
via `toolRegistryResolver(roomId)`, then merges each extension's tools:

```dart
for (final ext in extensions) {
  for (final tool in ext.tools) {
    toolRegistry = toolRegistry.register(tool);
  }
}
```

Extension tools augment (not replace) the base registry.

### getExtension<T>()

Tools access extensions via the `ToolExecutionContext`:

```dart
final env = context.getExtension<ScriptEnvironmentExtension>();
```

Returns `null` if no extension of type `T` is attached.

## Scripting Engine Integration

The scripting layer bridges Python interpreters into the agent session
lifecycle via the extension system.

### ScriptEnvironment

```dart
abstract interface class ScriptEnvironment {
  List<ClientTool> get tools;
  void dispose();
}
```

Owns interpreter resources (bridge, registries) and exposes them as
`ClientTool` instances. The runtime is agnostic about interpreter
technology (WASM, subprocess, etc.) -- it only sees `tools`.

### ScriptEnvironmentExtension

Adapter that wraps a `ScriptEnvironment` as a `SessionExtension`:

```dart
class ScriptEnvironmentExtension implements SessionExtension {
  ScriptEnvironmentExtension(this._environment);

  @override
  Future<void> onAttach(AgentSession session) async {}

  @override
  List<ClientTool> get tools => _environment.tools;

  @override
  void onDispose() => _environment.dispose();
}
```

### wrapScriptEnvironmentFactory

Converts a `ScriptEnvironmentFactory` into a `SessionExtensionFactory`:

```dart
SessionExtensionFactory wrapScriptEnvironmentFactory(
  ScriptEnvironmentFactory factory,
) {
  return () async {
    final env = await factory();
    return [ScriptEnvironmentExtension(env)];
  };
}
```

### Host API Boundary

Three interfaces define the platform boundary for scripting:

**`HostApi`** -- visual rendering (DataFrames, charts) and platform
services (location, camera, file picker). The `invoke` method uses
namespaced names:

- `native.*` -- GPS, clipboard, file picker, biometrics
- `ui.*` -- Flutter dialogs, navigation

**`AgentApi`** -- sub-agent spawning from Python. Uses integer handles
for session tracking. `RuntimeAgentApi` is the production implementation
backed by `AgentRuntime`. Handles are evicted after terminal operations
to prevent unbounded growth.

**`FormApi`** -- dynamic form creation from scripting. Returns integer
handles for forms, supports validation error setting.

### Test Doubles

`FakeHostApi` stores DataFrames and charts in memory with configurable
`invoke` handler. `FakeAgentApi` records calls and returns canned
responses. Both follow the same pattern for testing.

## Multi-Server Runtime

`MultiServerRuntime` coordinates multiple `AgentRuntime` instances, one
per backend server. It routes operations by `serverId`.

```dart
class MultiServerRuntime {
  MultiServerRuntime({
    required ServerRegistry registry,
    required ToolRegistryResolver toolRegistryResolver,
    required PlatformConstraints platform,
    required Logger logger,
    SessionExtensionFactory? extensionFactory,
  });

  AgentRuntime runtimeFor(String serverId);

  Future<AgentSession> spawn({
    required String serverId,
    required String roomId,
    required String prompt,
    ...
  });

  List<AgentSession> get activeSessions;
  AgentSession? getSession(ThreadKey key);
  Future<List<AgentResult>> waitAll(...);
  Future<AgentResult> waitAny(...);
  Future<void> cancelAll();
  Future<void> dispose();
}
```

**`ServerRegistry`** is a mutable registry of `ServerConnection`
instances. `add()` throws on duplicate `serverId`. `require()` throws
if the server is not registered.

**`ServerConnection`** is an immutable value object grouping `serverId`,
`SoliplexApi`, and `AgUiStreamClient`. The convenience factory
`ServerConnection.create` wires up clients from a server URL and a single
shared `SoliplexHttpClient` (appending `/api/v1` automatically). AG-UI
streams are request-scoped, so REST and SSE safely share one client.

**Lazy runtime creation** -- `runtimeFor` creates `AgentRuntime`
instances on first access using `AgentRuntime.fromConnection`.

## Troubleshooting

**WASM session rejected with StateError**
Check `PlatformConstraints.supportsReentrantInterpreter`. On web, only
one session can run at a time. If a tool tries to spawn a child session,
the guard rejects it. Solution: use `NativePlatformConstraints` for
multi-session scenarios, or serialize sessions on web.

**Tool depth limit exceeded**
The orchestrator stops after 10 yield/resume cycles. This usually means
the model is stuck in a tool-calling loop. Check that tool results are
meaningful and that the model's system prompt discourages repeated calls.

**Session disposed before completion**
If `dispose()` is called on a running session, the result completer is
completed with `AgentFailure(reason: internalError, error: 'Session
disposed before completion')`. Check that the runtime or parent session
is not being disposed prematurely.

**Thread deletion fails silently**
Ephemeral thread deletion errors are logged at warning level but
swallowed. Check logs if threads accumulate on the server. The
`_deletedThreadIds` set prevents double-deletion attempts.

**Extension tools not appearing**
Verify that `extensionFactory` is passed to `AgentRuntime` at
construction. Extension tools are merged into the registry during
`_buildSession` -- if the factory returns an empty list, no extension
tools are registered.

**Stale stream events after cancel**
The `_subscriptionEpoch` guard in `RunOrchestrator` ignores `onDone`
callbacks from stale subscriptions. If events still appear after cancel,
check that `cancelRun()` was called (not just `CancelToken.cancel()`).

**classifyError returns internalError for known exceptions**
The error classifier only handles `AuthException`, `NetworkException`,
and `TransportError`. Other `SoliplexException` subtypes (e.g.,
`NotFoundException`, `ApiException`) are not classified and fall through
to `internalError`. This is intentional -- those exceptions indicate
programming errors (wrong endpoint, invalid request), not runtime
conditions.

## File Index

All paths relative to `packages/soliplex_agent/lib/src/`.

| File | Role |
|------|------|
| `host/agent_api.dart` | `AgentApi` interface for sub-agent spawning |
| `host/fake_agent_api.dart` | `FakeAgentApi` test double |
| `host/fake_host_api.dart` | `FakeHostApi` test double |
| `host/form_api.dart` | `FormApi` interface for dynamic forms |
| `host/host_api.dart` | `HostApi` interface for platform boundary |
| `host/native_platform_constraints.dart` | `NativePlatformConstraints` (Isolate-based) |
| `host/platform_constraints.dart` | `PlatformConstraints` abstract interface |
| `host/runtime_agent_api.dart` | `RuntimeAgentApi` production AgentApi |
| `host/web_platform_constraints.dart` | `WebPlatformConstraints` (WASM) |
| `models/agent_result.dart` | `AgentResult` sealed class (Success, Failure, TimedOut) |
| `models/failure_reason.dart` | `FailureReason` enum (7 values) |
| `models/thread_key.dart` | `ThreadKey` typedef record (3-tuple) |
| `orchestration/error_classifier.dart` | `classifyError` function |
| `orchestration/execution_event.dart` | `ExecutionEvent` sealed class (13 variants) |
| `orchestration/run_orchestrator.dart` | `RunOrchestrator` state machine |
| `orchestration/run_state.dart` | `RunState` sealed class (6 variants) |
| `runtime/agent_runtime.dart` | `AgentRuntime` facade |
| `runtime/agent_session.dart` | `AgentSession` autonomous interaction |
| `runtime/agent_session_state.dart` | `AgentSessionState` enum (5 values) |
| `runtime/multi_server_runtime.dart` | `MultiServerRuntime` coordinator |
| `runtime/server_connection.dart` | `ServerConnection` value object |
| `runtime/server_registry.dart` | `ServerRegistry` mutable registry |
| `runtime/session_extension.dart` | `SessionExtension` interface + factory typedef |
| `scripting/script_environment.dart` | `ScriptEnvironment`, `ScriptEnvironmentExtension`, `wrapScriptEnvironmentFactory` |
| `tools/tool_execution_context.dart` | `ToolExecutionContext` interface |
| `tools/tool_registry.dart` | `ToolRegistry`, `ClientTool`, `ToolExecutor`, `emptyToolParameters` |
| `tools/tool_registry_resolver.dart` | `ToolRegistryResolver` typedef |
