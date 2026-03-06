# Agent Integration Guide

How to wire `soliplex_agent` into Flutter, CLI, and TUI consumers. This
guide covers provider setup, spawning sessions from UI events, handling
results, scripting engine integration, and platform limits.

For architecture internals (state machine, signals, extensions), see
[agent-stack.md](agent-stack.md).

## Consumer Landscape

Four consumer types exist today:

| Consumer | Framework | Depth | Status |
|----------|-----------|-------|--------|
| Flutter (demos) | Riverpod | `AgentRuntime` | Working |
| Flutter (chat) | Riverpod | `AgUiStreamClient` direct | Legacy |
| CLI | Pure Dart | `AgentRuntime` | Working |
| TUI | BLoC | `RunOrchestrator` direct | Legacy |

Two integration depths:

- **AgentRuntime path** (recommended) -- full session lifecycle, auto
  tool execution, signals, extensions, parent-child sessions
- **RunOrchestrator path** (advanced/legacy) -- manual state machine,
  manual tool submission, no session abstraction

New consumers should use the AgentRuntime path. The RunOrchestrator path
is for consumers that need direct control over the SSE state machine.

## Wiring AgentRuntime (Flutter + Riverpod)

### Foundation Providers

The app provides platform constraints and a bridge cache in
`lib/core/providers/api_provider.dart`:

```dart
final platformConstraintsProvider = Provider<PlatformConstraints>((ref) {
  return kIsWeb
      ? const WebPlatformConstraints()
      : const NativePlatformConstraints();
});

final bridgeCacheProvider = Provider<BridgeCache>((ref) {
  final platform = ref.watch(platformConstraintsProvider);
  return BridgeCache(limit: platform.maxConcurrentBridges);
});

final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return const ToolRegistry();
});
```

`platformConstraintsProvider` selects native or web constraints.
`bridgeCacheProvider` creates a Monty interpreter pool sized by the
platform's `maxConcurrentBridges` (4 on native, 1 on web).
`toolRegistryProvider` holds the base tool registry -- white-label apps
override this to inject custom tools.

### Creating AgentRuntime

Construct `AgentRuntime` from a `ServerConnection`:

```dart
final connection = ServerConnection.create(
  serverId: 'prod',
  serverUrl: 'https://api.example.com',
  httpClient: httpClient,
);
final runtime = AgentRuntime(
  connection: connection,
  toolRegistryResolver: (roomId) async => toolRegistry,
  platform: const NativePlatformConstraints(),
  logger: Loggers.agent,
);
```

In a Riverpod notifier, construct the runtime during initialization and
dispose it on teardown:

```dart
class MyAgentNotifier extends Notifier<MyState> {
  late final AgentRuntime _runtime;

  @override
  MyState build() {
    final connection = ref.watch(serverConnectionProvider);
    final platform = ref.watch(platformConstraintsProvider);
    _runtime = AgentRuntime(
      connection: connection,
      toolRegistryResolver: (roomId) async =>
          ref.read(toolRegistryProvider),
      platform: platform,
      logger: Loggers.agent,
    );
    ref.onDispose(() => _runtime.dispose());
    return MyState.idle();
  }
}
```

### Key Constructor Parameters

| Parameter | Type | Required | Default |
|-----------|------|----------|---------|
| `connection` | `ServerConnection` | Yes | -- |
| `toolRegistryResolver` | `ToolRegistryResolver` | Yes | -- |
| `platform` | `PlatformConstraints` | Yes | -- |
| `logger` | `Logger` | Yes | -- |
| `extensionFactory` | `SessionExtensionFactory?` | No | `null` |
| `serverId` | `String` | No | `'default'` |

## Click Event to LLM Call

A typical Flutter flow: user taps a send button, the notifier spawns a
session, and the UI rebuilds as results arrive.

### Step 1: Widget Dispatches Action

```dart
class ChatInput extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.send),
      onPressed: () {
        final text = _controller.text;
        if (text.isNotEmpty) {
          ref.read(chatNotifierProvider.notifier).send(
            roomId: 'my-room',
            prompt: text,
          );
          _controller.clear();
        }
      },
    );
  }
}
```

### Step 2: Notifier Spawns Session

```dart
class ChatNotifier extends Notifier<ChatState> {
  late final AgentRuntime _runtime;
  String? _activeThreadId;

  Future<void> send({
    required String roomId,
    required String prompt,
  }) async {
    state = ChatState.loading();

    try {
      final session = await _runtime.spawn(
        roomId: roomId,
        prompt: prompt,
        threadId: _activeThreadId, // null = new thread
        ephemeral: _activeThreadId == null,
      );

      // Save thread for follow-up messages
      _activeThreadId = session.threadKey.threadId;

      // Wait for completion
      final result = await session.awaitResult(
        timeout: const Duration(minutes: 2),
      );

      state = switch (result) {
        AgentSuccess(:final output) => ChatState.success(output),
        AgentFailure(:final reason, :final error) =>
          ChatState.error('$reason: $error'),
        AgentTimedOut(:final elapsed) =>
          ChatState.error('Timed out after $elapsed'),
      };
    } on StateError catch (e) {
      state = ChatState.error(e.message);
    }
  }
}
```

### Step 3: UI Rebuilds

```dart
class ChatView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatNotifierProvider);
    return switch (chat) {
      ChatIdle() => const Text('Ready'),
      ChatLoading() => const CircularProgressIndicator(),
      ChatSuccess(:final output) => Text(output),
      ChatError(:final message) => Text(message),
    };
  }
}
```

### What Happens Inside

When `spawn()` is called:

```text
1. Guards run: _guardNotDisposed, _guardWasmReentrancy, _guardConcurrency
2. Thread resolved: create new or reuse existing threadId
3. Session built: ToolRegistry merged with extension tools
4. Extensions attached: onAttach() called on each SessionExtension
5. RunOrchestrator.runToCompletion() starts the SSE state machine
6. Tool yield/resume loop runs automatically (up to depth 10)
7. Session completes: AgentResult returned via awaitResult()
8. Ephemeral cleanup: thread deleted if ephemeral=true
```

The consumer never drives the tool loop -- `AgentSession` handles it
automatically. Each tool call runs with a 60-second timeout. Tools
execute in parallel via `Future.wait`. Failing tools do not abort
siblings.

## Spawning and Resuming Sessions

### New Conversation (Ephemeral)

```dart
final session = await runtime.spawn(
  roomId: 'my-room',
  prompt: 'What is the capital of France?',
  // threadId: null (default) -- creates a new thread
  // ephemeral: true (default) -- deletes thread after completion
);
final result = await session.awaitResult();
```

The runtime creates a new server-side thread, runs the agent, and
deletes the thread after the session completes.

### Continuing a Conversation

```dart
// First message
final session1 = await runtime.spawn(
  roomId: 'my-room',
  prompt: 'Explain quantum computing',
  ephemeral: false, // keep the thread
);
final result1 = await session1.awaitResult();
final threadId = session1.threadKey.threadId;

// Follow-up message (same thread)
final session2 = await runtime.spawn(
  roomId: 'my-room',
  prompt: 'How does that relate to cryptography?',
  threadId: threadId,
  ephemeral: false,
);
final result2 = await session2.awaitResult();
```

When `threadId` is provided, the runtime skips thread creation and
reuses the existing conversation context.

### Spawn Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `roomId` | `String` | Required | Server-side room/agent configuration |
| `prompt` | `String` | Required | User message |
| `threadId` | `String?` | `null` | Existing thread for continuation |
| `timeout` | `Duration?` | `null` | Session-level timeout |
| `ephemeral` | `bool` | `true` | Delete thread after completion |
| `parent` | `AgentSession?` | `null` | Parent for child sessions |

## Handling Results

`AgentResult` is a sealed class with three variants. Use exhaustive
pattern matching:

```dart
final result = await session.awaitResult();

switch (result) {
  case AgentSuccess(:final output, :final runId):
    // output: last assistant message text
    // runId: backend run identifier
    print('Success: $output');

  case AgentFailure(:final reason, :final error):
    // reason: FailureReason enum
    // error: human-readable description
    switch (reason) {
      case FailureReason.authExpired:
        // Trigger re-authentication flow
        await refreshTokens();
      case FailureReason.rateLimited:
        // Back off and retry
        await Future.delayed(const Duration(seconds: 5));
      case FailureReason.networkLost:
        // Show offline indicator
        showOfflineBanner();
      case FailureReason.serverError:
      case FailureReason.toolExecutionFailed:
      case FailureReason.internalError:
      case FailureReason.cancelled:
        showError(error);
    }

  case AgentTimedOut(:final elapsed):
    print('Timed out after $elapsed');
}
```

### FailureReason Consumer Actions

| Reason | Source Exception | Recommended Action |
|--------|----------------|-------------------|
| `authExpired` | `AuthException`, 401/403 | Re-authenticate, retry |
| `rateLimited` | 429 | Exponential backoff |
| `networkLost` | `NetworkException` | Show offline state, retry on reconnect |
| `serverError` | Other HTTP errors | Show error, log for support |
| `toolExecutionFailed` | Tool threw exception | Log tool error, show fallback |
| `internalError` | Unexpected errors | Log, report bug |
| `cancelled` | User/parent cancellation | No action needed |

## Parallel Execution

### Wait for All Sessions

```dart
final sessions = await Future.wait([
  runtime.spawn(roomId: 'room-a', prompt: 'Task A'),
  runtime.spawn(roomId: 'room-b', prompt: 'Task B'),
  runtime.spawn(roomId: 'room-c', prompt: 'Task C'),
]);

final results = await runtime.waitAll(sessions);
// results: List<AgentResult> in same order as sessions
```

### Race: First Result Wins

```dart
final sessions = await Future.wait([
  runtime.spawn(roomId: 'fast-room', prompt: 'Quick answer'),
  runtime.spawn(roomId: 'slow-room', prompt: 'Detailed answer'),
]);

final first = await runtime.waitAny(sessions);
await runtime.cancelAll(); // cancel remaining
```

### Pipeline Pattern (from PipelineNotifier)

The demo `PipelineNotifier` executes a DAG of agent sessions. Nodes
within a layer run in parallel; layers execute sequentially:

```dart
for (final layer in dag.layers) {
  final layerSessions = <AgentSession>[];

  for (final node in layer.nodes) {
    final session = await runtime.spawn(
      roomId: node.roomId,
      prompt: node.buildPrompt(previousResults),
    );
    layerSessions.add(session);
  }

  final results = await runtime.waitAll(layerSessions);
  previousResults = results;
}
```

## Cancellation

### Cancel a Single Session

```dart
session.cancel();
// cancel() is synchronous -- fires CancelToken, cancels SSE subscription
```

### Cancel All Active Sessions

```dart
await runtime.cancelAll();
```

### Parent-Child Cascade

When a parent session is cancelled, all children are cancelled
depth-first before the parent's own orchestrator is cancelled:

```dart
final parent = await runtime.spawn(roomId: 'room', prompt: 'Start');

// Inside a tool executor, spawn a child:
final child = await context.spawnChild(
  roomId: 'sub-room',
  prompt: 'Sub-task',
);

// Cancelling parent cascades to child
parent.cancel();
// child is cancelled first, then parent
```

### CLI Signal Handler Pattern

```dart
var cancelCount = 0;
ProcessSignal.sigint.watch().listen((_) {
  cancelCount++;
  if (cancelCount == 1) {
    runtime.cancelAll();
  } else {
    exit(1); // force quit on second ^C
  }
});
```

## Implementing ToolRegistryResolver

`ToolRegistryResolver` returns a `ToolRegistry` for a given room.
This enables per-room tool configuration:

```dart
ToolRegistryResolver buildResolver(WidgetRef ref) {
  return (String roomId) async {
    final base = ref.read(toolRegistryProvider);

    // Room-specific tools
    final roomConfig = await ref.read(apiProvider).getRoomConfig(roomId);

    var registry = base;
    if (roomConfig.pythonEnabled) {
      registry = registry.register(ClientTool(
        definition: Tool(
          name: 'execute_python',
          description: 'Execute Python code',
          parameters: executePythonParams,
        ),
        executor: pythonExecutor,
      ));
    }

    return registry;
  };
}
```

### Tool Registration

`ToolRegistry` is immutable and copy-on-write. Each `register()` call
returns a new instance:

```dart
var registry = const ToolRegistry();

registry = registry.register(ClientTool(
  definition: Tool(
    name: 'get_weather',
    description: 'Get current weather for a city',
    parameters: weatherParams,
  ),
  executor: (toolCall, context) async {
    final city = toolCall.args['city'] as String;
    final weather = await fetchWeather(city);
    return jsonEncode(weather);
  },
));

// Aliases map alternative names to existing tools
registry = registry.alias('weather', 'get_weather');
```

Tool executors receive `ToolCallInfo` (tool name, call ID, arguments)
and `ToolExecutionContext` (cancel token, child spawning, event
emission, extension access). The executor returns a `String` result
that is sent back to the model.

### Tool Execution Flow

```text
Model returns tool_calls in RunFinished event
    |
RunOrchestrator enters ToolYieldingState
    |
AgentSession._executeAll receives pending tools
    |
Each tool runs in parallel via Future.wait
    |  - 60-second timeout per tool
    |  - Errors isolated per tool (siblings continue)
    |  - Result: String or error message
    |
AgentSession submits all results back to orchestrator
    |
RunOrchestrator starts new backend run with tool outputs
    |
Loop repeats (max depth: 10)
```

## Wiring the Scripting Engine

The scripting engine connects Monty Python interpreters to the agent
layer via `SessionExtension`.

### Architecture

```text
AgentRuntime
    |
    | extensionFactory: () async => [ScriptEnvironmentExtension(...)]
    |
AgentSession
    | onAttach -> extension.onAttach(session)
    | tool calls -> extension.tools merged into ToolRegistry
    | dispose -> extension.onDispose() -> environment.dispose()
    |
ScriptEnvironmentExtension
    | wraps ScriptEnvironment
    |
MontyScriptEnvironment (in soliplex_scripting)
    | owns MontyBridge (Monty Python interpreter)
    | provides execute_python tool
    | HostFunctionWiring: host functions callable from Python
    |
Host APIs (separate interfaces)
    | HostApi: platform services (DataFrames, charts, invoke)
    | AgentApi: sub-agent spawning from Python
    | FormApi: dynamic form creation
```

### BridgeCache

`BridgeCache` is a singleton pool of Monty interpreter bridges, sized
by `PlatformConstraints.maxConcurrentBridges`:

| Platform | Max Bridges | Reason |
|----------|------------|--------|
| Native (Isolates) | 4 | Each bridge runs in its own isolate |
| Web (WASM) | 1 | Single-threaded; reentrant calls deadlock |

The cache is provided as a Riverpod provider in `api_provider.dart`:

```dart
final bridgeCacheProvider = Provider<BridgeCache>((ref) {
  final platform = ref.watch(platformConstraintsProvider);
  return BridgeCache(limit: platform.maxConcurrentBridges);
});
```

### Wiring SessionExtensionFactory

To enable scripting in agent sessions, pass an `extensionFactory` to
`AgentRuntime`:

```dart
final runtime = AgentRuntime(
  bundle: bundle,
  toolRegistryResolver: resolver,
  platform: platform,
  logger: logger,
  extensionFactory: () async {
    final bridge = await bridgeCache.acquire();
    final hostBundle = createFlutterHostBundle(
      onChartCreated: chartNotifier.add,
      onChartUpdated: chartNotifier.update,
    );
    final env = MontyScriptEnvironment(
      bridge: bridge,
      hostBundle: hostBundle,
    );
    return [ScriptEnvironmentExtension(env)];
  },
);
```

The factory runs once per session. The `ScriptEnvironmentExtension`
adapter bridges `ScriptEnvironment` (tools + dispose) to the
`SessionExtension` lifecycle (onAttach, tools, onDispose).

### Convenience Wrapper

`wrapScriptEnvironmentFactory` converts a `ScriptEnvironmentFactory`
to a `SessionExtensionFactory`:

```dart
final runtime = AgentRuntime(
  ...
  extensionFactory: wrapScriptEnvironmentFactory(() async {
    final bridge = await bridgeCache.acquire();
    return MontyScriptEnvironment(bridge: bridge, hostBundle: bundle);
  }),
);
```

### Host Function Boundary

`HostApi` defines what platform operations the agent can perform.
The Flutter app implements it for rendering (DataFrames, charts);
`invoke()` is the extensibility point for platform services:

| Namespace | Example | Status |
|-----------|---------|--------|
| `native.location` | GPS coordinates | Not implemented |
| `native.clipboard` | Read/write clipboard | Not implemented |
| `native.file_picker` | File picker dialog | Not implemented |
| `ui.show_dialog` | Flutter dialog | Not implemented |
| `ui.navigate` | GoRouter navigation | Not implemented |

The `invoke()` method is the designated extension point. Implementing
a new platform service requires only adding a case to the host app's
`HostApi.invoke()` switch.

### AgentApi: Sub-Agent Spawning from Python

`RuntimeAgentApi` lets Python scripts spawn sub-agents:

```dart
final agentApi = RuntimeAgentApi(runtime: runtime);

// Python script calls: agent.spawn("room", "prompt")
// Returns integer handle
final handle = await agentApi.spawnAgent('room', 'sub-task');

// Python script calls: agent.get_result(handle)
final output = await agentApi.getResult(handle);
// Handle evicted after terminal operation
```

Handles are integer keys into an internal map. They are evicted after
terminal operations (`getResult`, `cancelAgent`, `waitAll`) to prevent
unbounded growth.

## Platform Constraints

| Property | Native | Web (WASM) | Purpose |
|----------|--------|------------|---------|
| `supportsParallelExecution` | `true` | `false` | Isolate availability |
| `supportsAsyncMode` | `false` | `false` | Reserved for future use |
| `maxConcurrentBridges` | 4 | 1 | Monty interpreter pool size |
| `supportsReentrantInterpreter` | `true` | `false` | WASM deadlock prevention |

### WASM Deadlock Prevention

On web, `supportsReentrantInterpreter` is `false`. The WASM runtime
is single-threaded: if a running session's tool calls back into the
interpreter (e.g., Python tool spawning a child agent that also needs
Python), it deadlocks.

`AgentRuntime._guardWasmReentrancy` prevents this:

```text
Web + any session active + new spawn() -> StateError thrown
```

On native, isolates provide true parallelism. Multiple sessions can
run concurrently up to `maxConcurrentBridges`.

### Concurrency Guard

`_guardConcurrency` enforces `maxConcurrentBridges` on all platforms:

```text
activeSessions.length >= maxConcurrentBridges -> StateError thrown
```

This prevents resource exhaustion regardless of platform.

## Reactive UI with Signals

`AgentSession` exposes three reactive signals:

| Signal | Type |
|--------|------|
| `runState` | `ReadonlySignal<RunState>` |
| `sessionState` | `ReadonlySignal<AgentSessionState>` |
| `lastExecutionEvent` | `ReadonlySignal<ExecutionEvent?>` |

`AgentRuntime` exposes:

| Signal | Type | Updates |
|--------|------|---------|
| `sessions` | `ReadonlySignal<List<AgentSession>>` | Session added/removed |

Signals are synchronous -- reading `.value` returns the current state
immediately without awaiting. The `soliplex_agent` barrel re-exports
`ReadonlySignal` and `Signal` from `signals_core`.

### Intended Riverpod Bridge Pattern

Signals can bridge to Riverpod via `effect()`:

```dart
// In a notifier, after spawning a session:
final session = await _runtime.spawn(roomId: room, prompt: text);

final disposer = effect(() {
  final event = session.lastExecutionEvent.value;
  if (event == null) return;

  switch (event) {
    case TextDelta(:final delta):
      state = state.appendText(delta);
    case ThinkingContent(:final delta):
      state = state.appendReasoning(delta);
    case ClientToolExecuting(:final toolName):
      state = state.showToolRunning(toolName);
    case RunCompleted():
      state = state.markComplete();
    case RunFailed(:final error):
      state = state.markError(error);
    default:
      break;
  }
});

ref.onDispose(disposer);
```

This enables real-time streaming UI without manual SSE subscription.
The signal updates synchronously as events arrive from the
orchestrator.

> **Note:** No consumer currently reads these signals. CLI uses
> `awaitResult()` (Future). TUI uses `stateChanges` (Stream). The signal
> pattern above is the intended path for new consumers.

### Deprecated Stream APIs

`AgentSession.stateChanges` and `AgentRuntime.sessionChanges` still
exist but are deprecated in favor of signals. Both delegate to the
same underlying data. New code should use signals.

## Current Integration Gaps

These are known gaps between the agent layer's capabilities and how
consumers actually use it today.

### Signals Unused by Any Consumer

All four signals (`runState`, `sessionState`, `lastExecutionEvent`,
`sessions`) are built and tested but no CLI command or TUI cubit reads
them. CLI uses `awaitResult()` (Future). TUI uses `stateChanges`
(Stream).

## Reference Consumers

### CLI (`soliplex_cli`)

The cleanest consumer. Demonstrates:
- `AgentRuntime` construction with `ServerConnection`
- Interactive prompt loop with thread persistence per room
- Background session spawning (`/spawn`)
- `waitAll` / `waitAny` for multi-session coordination
- Verbose state tracing via `stateChanges` stream
- SIGINT signal handling for graceful cancellation
- No stubs, no workarounds

### TUI (`soliplex_tui`)

BLoC-based consumer using `RunOrchestrator` directly:
- `TuiChatCubit` listens to `orchestrator.stateChanges`
- Maps `RunState` to `TuiChatState` hierarchy
- Auto-executes tools on `ToolYieldingState`
- Uses `_StubExecutionContext` (legacy, planned V8 migration)

### Demo Notifiers (Flutter)

`PipelineNotifier` and `DebateNotifier` demonstrate multi-session
patterns:
- Create `AgentRuntime` per run
- Spawn multiple `AgentSession` instances (parallel or sequential)
- Per-session `HostApi` isolation for chart/DataFrame state
- Per-session `MontyToolExecutor` construction
- Result handling via `AgentResult` pattern matching

### AgUiBridgeAdapter (Scripting)

Stateless adapter in `soliplex_scripting` that maps Monty bridge
events to AG-UI protocol events:

| Bridge Event | AG-UI Event |
|-------------|------------|
| `BridgeRunStarted` | `RunStartedEvent` |
| `BridgeRunFinished` | `RunFinishedEvent` |
| `BridgeTextContent` | `TextMessageContentEvent` |
| `BridgeToolCallStart` | `ToolCallStartEvent` |
| `BridgeToolCallResult` | `ToolCallResultEvent` |
| (+ 7 more) | (1:1 mapping) |

## Troubleshooting

**StateError on spawn()**
Check `maxConcurrentBridges`. On web, only 1 concurrent session is
allowed. On native, the default is 4. If all slots are taken,
`spawn()` throws.

**Tools not executing**
Verify `ToolRegistryResolver` returns a registry containing the
expected tools. Tools must be registered by exact name. Use
`registry.alias()` for alternative names.

**Session hangs without completing**
Check tool timeout. Individual tools time out after 60 seconds. If a
tool is blocking indefinitely, it will be cancelled. Also check
`_maxToolDepth` (10) -- if the model keeps requesting tools beyond
depth 10, the session fails.

**Ephemeral thread not deleted**
Thread deletion errors are logged but swallowed. Check logs for
deletion failures. The `_deletedThreadIds` guard prevents
double-deletion attempts.

**Scripting bridge not available**
Verify `BridgeCache` has available bridges. On web, only 1 bridge
exists. If it is in use by another session, the factory will block
until it is released.
