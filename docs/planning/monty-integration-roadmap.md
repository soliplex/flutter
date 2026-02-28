# Monty-Flutter Integration Roadmap

## 4 Milestones — Keep It Simple

No RxDart. No stream resilience pipeline (premature — add if jank appears).
Focus on what's broken now and what unlocks the most value.

---

## Prerequisites: Platform Fix

### Problem

`thread_bridge_cache.dart` line 3 imports `dart_monty_native` directly:

```dart
import 'package:dart_monty_native/dart_monty_native.dart';
```

This pulls in `dart:isolate` + `dart:ffi` which **breaks web/WASM compilation**.
The web compiler must resolve all imports — tree-shaking happens after.

### Fix

Use the conditional import pattern already in the codebase (`auth_flow.dart`,
`console_sink.dart`, `create_platform_client.dart`):

```text
lib/core/services/
  monty_platform_factory.dart        ← conditional export
  monty_platform_factory_native.dart ← MontyNative + NativeIsolateBindingsImpl
  monty_platform_factory_web.dart    ← MontyWasm + WasmBindingsJs + execution mutex
```

```dart
// monty_platform_factory.dart
import 'monty_platform_factory_native.dart'
    if (dart.library.js_interop) 'monty_platform_factory_web.dart'
    as impl;

MontyPlatform createMontyPlatform() => impl.createMontyPlatform();
```

### Web concurrency constraint

On native: one Isolate per thread → true parallel Python execution.
On web: all `MontyWasm` instances share `window.DartMontyBridge` singleton.
Dart on web is single-threaded, but interleaved async calls can corrupt state.

Fix: web factory returns platforms through a mutex/queue that serializes
execution across threads. `DefaultMontyBridge._isExecuting` already guards
single-bridge concurrency; the web mutex guards cross-bridge concurrency.

### Platform capabilities

dart_monty uses a capability model — callers check with `is` before invoking:

- `MontyNative` implements `MontySnapshotCapable` + `MontyFutureCapable`
- `MontyWasm` implements `MontySnapshotCapable` only (not `MontyFutureCapable`)

Python `async def` / `await` is only available on native. On web, the
capability check (`platform is MontyFutureCapable`) prevents those code paths.

This does NOT affect the roadmap: the `DefaultMontyBridge` start/resume loop
uses the synchronous external function pattern (`MontyPending`), not async
futures. The `MontyResolveFutures` case already has `TODO(M13)` and is a no-op.

Dart `HostFunction` handlers CAN do async work on both platforms — Python
pauses at the external function call, Dart awaits whatever it needs, then
calls `resume()`.

Both platforms implement `MontySnapshotCapable` — snapshot/restore works
everywhere. This could be used to prime interpreters with pre-evaluated state.

---

## M1: Host Function Registry + Introspection

**Problem**: Host functions registered inline with no structure. Python can't
discover what's available.

**Delivers**: Clean registry with categories. Python calls `list_functions()`
and `help('df_create')` to discover available host functions.

### Naming Convention

Category prefix IS the namespace. No Python classes, imports, or modules
(Monty doesn't support them). Functions are flat:

```text
Dart source                                                → Category → Python functions
packages/soliplex_monty/lib/src/functions/df_functions.dart → "df"     → df_create, df_head, df_shape, ...
packages/soliplex_monty/lib/src/functions/chart_functions.dart → "chart" → chart_line, chart_bar, ...
(room tools from backend)                                   → "tools"  → search_documents, ...
(navigation functions)                                      → "nav"    → navigate_to, switch_thread, ...
```

`list_functions()` returns results grouped by category:

```python
list_functions()
# → {"df": [{"name": "df_create", "description": "...", "params": [...]}],
#    "chart": [...], "tools": [...], "nav": [...]}
```

`help('df_create')` returns detailed param info for one function.

### New Files (in `packages/soliplex_monty/`)

| File | What |
|------|------|
| `lib/src/bridge/host_function_registry.dart` | `HostFunctionRegistry` — groups functions by category, bulk-registers onto bridge |
| `lib/src/bridge/introspection_functions.dart` | `list_functions()` + `help()` built from registry contents |
| `test/src/bridge/host_function_registry_test.dart` | Tests |
| `test/src/bridge/introspection_functions_test.dart` | Tests |

### New Files (platform fix)

| File | What |
|------|------|
| `lib/core/services/monty_platform_factory.dart` | Conditional export |
| `lib/core/services/monty_platform_factory_native.dart` | `MontyNative(bindings: NativeIsolateBindingsImpl())` |
| `lib/core/services/monty_platform_factory_web.dart` | `MontyWasm(bindings: WasmBindingsJs())` + mutex |

### Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Remove `dart_monty_native` import. Use `createMontyPlatform()`. Replace inline loop with `registry.addCategory(...)` + `registry.registerAllOnto(bridge)` |

### Design

- Pure Dart registry, no Flutter/Riverpod
- Reuses existing `HostFunctionSchema.toAgUiTool()` for introspection data
- `addCategory(String name, List<HostFunction> functions)`
- `registerAllOnto(MontyBridge bridge)` — registers all functions + introspection builtins
- `allFunctions` getter, `schemasByCategory` for introspection
- Introspection functions (`list_functions`, `help`) are self-referential:
  they appear in their own output

### Done When

- `flutter test packages/soliplex_monty/` passes
- App compiles on **both native and web**
- `list_functions()` returns categories with function metadata
- `help('search_documents')` returns param details with types and descriptions
- Flat function names work: `search_documents(query="x")`

---

## M2: DataFrame Engine + Wire-Up

**Problem**: Charting playground has a full DataFrame engine but it's not in
the Soliplex bridge.

**Delivers**: Python can create/manipulate DataFrames. Per-thread isolation.

### New Files (in `packages/soliplex_monty/`)

| File | What |
|------|------|
| `lib/src/data/data_frame.dart` | DataFrame class — port from playground |
| `lib/src/data/df_registry.dart` | Handle-based DataFrame storage — port from playground |
| `lib/src/functions/df_functions.dart` | 44 df_* host functions returning `List<HostFunction>` |
| `test/src/data/df_registry_test.dart` | Tests |
| `test/src/functions/df_functions_test.dart` | Tests |

### Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Per-thread `DfRegistry`, registered as `df` category |

### 44 Functions (from playground `dispatch.dart`)

- **Create** (3): df_create, df_from_csv, df_from_json
- **Inspect** (9): df_shape, df_columns, df_head, df_tail, df_describe, etc.
- **Transform** (13): df_select, df_filter, df_sort, df_group_agg, df_merge, etc.
- **Aggregate** (8): df_mean, df_sum, df_min, df_max, df_std, df_corr, etc.
- **Lifecycle** (2): df_dispose, df_dispose_all

### Design

- `List<Map<String, dynamic>>` data model (same as playground)
- Handle-based: Python gets integer IDs, not raw data
- Per-thread DfRegistry — disposed with bridge
- WASM note: `df_create` with large datasets pays JSON serialization tax
  across JS boundary. Encourage `df_from_csv(url)` so Dart does the heavy
  fetching directly into DfRegistry, giving Python only the lightweight handle.

### Done When

- Python: `df = df_create([{'x': 1, 'y': 2}])` returns handle
- Python: `df_head(df)` returns rows
- Different threads have independent DataFrames
- `list_functions()` shows `df` category with 44 functions
- Works on both native and web

---

## M3: AG-UI Event Passthrough

**Problem**: `execute_python` flattens the bridge event stream to a plain
string. All intermediate feedback (steps, tool calls, print output) is
discarded.

**Delivers**: Chat UI shows real-time Python execution feedback.

### New Files

| File | What |
|------|------|
| `packages/soliplex_client/lib/src/domain/tool_execution_observer.dart` | `ToolExecutionObserver` interface — `onToolEvent(toolCallId, BaseEvent)` |

### Modified

| File | Change |
|------|--------|
| `lib/core/providers/api_provider.dart` | execute_python executor forwards bridge events through observer via closure capture |
| `lib/core/providers/active_run_notifier.dart` | Provides observer in `_executeToolsAndContinue`. Maps sub-events to state updates |
| `lib/features/chat/widgets/status_indicator.dart` | Shows Python step names during execution |

### Design

- Observer is **opt-in** — `ClientTool.executor` signature unchanged
- Passed via **closure capture** (not Zone values — those are fragile)
- execute_python still returns `Future<String>` for the LLM
- If jank appears from rapid events, add frame batching then (not now)
- No platform-specific code needed — pure Dart + Flutter

### Done When

- Status shows "Running Python... calling search_documents..."
- Print output streams during execution (not batched until end)
- Tool call results visible as they complete

---

## M4: Charts + Rich Content in Chat

**Problem**: Charting playground works standalone but charts can't render
inline in chat.

**Delivers**: Python creates charts → they render as widgets in chat.

### New Files (in `packages/soliplex_monty/`)

| File | What |
|------|------|
| `lib/src/charting/chart_config.dart` | Immutable chart configuration |
| `lib/src/charting/chart_builder.dart` | Handle-based chart management — port from playground |
| `lib/src/functions/chart_functions.dart` | 11 chart_* host functions for `chart` category |
| `lib/src/widgets/chart_message_widget.dart` | Renders ChartConfig as inline Cristalyse widget |
| `lib/src/widgets/df_preview_widget.dart` | Renders DataFrame preview as data table |
| `test/src/charting/chart_builder_test.dart` | Tests |

### Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Per-thread ChartBuilder, `chart` category |
| `lib/features/chat/widgets/chat_message_widget.dart` | Detect structured JSON in ToolCallResult, route to chart/df widgets |

### Structured Payloads in ToolCallResult

```json
{"type": "chart", "chart_id": 1, "config": {...}}
{"type": "df_preview", "handle": 3, "columns": [...], "rows": [...]}
```

Chat widget checks for JSON with `"type"` key → routes to widget.
Falls back to code block.

### Done When

- Python: `chart_line(df, 'x', 'y')` renders chart inline in chat
- Python: `df_head(df)` renders data table inline
- Multiple charts in one execution all render
- Unknown structured types fall back to code blocks
- Works on both native and web

---

## Dependency Graph

```text
Platform Fix (prerequisite)
    │
    v
M1 (Registry + Introspection) ──┐
                                  ├──→ M2 (DataFrame) ──→ M4 (Charts + Rich UI)
                                  │
                                  └──→ M3 (Event Passthrough)
```

| Order | Milestone | Can Parallelize? |
|-------|-----------|-----------------|
| First | **Platform Fix + M1** | Start here — platform fix is prerequisite |
| Second | **M2 + M3** | Yes, parallel — M2 is pure Dart, M3 is UI plumbing |
| Third | **M4** | Needs M2 (DataFrames) + benefits from M3 (event streaming) |

---

## Cross-Platform Summary

| Aspect | Native | Web WASM |
|--------|--------|----------|
| Python runtime | Rust FFI (.dylib/.so/.dll) | WASM in Web Worker |
| Threads | One Isolate per thread (parallel) | Shared singleton (serialized via mutex) |
| Capabilities | `MontySnapshotCapable` + `MontyFutureCapable` | `MontySnapshotCapable` only |
| Dart async handlers | Work fine | Work fine |
| JSON tax | None (sealed classes via SendPort) | Every call crosses JS boundary as JSON |
| Large data mitigation | N/A | Use `df_from_csv(url)` instead of `df_create(huge_list)` |
| Bridge loop | `start()` → `resume()` works | `start()` → `resume()` works |

---

## What We're Deliberately Deferring

| Thing | Why Not Now |
|-------|-----------|
| RxDart / stream resilience | No evidence of jank yet. See `backlog-stream-resilience.md` |
| DataStore interface | `List<Map>` works fine for V1. Abstract when DuckDB becomes real |
| Widget Builder Registry | Simple switch/if in chat widget is fine until 3+ content types |
| MontyPlugin interface | Over-engineering for 2 categories |
| DfRegistry serialization | Not needed until session persistence is a feature |
| Isolate-based JSON parsing | Premature. Profile first, optimize if needed |
| Python namespacing via classes | Monty doesn't support classes or imports. Category prefix is sufficient. |
| Snapshot-primed interpreters | Both platforms support `MontySnapshotCapable`. Could pre-evaluate state. Explore later. |

---

## Files Reference

| File | Role |
|------|------|
| `packages/soliplex_monty/lib/src/bridge/default_monty_bridge.dart` | Core bridge loop, event emission, preamble injection |
| `packages/soliplex_monty/lib/src/bridge/host_function.dart` | HostFunction = schema + handler |
| `packages/soliplex_monty/lib/src/bridge/host_function_schema.dart` | Typed params + validation |
| `packages/soliplex_monty/lib/src/bridge/tool_definition_converter.dart` | Backend tool defs → HostFunctionSchema |
| `lib/core/services/thread_bridge_cache.dart` | Per-thread bridge lifecycle |
| `lib/core/providers/api_provider.dart` | execute_python executor |
| `lib/core/providers/active_run_notifier.dart` | AG-UI orchestration, SSE streaming |
| `lib/features/chat/widgets/chat_message_widget.dart` | Message rendering |
| `lib/features/chat/widgets/status_indicator.dart` | Execution status display |
| `dart_monty/example/charting_playground/lib/dispatch.dart` | Reference: 67 functions |
| `dart_monty/example/charting_playground/lib/df_registry.dart` | Reference: DataFrame engine |
| `dart_monty/example/charting_playground/lib/chart_builder.dart` | Reference: Chart rendering |
