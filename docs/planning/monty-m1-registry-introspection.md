# M1: Host Function Registry + Introspection

**Roadmap:** [monty-integration-roadmap.md](monty-integration-roadmap.md)
**Depends on:** M0 (Platform Fix)
**Blocks:** M2, M3, M4

---

## Problem

Host functions registered inline with no structure. Python can't
discover what's available.

## Delivers

Clean registry with categories. Python calls `list_functions()`
and `help('df_create')` to discover available host functions.

## Naming Convention

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
# → {"tools": {"df": [{"name": "df_create", "description": "...", "params": [...]}],
#              "chart": [...], "tools": [...], "nav": [...],
#              "introspection": [...]}}
```

`help('df_create')` returns detailed param info for one function.

## New Files (in `packages/soliplex_monty/`)

| File | What |
|------|------|
| `lib/src/bridge/host_function_registry.dart` | `HostFunctionRegistry` — groups functions by category, bulk-registers onto bridge |
| `lib/src/bridge/introspection_functions.dart` | `list_functions()` + `help()` built from registry contents |
| `test/src/bridge/host_function_registry_test.dart` | Tests |
| `test/src/bridge/introspection_functions_test.dart` | Tests |

## Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Replace inline loop with `registry.addCategory(...)` + `registry.registerAllOnto(bridge)` |

## Design

- Pure Dart registry, no Flutter/Riverpod
- Custom serializers for introspection JSON (lighter than `toAgUiTool()`)
- `addCategory(String name, List<HostFunction> functions)`
- `registerAllOnto(MontyBridge bridge)` — registers all functions + introspection builtins
- `allFunctions` getter, `schemasByCategory` for introspection
- Introspection functions (`list_functions`, `help`) are self-referential:
  they appear in their own output

## Done When

- `flutter test packages/soliplex_monty/` passes
- App compiles on **both native and web**
- `list_functions()` returns categories with function metadata
- `help('search_documents')` returns param details with types and descriptions
- Flat function names work: `search_documents(query="x")`
