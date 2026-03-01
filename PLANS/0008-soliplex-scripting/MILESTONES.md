# Milestones: soliplex_scripting

Four milestones implementing the `soliplex_scripting` wiring package per
[SPEC.md](SPEC.md). Each milestone is self-contained: tests pass, analyze
clean, DCM strict config passes at exit.

Commit messages use `(M<N>)` tags for `tool/milestone_review.sh` auto-detection.

---

## M1: BridgeEvent hierarchy + interpreter decoupling

Decouple `soliplex_interpreter_monty` from `ag_ui` by introducing a
protocol-agnostic `BridgeEvent` sealed hierarchy.

### Deliverables

- `BridgeEvent` sealed class with 12 subtypes in
  `soliplex_interpreter_monty/lib/src/bridge/bridge_event.dart`
- Refactor `DefaultMontyBridge.execute()` to return `Stream<BridgeEvent>`
  (was `Stream<BaseEvent>`)
- Remove `HostFunctionSchema.toAgUiTool()` from interpreter
- Remove `MontyBridge.toAgUiTools()` from interface
- Remove `ag_ui` from `soliplex_interpreter_monty/pubspec.yaml`
- Update existing interpreter tests to use `BridgeEvent` types

### Exit criteria

- `dart analyze --fatal-infos` clean for `soliplex_interpreter_monty`
- `dart test` passes in `soliplex_interpreter_monty`
- `ag_ui` absent from interpreter's `pubspec.yaml`
- No `import 'package:ag_ui` in any interpreter source file

---

## M2: Package scaffold + AgUiBridgeAdapter + tool definition

Create the `soliplex_scripting` package and implement the stateless mapping
layer that bridges `BridgeEvent` back to ag-ui types.

### Deliverables

- `packages/soliplex_scripting/` scaffold: `pubspec.yaml`,
  `analysis_options.yaml`, barrel export
- `AgUiBridgeAdapter` — exhaustive `switch` mapping all 12
  `BridgeEvent` → `BaseEvent` (see SPEC section 4b)
- `pythonExecutorToolDefinition` — `const Tool(...)` moved from interpreter
- `HostSchemaAgUi` extension — `toAgUiTool()` on `HostFunctionSchema`
- Unit tests: `ag_ui_bridge_adapter_test.dart`, extension test

### Exit criteria

- `dart analyze --fatal-infos` clean for `soliplex_scripting`
- `dart test` passes in `soliplex_scripting`
- `soliplex_scripting` has no Flutter imports (pure Dart)
- DCM strict config (`PLANS/0008-soliplex-scripting/dcm_options.yaml`) passes

---

## M3: BridgeCache + WASM guard

Implement bridge lifecycle management with LRU eviction and WASM safety.

### Deliverables

- `BridgeCache` — `Map<ThreadKey, MontyBridge>` keyed by conversation thread
  - Lazy creation on first `acquire()`
  - LRU eviction when `PlatformConstraints.maxConcurrentBridges` reached
  - Execution tracking (prevent concurrent execution on same bridge)
  - `StateError` when all bridges executing and limit reached (WASM guard)
  - `acquire()`, `release()`, `evict()`, `disposeAll()`
- Unit tests: `bridge_cache_test.dart`
  - Acquire/release round-trip
  - LRU eviction fires on limit
  - StateError on full-capacity concurrent execution
  - disposeAll cleans all bridges

### Exit criteria

- `dart test` passes in `soliplex_scripting`
- DCM strict config passes
- WASM guard test covers the `StateError` path

---

## M4: Wiring + executor + resolver + integration

Wire everything together: host functions, tool executor, and registry
resolver. Verify all acceptance criteria from SPEC.

### Deliverables

- `HostFunctionWiring` — connects `HostApi` methods to
  `HostFunctionRegistry` categories (data, chart, platform)
- `MontyToolExecutor` — extract code from `ToolCallInfo`, acquire bridge,
  register host functions, execute, collect text result
- `ScriptingToolRegistryResolver` — wraps inner `ToolRegistryResolver`,
  appends `execute_python` `ClientTool`
- Unit tests: `host_function_wiring_test.dart`,
  `monty_tool_executor_test.dart`,
  `scripting_tool_registry_resolver_test.dart`
- Integration test: tool call → bridge → host function → result

### Exit criteria

- All 16 acceptance criteria from SPEC verified
- `dart format .` produces no changes
- `dart analyze --fatal-infos` clean across all packages
- `dart test` passes across all packages
- DCM strict config passes for `soliplex_scripting`
