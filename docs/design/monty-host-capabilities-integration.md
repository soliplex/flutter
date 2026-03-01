# Monty HostApi Integration Guide

## Purpose

This document specifies how `soliplex_interpreter_monty` integrates with `soliplex_agent`
via the `HostApi` interface and direct `ToolRegistry` injection. It covers
the call flow, dependency wiring, and platform constraint discrimination.

There is no `MontyHostApi` subclass — `HostApi` is the single interface
for all host operations. Tool execution goes through a directly injected
`ToolRegistry`, not through the host interface.

**Audience:** Implementer of the Monty bridge rewire (Phase 4 of
soliplex_agent plan).

**Prerequisite branches:**

- `feat/monty-bridge-charting` — current Monty integration (baseline)
- `soliplex_agent` Phase 1 — package skeleton with `HostApi` interface

## Current Architecture (charting branch)

```text
Python code
  │
  ▼
MontyPlatform (start/resume loop)
  │  MontyPending(functionName, args)
  ▼
DefaultMontyBridge._handlePending()
  │  looks up HostFunction by name
  ▼
HostFunction.handler(validatedArgs)
  │  closure captures ref.read(toolRegistryProvider)
  ▼
ToolRegistry.execute(toolCall) ──► backend or local tool
```

The problem: `HostFunction` handlers are closures that capture Riverpod `ref`.
This couples `soliplex_interpreter_monty` to Flutter at the wiring layer
(`ThreadBridgeCacheNotifier.getOrCreate`).

### Monty Language Limitations

The Monty runtime supports a **restricted subset of Python**: no
`import` statements, no `class` definitions. LLM-generated scripts are
flat procedural code — control flow, variables, dicts, lists, and
registered host functions only.

This means **every capability** the script needs must be a registered
`HostFunction` on the bridge. The LLM cannot import helpers or define
reusable types. All orchestration primitives (`spawn_agent`, `wait_all`,
`df_create`, etc.) are host functions, not Python library calls.

See `docs/design/agent-runtime-vision.md` § "Monty Language Limitations"
for full details and design implications.

## Target Architecture

```text
Python code
  │
  ▼
MontyPlatform (start/resume loop)
  │  MontyPending(functionName, args)
  ▼
DefaultMontyBridge._handlePending()
  │  looks up HostFunction by name
  ▼
HostFunction.handler(validatedArgs)
  │  tool calls → injected ToolRegistry.execute()
  │  df/chart   → injected HostApi.registerDataFrame() etc.
  │  platform   → injected HostApi.invoke()
  ▼
ToolRegistry (pure Dart, from soliplex_client)
HostApi (interface defined in soliplex_agent, implemented by Flutter)
```

## Call Flow: End-to-End Examples

### Python calls `search_documents(query="WASM support")`

```text
1. Python:  search_documents(query="WASM support")

2. MontyPlatform suspends Python, returns:
   MontyPending(
     functionName: "search_documents",
     arguments: ["WASM support"],
     kwargs: null,
   )

3. DefaultMontyBridge._handlePending():
   - Looks up HostFunction for "search_documents"
   - Calls fn.schema.mapAndValidate(pending)
     → {"query": "WASM support"}
   - Emits StepStartedEvent, ToolCallStartEvent, ToolCallArgsEvent

4. HostFunction.handler({"query": "WASM support"}):
   → calls toolRegistry.execute(ToolCallInfo(
       name: "soliplex.tools.search_documents",
       arguments: '{"query": "WASM support"}',
     ))

5. ToolRegistry.execute():
   (pure Dart, constructed by Flutter with executor closures)
   → HTTP call to backend or local execution
   → returns "Found 3 documents matching..."

6. DefaultMontyBridge resumes:
   - Emits ToolCallResultEvent, StepFinishedEvent
   - platform.resume("Found 3 documents matching...")

7. Python receives return value, continues execution.
```

### Python calls `df_create([...])`

```text
1. Python:  h = df_create([{"name": "Alice", "age": 30}])

2. MontyPlatform suspends, returns MontyPending

3. DefaultMontyBridge dispatches to df_create handler

4. Handler calls:
   hostApi.registerDataFrame({"name": ["Alice"], "age": [30]})
   → Flutter's _FlutterHostApi stores in DfRegistry
   → returns handle ID (1)

5. Bridge resumes Python with handle 1
   → Python now has h = 1

6. Python:  df_head(h)
   → handler calls hostApi.getDataFrame(1)
   → returns column map
   → formats as string, resumes Python
```

## Dependency Graph

```text
soliplex_interpreter_monty ──depends──► soliplex_agent  (for HostApi, PlatformConstraints)
soliplex_agent ──depends──► soliplex_client (for domain models, ToolRegistry)
Flutter app    ──depends──► soliplex_interpreter_monty, soliplex_agent

soliplex_interpreter_monty does NOT depend on Flutter (already true on charting branch,
except for widgets/ which stay in soliplex_interpreter_monty or move to the app).
```

**Important:** `soliplex_interpreter_monty` gains a dependency on `soliplex_agent`
*only* for `HostApi` and `PlatformConstraints`. It does not import
`RunOrchestrator`, `ThreadHistoryCache`, or any other agent internals.

## Platform Capabilities

### The WASM Constraint

Monty on WASM supports **synchronous execution only**. The start/resume loop
is synchronous from Python's perspective — when Python calls an external
function, the interpreter suspends and Dart gets a `MontyPending`. Dart runs
the handler (which may be async), then calls `platform.resume(result)`.

The `MontyResolveFutures` progress state exists in `MontyPlatform` but is
**not implemented on WASM**. This means:

- Python cannot `await` a Dart future
- All host function results must be available when `resume()` is called
- Long-running async operations (HTTP fetches, file I/O) work because Dart's
  event loop runs while Python is suspended — but Python sees them as
  synchronous calls

On **native** (Isolate-backed), async/futures support is potentially possible
in the future (`MontyResolveFutures`), and each bridge runs in its own Isolate
(true parallelism).

### PlatformConstraints Interface

Defined in `soliplex_agent` — see
[`soliplex-agent-package.md`](soliplex-agent-package.md) § "PlatformConstraints"
for the full interface. Key flags consumed by the Monty layer:

- `supportsParallelExecution` — native true, WASM false
- `supportsAsyncMode` — false everywhere until `MontyResolveFutures`
- `maxConcurrentBridges` — native unbounded, WASM 1
- `supportsReentrantInterpreter` — native true, WASM false

`PlatformConstraints` is separate from `HostApi` — it's global
(per app instance), not per-session.

### Where Platform Detection Happens

The Flutter app provides the implementation at startup:

```dart
// In the Flutter app (not in soliplex_agent or soliplex_interpreter_monty)

class NativePlatformConstraints implements PlatformConstraints {
  @override
  bool get supportsParallelExecution => true;
  @override
  bool get supportsAsyncMode => false; // Until MontyResolveFutures lands
  @override
  int get maxConcurrentBridges => 256; // Practical limit
  @override
  bool get supportsReentrantInterpreter => true;
}

class WebPlatformConstraints implements PlatformConstraints {
  @override
  bool get supportsParallelExecution => false;
  @override
  bool get supportsAsyncMode => false;
  @override
  int get maxConcurrentBridges => 1;
  @override
  bool get supportsReentrantInterpreter => false;
}
```

Selected via the existing conditional import pattern
(`if (dart.library.js_interop)`).

### How Monty Uses PlatformConstraints

`DefaultMontyBridge` does **not** need this directly — it already has
`_isExecuting` to guard single-bridge concurrency. The cross-bridge mutex
on web is handled by `_MutexGuardedPlatform`.

`PlatformConstraints` is consumed by:

1. **ThreadBridgeCache** — decides whether to eagerly pre-warm bridges
   (native) or defer creation (web, to avoid mutex contention).
2. **RunOrchestrator** — knows whether tool execution can run in parallel
   with other bridges or must wait.
3. **Future: MontyResolveFutures handler** — skips async dispatch on web,
   resumes with error explaining the limitation.

## How Monty Uses HostApi + ToolRegistry

`HostApi` is defined in `soliplex_agent` — see
[`soliplex-agent-package.md`](soliplex-agent-package.md) § "HostApi"
for the full interface. The bridge uses it for DataFrame/chart
registration and platform service dispatch (`invoke()`).

### Tool Dispatch: Direct ToolRegistry Injection

Tool execution does **not** go through `HostApi`. The bridge receives
a `ToolRegistry` directly (constructed by Flutter with whatever closures
it needs baked in). The bridge calls `registry.execute(toolCall)`.

```dart
// Bridge receives ToolRegistry + HostApi as separate concerns
class DefaultMontyBridge implements MontyBridge {
  DefaultMontyBridge({
    required ToolRegistry toolRegistry,
    required HostApi hostApi,
    MontyPlatform? platform,
  });
}
```

Tool host functions delegate to the injected registry:

```dart
HostFunction(
  schema: mapping.schema,
  handler: (args) {
    final toolCall = ToolCallInfo(
      id: 'monty_${mapping.pythonName}_${timestamp}',
      name: mapping.registryName,
      arguments: jsonEncode(args),
    );
    return toolRegistry.execute(toolCall);
  },
)
```

The registry IS the tool dispatch interface — no wrapper needed.
Some executors may internally capture Riverpod `ref` (for dialogs,
navigation, etc.), but that's opaque to the bridge.

## Rewiring: ThreadBridgeCacheNotifier → ToolRegistry + HostApi

### Current (charting branch)

`ThreadBridgeCacheNotifier.getOrCreate` builds handler closures that capture
`ref`:

```dart
// Current: closure captures Riverpod ref
handler: (args) async {
  final registry = ref.read(toolRegistryProvider);
  final toolCall = ToolCallInfo(
    id: 'monty_${mapping.pythonName}_${timestamp}',
    name: mapping.registryName,
    arguments: jsonEncode(args),
  );
  return registry.execute(toolCall);
},
```

### Target

`DefaultMontyBridge` receives `ToolRegistry` and `HostApi` as separate
constructor parameters. Tool calls go directly to the registry. DataFrame,
chart, and platform operations go through `HostApi`.

```dart
// Target: two separate concerns injected
class DefaultMontyBridge implements MontyBridge {
  DefaultMontyBridge({
    required ToolRegistry toolRegistry,
    required HostApi hostApi,
    required PlatformConstraints platform,
    MontyPlatform? montyPlatform,
    MontyLimits? limits,
  }) : _toolRegistry = toolRegistry,
       _hostApi = hostApi,
       _platform = platform,
       _explicitPlatform = montyPlatform,
       _limits = limits;

  final ToolRegistry _toolRegistry;
  final HostApi _hostApi;
  final PlatformConstraints _platform;
  // ... rest unchanged
}
```

Tool host functions delegate to the injected registry (no interface
wrapper, no `executeTool`):

```dart
HostFunction(
  schema: mapping.schema,
  handler: (args) {
    final toolCall = ToolCallInfo(
      id: 'monty_${mapping.registryName}_$timestamp',
      name: mapping.registryName,
      arguments: jsonEncode(args),
    );
    return _toolRegistry.execute(toolCall);
  },
)
```

DataFrame functions call `hostApi.registerDataFrame()` /
`hostApi.getDataFrame()` instead of a closure-captured `DfRegistry`:

```dart
// Current: DfRegistry is a local object
final dfRegistry = DfRegistry();
buildDfFunctions(dfRegistry);

// Target: delegate to HostApi
HostFunction(
  schema: dfCreateSchema,
  handler: (args) async {
    final data = args['data'] as List<Map<String, Object?>>;
    return hostApi.registerDataFrame(_columnarize(data));
  },
)
```

### Flutter Implementation

```dart
// In the Flutter app — private class, not exported

class _FlutterHostApi implements HostApi {
  _FlutterHostApi(this._ref);

  final Ref _ref;
  final _dfRegistry = DfRegistry();     // Per-instance isolation
  final _chartHandles = <int, Map<String, Object?>>{};
  int _nextChartId = 1;

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) =>
      _dfRegistry.create(DataFrame.fromColumns(columns));

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) =>
      _dfRegistry.get(handle)?.toColumns();

  @override
  int registerChart(Map<String, Object?> chartConfig) {
    final id = _nextChartId++;
    _chartHandles[id] = chartConfig;
    // Notify UI via Riverpod state update
    return id;
  }

  @override
  Future<Object?> invoke(
    String name,
    Map<String, Object?> args,
  ) async {
    return switch (name) {
      'native.location' => _handleLocation(args),
      'native.clipboard' => _handleClipboard(args),
      'native.file_picker' => _handleFilePicker(args),
      _ => throw UnimplementedError('Unknown host operation: $name'),
    };
  }
}
```

### ThreadBridgeCache After Rewire

```dart
class ThreadBridgeCacheNotifier extends Notifier<ThreadBridgeCacheState> {
  // ...

  MontyBridge getOrCreate(ThreadKey key, List<ToolNameMapping> mappings) {
    final existing = bridges[key];
    if (existing != null) return existing;

    final toolRegistry = ref.read(toolRegistryProvider);
    final hostApi = _FlutterHostApi(ref);
    final platformConstraints = ref.read(platformConstraintsProvider);
    final montyPlatform = createMontyPlatform();

    final bridge = DefaultMontyBridge(
      toolRegistry: toolRegistry,
      hostApi: hostApi,
      platform: platformConstraints,
      montyPlatform: montyPlatform,
    );

    // Host functions registered with direct references — no closure capture
    final funcRegistry = HostFunctionRegistry()
      ..addCategory('tools', _buildToolFunctions(mappings, toolRegistry))
      ..addCategory('df', buildDfFunctions(hostApi));
    funcRegistry.registerAllOnto(bridge);

    bridges[key] = bridge;
    state = Map.of(bridges);
    return bridge;
  }
}
```

## HostFunctionRegistry Integration

The `HostFunctionRegistry` (currently in `soliplex_interpreter_monty`) doesn't change
structurally. What changes is **how handlers are built**:

### Current: Handlers capture closures

```dart
HostFunctionRegistry()
  ..addCategory('tools', [
    for (final m in mappings)
      HostFunction(
        schema: m.schema,
        handler: (args) async {
          final reg = ref.read(toolRegistryProvider);  // ← Riverpod
          return reg.execute(ToolCallInfo(...));
        },
      ),
  ])
  ..addCategory('df', buildDfFunctions(dfRegistry))  // ← local DfRegistry
```

### Target: Handlers use injected ToolRegistry + HostApi

```dart
HostFunctionRegistry()
  ..addCategory('tools', [
    for (final m in mappings)
      HostFunction(
        schema: m.schema,
        handler: (args) {
          final toolCall = ToolCallInfo(
            id: 'monty_${m.registryName}_$timestamp',
            name: m.registryName,
            arguments: jsonEncode(args),
          );
          return toolRegistry.execute(toolCall);  // ← direct injection
        },
      ),
  ])
  ..addCategory('df', buildDfFunctions(hostApi))  // ← via HostApi
```

`buildDfFunctions` changes signature from `(DfRegistry)` to
`(HostApi)` — it calls `registerDataFrame` / `getDataFrame`
instead of directly mutating a `DfRegistry`.

## What Moves Where

| Component | Current Location | Target | Change |
|-----------|-----------------|--------|--------|
| `HostApi` | N/A | `soliplex_agent` | New interface |
| `PlatformConstraints` | N/A | `soliplex_agent` | New interface |
| `MontyBridge` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | No change |
| `DefaultMontyBridge` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | Add `toolRegistry` + `hostApi` params |
| `HostFunction` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | No change |
| `HostFunctionSchema` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | No change |
| `HostFunctionRegistry` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | No change (or move to agent) |
| `DfRegistry` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | Used only by Flutter impl |
| `buildDfFunctions` | `soliplex_interpreter_monty` | `soliplex_interpreter_monty` | Signature: `(DfRegistry)` → `(HostApi)` |
| `ThreadBridgeCacheNotifier` | Flutter app | Flutter app | Injects `ToolRegistry` + `HostApi` |
| `_FlutterHostApi` | N/A | Flutter app | New private class implementing `HostApi` |
| Platform factories | Flutter app | Flutter app | No change |
| `_MutexGuardedPlatform` | Flutter app | Flutter app | No change |

## Open Questions for Implementer

1. **Should `DfRegistry` move into `soliplex_agent`?**
   Currently it's a detail of `soliplex_interpreter_monty`. Since `HostApi`
   defines `registerDataFrame`/`getDataFrame`, the Flutter impl can use
   `DfRegistry` internally. `soliplex_interpreter_monty`'s `buildDfFunctions` just needs
   the `HostApi` interface. Recommend: keep `DfRegistry` in `soliplex_interpreter_monty`,
   used only by the Flutter implementation class.

2. **Should `HostFunctionRegistry` move to `soliplex_agent`?**
   It's a utility for grouping and registering functions onto a bridge.
   It has no Riverpod dependency. Could live in either package. Recommend:
   keep in `soliplex_interpreter_monty` — it's specific to the Monty bridge pattern.

3. **Chart rendering pipeline.**
   `registerChart` returns a handle. How does the UI know to render it?
   Options: (a) Structured JSON in `ToolCallResult` content, detected by
   chat widget. (b) Side-channel via Riverpod state notification. (c)
   `onChartRegistered` callback in `HostApi`. Recommend: (a)
   — keep it in the ag-ui event stream, same as current charting plan in
   `monty-m4-charts-rich-content.md`.

4. **WASM async mode — when `MontyResolveFutures` lands.**
   The `PlatformConstraints.supportsAsyncMode` flag is `false` everywhere
   today. When native async lands, the bridge needs a code path in
   `_run()` to handle `MontyResolveFutures` — dispatch pending futures
   via Dart's event loop and resume. The current `TODO(M13)` comment marks
   this location. The interface is ready; the implementation is deferred.

5. **Widget files in `soliplex_interpreter_monty`.**
   `console_output_view.dart` and `python_run_button.dart` import Flutter.
   They should either (a) move to the Flutter app's `shared/widgets/`, or
   (b) stay in `soliplex_interpreter_monty` with `soliplex_interpreter_monty` keeping its Flutter
   dependency for the widget layer only. Recommend: (b) for now — the
   widgets are tightly coupled to Monty console events.

## Testing Strategy

### Unit Tests in `soliplex_interpreter_monty`

`DefaultMontyBridge` tests use mock `ToolRegistry` + `HostApi`:

```dart
class MockToolRegistry extends Mock implements ToolRegistry {}
class MockHostApi extends Mock implements HostApi {}

test('dispatches tool call through injected registry', () async {
  final toolRegistry = MockToolRegistry();
  final hostApi = MockHostApi();
  when(() => toolRegistry.execute(any()))
      .thenAnswer((_) async => 'result');

  final bridge = DefaultMontyBridge(
    toolRegistry: toolRegistry,
    hostApi: hostApi,
    platform: NativePlatformConstraints(),
    montyPlatform: MockMontyPlatform(),
  );
  // ... register function, execute, verify
});
```

### Integration Tests in Flutter App

`_FlutterHostApi` is tested via the existing `ThreadBridgeCacheNotifier`
tests, which use `pumpWithProviders` and real Riverpod wiring.

### Platform Capability Tests

Separate test files for each platform implementation, verifying the
correct flags are set. These are compile-time conditional — native tests
run on native, web tests run on web (or both via `flutter test --platform`).
