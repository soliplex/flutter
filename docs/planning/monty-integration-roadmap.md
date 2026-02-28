# Monty-Flutter Integration Roadmap

## 4 Milestones — Keep It Simple

No RxDart. No stream resilience pipeline (premature — add if jank appears).
Focus on what's broken now and what unlocks the most value.

## Milestones

| Milestone | Title | Spec |
|-----------|-------|------|
| Prerequisites | Platform Fix | [monty-m0-platform-fix.md](monty-m0-platform-fix.md) |
| M1 | Host Function Registry + Introspection | [monty-m1-registry-introspection.md](monty-m1-registry-introspection.md) |
| M2 | DataFrame Engine + Wire-Up | [monty-m2-dataframe-engine.md](monty-m2-dataframe-engine.md) |
| M3 | AG-UI Event Passthrough | [monty-m3-agui-event-passthrough.md](monty-m3-agui-event-passthrough.md) |
| M4 | Charts + Rich Content in Chat | [monty-m4-charts-rich-content.md](monty-m4-charts-rich-content.md) |

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

## What We're Deliberately Deferring

| Thing | Why Not Now |
|-------|-----------|
| RxDart / stream resilience | No evidence of jank yet. See [backlog-stream-resilience.md](backlog-stream-resilience.md) |
| DataStore interface | `List<Map>` works fine for V1. Abstract when DuckDB becomes real |
| Widget Builder Registry | Simple switch/if in chat widget is fine until 3+ content types |
| MontyPlugin interface | Over-engineering for 2 categories |
| DfRegistry serialization | Not needed until session persistence is a feature |
| Isolate-based JSON parsing | Premature. Profile first, optimize if needed |
| Python namespacing via classes | Monty doesn't support classes or imports. Category prefix is sufficient. |
| Snapshot-primed interpreters | Both platforms support `MontySnapshotCapable`. Could pre-evaluate state. Explore later. |

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
