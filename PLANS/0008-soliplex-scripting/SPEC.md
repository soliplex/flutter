# Feature Specification: soliplex_scripting

## Overview

`soliplex_scripting` is a pure-Dart wiring package that connects `soliplex_agent`
(runtime orchestration) with `soliplex_interpreter_monty` (Python sandbox) to
enable LLM-generated Python execution as a client-side tool.

### Why a wiring package

The agent package owns ag-ui protocol types and orchestration. The interpreter
package owns the Monty bridge and host function dispatch. Neither should depend
on the other — that creates a circular dependency and forces the interpreter to
know about event protocols. A third package resolves the dependency diamond:

- `soliplex_agent` defines extension points (`ToolRegistryResolver`, `HostApi`,
  `PlatformConstraints`) but knows nothing about Python.
- `soliplex_interpreter_monty` defines the bridge and host function system but
  knows nothing about ag-ui events (after refactor).
- `soliplex_scripting` depends on both and wires them together.

All three surfaces — Flutter, CLI (`soliplex_cli`), and TUI (`soliplex_tui`) —
import `soliplex_scripting` to get `execute_python` as a registered client-side
tool. Surface-specific behavior (chart rendering, navigation, clipboard) is
injected via `HostApi` implementations.

## Problem Statement

The interpreter package currently depends on `ag_ui` and constructs ag-ui event
types directly:

1. **`MontyBridge.execute()` returns `Stream<BaseEvent>`** — the abstract
   interface is coupled to ag-ui.

2. **`DefaultMontyBridge._run()` constructs 12 ag-ui event types** —
   `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`, `StepStartedEvent`,
   `StepFinishedEvent`, `ToolCallStartEvent`, `ToolCallArgsEvent`,
   `ToolCallEndEvent`, `ToolCallResultEvent`, `TextMessageStartEvent`,
   `TextMessageContentEvent`, `TextMessageEndEvent`.

3. **`HostFunctionSchema.toAgUiTool()`** converts a host function schema to
   an ag-ui `Tool` type — coupling the schema layer to the protocol.

4. **`PythonExecutorTool.definition`** is a `const Tool(...)` — ag-ui at the
   tool definition level.

An interpreter should not know about event protocols. This coupling prevents
alternative runtimes (d4rt, js_interpreter) from reusing the bridge interface
without pulling in ag-ui. The refactor decouples the interpreter from ag-ui
entirely, moving protocol formatting to the wiring layer.

## Package Dependency Graph

```text
soliplex_agent ──────────────┐
  (depends: ag_ui,           │
   soliplex_client)          │
                             ▼
                  soliplex_scripting
                  (depends: ag_ui, soliplex_agent,
                   soliplex_interpreter_monty, meta)
                             ▲
soliplex_interpreter_monty ──┘
  (depends: dart_monty_platform_interface, meta)
  (NO ag_ui dependency after refactor)
```

Key constraints:

- `soliplex_interpreter_monty` must not import `ag_ui` or `soliplex_agent`.
- `soliplex_scripting` must not import `flutter` — pure Dart only.
- `soliplex_agent` must not import `soliplex_interpreter_monty`.
- The dependency graph is acyclic.

## Design Decision: ag-ui Decoupling

### 4a. BridgeEvent Sealed Hierarchy

A new `BridgeEvent` sealed class replaces ag-ui events in the interpreter
package. These are protocol-agnostic lifecycle events that any interpreter
runtime can emit.

```dart
// In soliplex_interpreter_monty/lib/src/bridge/bridge_event.dart

sealed class BridgeEvent {
  const BridgeEvent();
}

class BridgeRunStarted extends BridgeEvent {
  const BridgeRunStarted();
}

class BridgeRunFinished extends BridgeEvent {
  const BridgeRunFinished();
}

class BridgeRunError extends BridgeEvent {
  const BridgeRunError({required this.message});
  final String message;
}

class BridgeStepStarted extends BridgeEvent {
  const BridgeStepStarted({required this.stepId});
  final String stepId;
}

class BridgeStepFinished extends BridgeEvent {
  const BridgeStepFinished({required this.stepId});
  final String stepId;
}

class BridgeToolCallStart extends BridgeEvent {
  const BridgeToolCallStart({required this.callId, required this.name});
  final String callId;
  final String name;
}

class BridgeToolCallArgs extends BridgeEvent {
  const BridgeToolCallArgs({required this.callId, required this.delta});
  final String callId;
  final String delta;
}

class BridgeToolCallEnd extends BridgeEvent {
  const BridgeToolCallEnd({required this.callId});
  final String callId;
}

class BridgeToolCallResult extends BridgeEvent {
  const BridgeToolCallResult({required this.callId, required this.result});
  final String callId;
  final String result;
}

class BridgeTextStart extends BridgeEvent {
  const BridgeTextStart({required this.messageId});
  final String messageId;
}

class BridgeTextContent extends BridgeEvent {
  const BridgeTextContent({required this.messageId, required this.delta});
  final String messageId;
  final String delta;
}

class BridgeTextEnd extends BridgeEvent {
  const BridgeTextEnd({required this.messageId});
  final String messageId;
}
```

After refactor, `MontyBridge.execute()` returns `Stream<BridgeEvent>` and
`DefaultMontyBridge` emits `BridgeEvent` subclasses instead of ag-ui types.

### 4b. AgUiBridgeAdapter

A stateless adapter in `soliplex_scripting` maps `BridgeEvent`s to ag-ui
`BaseEvent`s. The mapping is 1:1 and exhaustive:

```dart
// In soliplex_scripting/lib/src/ag_ui_bridge_adapter.dart

import 'package:ag_ui/ag_ui.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

Stream<BaseEvent> adaptToAgUi(
  Stream<BridgeEvent> source, {
  required String threadId,
  required String runId,
}) {
  return source.map((event) => switch (event) {
    BridgeRunStarted()     => RunStartedEvent(threadId: threadId, runId: runId),
    BridgeRunFinished()    => RunFinishedEvent(threadId: threadId, runId: runId),
    BridgeRunError(:final message) => RunErrorEvent(message: message),
    BridgeStepStarted(:final stepId)  => StepStartedEvent(stepName: stepId),
    BridgeStepFinished(:final stepId) => StepFinishedEvent(stepName: stepId),
    BridgeToolCallStart(:final callId, :final name) =>
      ToolCallStartEvent(toolCallId: callId, toolCallName: name),
    BridgeToolCallArgs(:final callId, :final delta) =>
      ToolCallArgsEvent(toolCallId: callId, delta: delta),
    BridgeToolCallEnd(:final callId) =>
      ToolCallEndEvent(toolCallId: callId),
    BridgeToolCallResult(:final callId, :final result) =>
      ToolCallResultEvent(
        messageId: callId,
        toolCallId: callId,
        content: result,
      ),
    BridgeTextStart(:final messageId) =>
      TextMessageStartEvent(messageId: messageId),
    BridgeTextContent(:final messageId, :final delta) =>
      TextMessageContentEvent(messageId: messageId, delta: delta),
    BridgeTextEnd(:final messageId) =>
      TextMessageEndEvent(messageId: messageId),
  });
}
```

**Mapping table:**

| BridgeEvent | BaseEvent | Notes |
|-------------|-----------|-------|
| `BridgeRunStarted` | `RunStartedEvent` | threadId/runId injected by adapter |
| `BridgeRunFinished` | `RunFinishedEvent` | threadId/runId injected by adapter |
| `BridgeRunError` | `RunErrorEvent` | message passthrough |
| `BridgeStepStarted` | `StepStartedEvent` | stepId → stepName |
| `BridgeStepFinished` | `StepFinishedEvent` | stepId → stepName |
| `BridgeToolCallStart` | `ToolCallStartEvent` | 1:1 |
| `BridgeToolCallArgs` | `ToolCallArgsEvent` | 1:1 |
| `BridgeToolCallEnd` | `ToolCallEndEvent` | 1:1 |
| `BridgeToolCallResult` | `ToolCallResultEvent` | callId → messageId + toolCallId |
| `BridgeTextStart` | `TextMessageStartEvent` | 1:1 |
| `BridgeTextContent` | `TextMessageContentEvent` | 1:1 |
| `BridgeTextEnd` | `TextMessageEndEvent` | 1:1 |

### 4c. What Moves Where

| Item | Current Location | New Location | Reason |
|------|-----------------|--------------|--------|
| `PythonExecutorTool.definition` | `soliplex_interpreter_monty` | `soliplex_scripting` | Needs ag-ui `Tool` type |
| `HostFunctionSchema.toAgUiTool()` | `soliplex_interpreter_monty` | Extension in `soliplex_scripting` | Needs ag-ui `Tool` type |
| `toolDefToHostSchema()` | `soliplex_interpreter_monty` | Stays | Bridge-level types only |
| `roomToolDefsToMappings()` | `soliplex_interpreter_monty` | Stays | Bridge-level types only |
| `MontyBridge.toAgUiTools()` | `soliplex_interpreter_monty` | Removed (use extension) | Needs ag-ui `Tool` type |

After refactor, `HostFunctionSchema` has no `toAgUiTool()` method. Instead,
`soliplex_scripting` provides:

```dart
// In soliplex_scripting/lib/src/host_schema_ag_ui.dart

extension HostSchemaAgUi on HostFunctionSchema {
  Tool toAgUiTool() {
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final param in params) {
      properties[param.name] = <String, Object?>{
        'type': param.type.jsonSchemaType,
        if (param.description != null) 'description': param.description,
      };
      if (param.isRequired) required.add(param.name);
    }
    return Tool(
      name: name,
      description: description,
      parameters: <String, Object?>{
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
      },
    );
  }
}
```

## Extension Points in soliplex_agent

### ToolRegistryResolver

```dart
// packages/soliplex_agent/lib/src/tools/tool_registry_resolver.dart
typedef ToolRegistryResolver = Future<ToolRegistry> Function(String roomId);
```

Primary injection point for `execute_python`. The scripting package provides a
`ScriptingToolRegistryResolver` that wraps an existing resolver and appends the
`execute_python` `ClientTool` to the returned `ToolRegistry`.

### HostApi

```dart
// packages/soliplex_agent/lib/src/host/host_api.dart
abstract interface class HostApi {
  int registerDataFrame(Map<String, List<Object?>> columns);
  Map<String, List<Object?>>? getDataFrame(int handle);
  int registerChart(Map<String, Object?> chartConfig);
  Future<Object?> invoke(String name, Map<String, Object?> args);
}
```

Closure-captured by `MontyToolExecutor` host function handlers. Not injected
into `AgentRuntime` — the wiring layer connects `HostApi` methods to bridge
host functions via `HostFunctionWiring`.

### PlatformConstraints

```dart
// packages/soliplex_agent/lib/src/host/platform_constraints.dart
abstract interface class PlatformConstraints {
  bool get supportsParallelExecution;
  bool get supportsAsyncMode;
  int get maxConcurrentBridges;
  bool get supportsReentrantInterpreter;
}
```

`BridgeCache` reads `maxConcurrentBridges` to size the pool.
`supportsReentrantInterpreter` guards against WASM deadlocks when a sub-agent's
tool call would require Python execution while Python is already suspended.

### AgentSession._executeSingle()

```dart
// packages/soliplex_agent/lib/src/runtime/agent_session.dart:152
Future<ToolCallInfo> _executeSingle(ToolCallInfo toolCall) async {
  try {
    final result = await _toolRegistry.execute(toolCall);
    return toolCall.copyWith(
      status: ToolCallStatus.completed,
      result: result,
    );
  } on Object catch (error, stackTrace) { ... }
}
```

The auto-execute loop calls `ToolRegistry.execute()` which dispatches to
`ToolExecutor` functions. When the tool is `execute_python`, the executor is
`MontyToolExecutor.execute` provided by `soliplex_scripting`.

### RunOrchestrator → ToolYieldingState

```dart
// packages/soliplex_agent/lib/src/run/run_state.dart:184
class ToolYieldingState extends RunState {
  final List<ToolCallInfo> pendingToolCalls;
  final int toolDepth;
}
```

When the backend yields `execute_python` as a tool call, the orchestrator
transitions to `ToolYieldingState`. `AgentSession` detects this and calls
`_executeToolsAndResume()`, which invokes the scripting-provided executor.

## Extension Points in soliplex_interpreter_monty

### MontyBridge.execute()

```dart
// After refactor:
abstract class MontyBridge {
  List<HostFunctionSchema> get schemas;
  void register(HostFunction function);
  void unregister(String name);
  Stream<BridgeEvent> execute(String code);
  void dispose();
}
```

Returns `Stream<BridgeEvent>` (not `Stream<BaseEvent>`). The `toAgUiTools()`
method is removed from the interface.

### HostFunctionRegistry

```dart
// packages/soliplex_interpreter_monty/lib/src/bridge/host_function_registry.dart
class HostFunctionRegistry {
  void addCategory(String name, List<HostFunction> functions);
  List<HostFunction> get allFunctions;
  Map<String, List<HostFunctionSchema>> get schemasByCategory;
  void registerAllOnto(MontyBridge bridge);
}
```

The wiring layer uses `addCategory()` to register surface-specific host
functions (data frame, chart, platform services) and then
`registerAllOnto(bridge)` to bulk-register them plus introspection builtins.

### toolDefToHostSchema() / roomToolDefsToMappings()

```dart
// packages/soliplex_interpreter_monty/lib/src/bridge/tool_definition_converter.dart
HostFunctionSchema? toolDefToHostSchema(Map<String, dynamic> toolDef);
List<ToolNameMapping> roomToolDefsToMappings(List<Map<String, dynamic>> toolDefs);
```

Convert backend room tool definitions into bridge-level schemas and name
mappings. Stay in the interpreter package — no ag-ui dependency.

### SchemaExecutor

```dart
// packages/soliplex_interpreter_monty/lib/src/schema_executor.dart
class SchemaExecutor {
  void loadSchemas(Map<String, String> schemas);
  Future<Map<String, Object?>> validate(String schemaName, Map<String, Object?> rawJson);
}
```

Optional component for Python-based schema validation. Used independently of
the bridge for input validation.

### Bridge Lifecycle

```text
create MontyBridge
  → register host functions (via HostFunctionRegistry.registerAllOnto)
  → execute(code) → Stream<BridgeEvent> (repeatable)
  → dispose()
```

A bridge can execute multiple scripts sequentially. `BridgeCache` manages
creation, reuse, and eviction.

## Wiring Components in soliplex_scripting

### ScriptingToolRegistryResolver

Wraps an existing `ToolRegistryResolver` and appends `execute_python`:

```dart
class ScriptingToolRegistryResolver {
  ScriptingToolRegistryResolver({
    required ToolRegistryResolver inner,
    required MontyToolExecutor executor,
  });

  Future<ToolRegistry> call(String roomId) async {
    final registry = await inner(roomId);
    return registry.register(
      ClientTool(
        definition: pythonExecutorToolDefinition,
        executor: executor.execute,
      ),
    );
  }
}
```

### MontyToolExecutor

The `ToolExecutor` that handles `execute_python` tool calls:

```dart
class MontyToolExecutor {
  MontyToolExecutor({
    required BridgeCache bridgeCache,
    required HostFunctionWiring hostWiring,
  });

  Future<String> execute(ToolCallInfo toolCall) async {
    final code = _extractCode(toolCall);
    final bridge = await bridgeCache.acquire(toolCall.threadKey);
    hostWiring.registerOnto(bridge);
    final events = bridge.execute(code);
    return _collectTextResult(events);
  }
}
```

Extracts `code` from the tool call arguments, acquires a bridge from the cache,
registers host functions, executes, and collects the text result from
`BridgeEvent`s. Returns a `Future<String>` per the `ToolExecutor` typedef.

### BridgeCache

Manages a pool of `MontyBridge` instances keyed by thread:

```dart
class BridgeCache {
  BridgeCache({
    required PlatformConstraints platform,
    MontyBridge Function()? bridgeFactory,
  });

  Future<MontyBridge> acquire(ThreadKey key);
  void release(ThreadKey key);
  void evict(ThreadKey key);
  void disposeAll();
}
```

- **Keying:** `Map<ThreadKey, MontyBridge>` — one bridge per conversation
  thread for session continuity.
- **Lazy creation:** Bridges are created on first `acquire()` for a key.
- **LRU eviction:** When `platform.maxConcurrentBridges` is reached, the
  least recently used bridge is disposed and evicted.
- **Execution tracking:** Tracks which bridges are currently executing to
  prevent concurrent execution on the same bridge.

### HostFunctionWiring

Connects `HostApi` methods to `HostFunctionRegistry` entries:

```dart
class HostFunctionWiring {
  HostFunctionWiring({required HostApi hostApi});

  void registerOnto(MontyBridge bridge) {
    final registry = HostFunctionRegistry()
      ..addCategory('data', _dataFunctions())
      ..addCategory('chart', _chartFunctions())
      ..addCategory('platform', _platformFunctions());
    registry.registerAllOnto(bridge);
  }
}
```

Maps `HostApi` methods to `HostFunction` handlers:

| HostApi Method | Python Function | Category |
|----------------|-----------------|----------|
| `registerDataFrame(columns)` | `df_create(columns)` | data |
| `getDataFrame(handle)` | `df_get(handle)` | data |
| `registerChart(config)` | `chart_create(config)` | chart |
| `invoke(name, args)` | `host_invoke(name, args)` | platform |

### AgUiBridgeAdapter

Described in section 4b. Stateless `Stream<BridgeEvent>` → `Stream<BaseEvent>`
mapper. Used when the caller needs ag-ui events (e.g., for streaming to the
frontend). Not used by `MontyToolExecutor` directly, since it only needs the
text result.

### PythonExecutorTool Definition

```dart
// In soliplex_scripting/lib/src/python_executor_tool.dart

import 'package:ag_ui/ag_ui.dart' show Tool;

const pythonExecutorToolDefinition = Tool(
  name: 'execute_python',
  description: 'Execute Python code in a sandboxed interpreter. '
      'The code can call registered tool functions directly. '
      'Returns the text output or error message.',
  parameters: {
    'type': 'object',
    'properties': {
      'code': {
        'type': 'string',
        'description': 'Python source code to execute',
      },
    },
    'required': ['code'],
  },
);
```

## HostApi Per Surface

Each surface provides its own `HostApi` implementation. The wiring layer is
surface-agnostic — it receives `HostApi` and connects methods to host functions.

### Flutter

| HostApi Method | Implementation |
|----------------|----------------|
| `registerDataFrame` | Stores columns, returns handle for `DataTable` widget |
| `getDataFrame` | Retrieves stored columns by handle |
| `registerChart` | Stores chart config for `fl_chart` rendering |
| `invoke('ui.navigate', ...)` | GoRouter navigation |
| `invoke('native.clipboard', ...)` | `Clipboard.setData()` |
| `invoke('native.file_picker', ...)` | `file_picker` plugin |

### CLI (soliplex_cli)

| HostApi Method | Implementation |
|----------------|----------------|
| `registerDataFrame` | Stores columns, returns handle for ASCII table output |
| `getDataFrame` | Retrieves stored columns by handle |
| `registerChart` | Stores config for file-based chart export (SVG/PNG) |
| `invoke('native.clipboard', ...)` | `pbcopy`/`xclip` via `Process.run` |
| `invoke('native.file_picker', ...)` | stdin prompt for file path |

### TUI (soliplex_tui)

| HostApi Method | Implementation |
|----------------|----------------|
| `registerDataFrame` | Stores columns for nocterm table component |
| `getDataFrame` | Retrieves stored columns by handle |
| `registerChart` | Stores config for ASCII chart rendering |
| `invoke('native.clipboard', ...)` | `pbcopy`/`xclip` via `Process.run` |

## Execution Flow

```text
LLM generates tool_call: execute_python(code="...")
  │
  ▼
Backend yields ToolCallInfo via AG-UI SSE stream
  │
  ▼
RunOrchestrator transitions to ToolYieldingState
  │
  ▼
AgentSession._executeToolsAndResume()
  │
  ▼
ToolRegistry.execute(toolCall)
  │
  ▼
MontyToolExecutor.execute(toolCall)
  │
  ├── Extract code from toolCall.arguments["code"]
  │
  ├── BridgeCache.acquire(threadKey) → MontyBridge
  │     └── Creates new bridge if none cached for this thread
  │     └── LRU-evicts if at maxConcurrentBridges
  │
  ├── HostFunctionWiring.registerOnto(bridge)
  │     └── HostFunctionRegistry.addCategory("data", [...])
  │     └── HostFunctionRegistry.addCategory("chart", [...])
  │     └── HostFunctionRegistry.registerAllOnto(bridge)
  │
  ├── bridge.execute(code) → Stream<BridgeEvent>
  │     ├── BridgeRunStarted
  │     ├── BridgeStepStarted(stepId)
  │     ├── BridgeToolCallStart(callId, name)
  │     ├── BridgeToolCallArgs(callId, delta)
  │     ├── BridgeToolCallEnd(callId)
  │     │     └── HostFunction.handler(args) → result
  │     ├── BridgeToolCallResult(callId, result)
  │     ├── BridgeStepFinished(stepId)
  │     ├── BridgeTextStart(messageId)      ← print() output
  │     ├── BridgeTextContent(messageId, delta)
  │     ├── BridgeTextEnd(messageId)
  │     └── BridgeRunFinished
  │
  ├── _collectTextResult(events) → String
  │     └── Accumulates BridgeTextContent deltas + BridgeToolCallResult results
  │     └── Returns concatenated text or error message
  │
  └── BridgeCache.release(threadKey)

  │
  ▼
AgentSession returns ToolCallInfo.copyWith(
  status: ToolCallStatus.completed,
  result: "Python output text...",
)
  │
  ▼
RunOrchestrator.submitToolOutputs(executedTools)
  │
  ▼
Backend continuation run with tool results
```

## WASM Safety

### Spike Status

The WASM re-entrancy spike (`spike-wasm-reentrant-deadlock`) validated the
core assumptions:

- Scenario 1 (happy path): suspend/resume works on WASM.
- Scenario 2 (re-entrancy guard): `StateError` thrown on re-entry attempt.
- Scenario 3 (error recovery): `resumeWithError()` unwinds Python cleanly.

### Guard Mechanism

`PlatformConstraints.supportsReentrantInterpreter` is `false` on WASM.
`AgentRuntime._guardWasmReentrancy()` throws `StateError` when a session
spawn is attempted while another is active:

```dart
void _guardWasmReentrancy() {
  if (!_platform.supportsReentrantInterpreter && _activeCount > 0) {
    throw StateError('WASM runtime does not support concurrent sessions');
  }
}
```

### BridgeCache Interaction

`BridgeCache` enforces `maxConcurrentBridges`:

- **Native:** High limit (one Isolate per bridge). Parallel execution supported.
- **Web (WASM):** `maxConcurrentBridges = 1`. Single bridge, mutex-serialized.

When a second `acquire()` arrives and the limit is reached, `BridgeCache`
LRU-evicts an idle bridge. If all bridges are executing, it throws `StateError`
(caught by the agent session as a tool failure).

## Package Structure

```text
packages/soliplex_scripting/
  lib/
    soliplex_scripting.dart          # Barrel export
    src/
      scripting_tool_registry_resolver.dart
      monty_tool_executor.dart
      bridge_cache.dart
      host_function_wiring.dart
      ag_ui_bridge_adapter.dart
      python_executor_tool.dart      # const Tool definition
      host_schema_ag_ui.dart         # HostFunctionSchema.toAgUiTool() extension
  test/
    src/
      ag_ui_bridge_adapter_test.dart
      bridge_cache_test.dart
      monty_tool_executor_test.dart
      host_function_wiring_test.dart
      scripting_tool_registry_resolver_test.dart
  pubspec.yaml
  analysis_options.yaml
```

### pubspec.yaml

```yaml
name: soliplex_scripting
description: Wiring package connecting soliplex_agent with soliplex_interpreter_monty.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  ag_ui:
    git:
      url: https://github.com/soliplex/ag-ui.git
      path: sdks/community/dart
  meta: ^1.11.0
  soliplex_agent:
    path: ../soliplex_agent
  soliplex_interpreter_monty:
    path: ../soliplex_interpreter_monty

dev_dependencies:
  mocktail: ^1.0.4
  test: ^1.24.0
  very_good_analysis: ^10.0.0
```

## Future Runtimes

The `BridgeEvent` sealed hierarchy is runtime-agnostic. Any interpreter that
emits `Stream<BridgeEvent>` can plug into `soliplex_scripting` with a thin
adapter.

| Runtime | Package | Host Function API | Sandbox | Bridge Fit |
|---------|---------|-------------------|---------|------------|
| Python (Monty) | `dart_monty` | `register(HostFunction)` | resource limits | Primary |
| Dart | `d4rt` v0.2.2 | `BridgedClass` annotations | permissions system | Good |
| JavaScript | `js_interpreter` v0.0.2 | `setGlobal(name, fn)` | None | Excellent API fit |
| Hetu | `hetu_script` v0.4.2 | `externalFunctions` map | None | Good (stale) |

Each would get a `soliplex_interpreter_<name>` package emitting `BridgeEvent`,
with a thin adapter in `soliplex_scripting`. The `BridgeCache` and
`AgUiBridgeAdapter` are reusable across all runtimes.

Example: a d4rt interpreter would implement:

```dart
abstract class DartBridge {
  Stream<BridgeEvent> execute(String code);
  void dispose();
}
```

The wiring layer would provide a `DartToolExecutor` analogous to
`MontyToolExecutor`, registering `execute_dart` as a client-side tool.

## Open Questions

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | Streaming vs text-only tool result? | Text-only. `ToolExecutor` returns `Future<String>`. Streaming bridge events are available via `AgUiBridgeAdapter` for UIs that want real-time display, but the agent loop only needs the final text. |
| 2 | BridgeCache location? | `soliplex_scripting`. It's a wiring concern — the interpreter doesn't know about threads or caching, and the agent doesn't know about bridges. |
| 3 | Persistent Python sessions across runs? | Deferred. Currently each `execute_python` call is stateless. Session persistence (keeping variables between calls) requires bridge lifecycle changes and is not needed for v1. |
| 4 | Inter-agent bridge sharing? | Deferred. Each agent session gets its own bridge via `BridgeCache` keyed by `ThreadKey`. Sharing bridges between agents would require a coordination protocol. |
| 5 | `BridgeEvent` package location? | In `soliplex_interpreter_monty`. If a second interpreter is added, extract to a shared `soliplex_bridge_api` package. Premature to extract now. |

## Acceptance Criteria

- [ ] `soliplex_scripting` package exists at `packages/soliplex_scripting/`
- [ ] `soliplex_interpreter_monty` has no `ag_ui` dependency in `pubspec.yaml`
- [ ] `BridgeEvent` sealed hierarchy defined in interpreter package (12 subtypes)
- [ ] `DefaultMontyBridge.execute()` returns `Stream<BridgeEvent>`
- [ ] `HostFunctionSchema.toAgUiTool()` removed from interpreter; extension in
      scripting package
- [ ] `PythonExecutorTool` definition moved to scripting package
- [ ] `MontyBridge.toAgUiTools()` removed from interface
- [ ] `AgUiBridgeAdapter` maps all 12 BridgeEvent → BaseEvent (exhaustive switch)
- [ ] `ScriptingToolRegistryResolver` wraps inner resolver, appends
      `execute_python`
- [ ] `MontyToolExecutor` acquires bridge, registers functions, executes,
      returns text
- [ ] `BridgeCache` manages bridge lifecycle with LRU eviction respecting
      `maxConcurrentBridges`
- [ ] `HostFunctionWiring` connects `HostApi` methods to `HostFunctionRegistry`
      categories
- [ ] WASM guard: `BridgeCache` throws `StateError` when all bridges are
      executing and limit is reached
- [ ] `dart format .` produces no changes
- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] All tests pass
