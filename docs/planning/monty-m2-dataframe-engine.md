# M2: DataFrame Engine + Wire-Up

**Roadmap:** [monty-integration-roadmap.md](monty-integration-roadmap.md)
**Depends on:** M1 (Registry + Introspection)
**Blocks:** M4 (Charts + Rich Content)
**Can parallelize with:** M3

---

## Problem

Charting playground has a full DataFrame engine but it's not in
the Soliplex bridge.

## Delivers

Python can create/manipulate DataFrames. Per-thread isolation.

## New Files (in `packages/soliplex_monty/`)

| File | What |
|------|------|
| `lib/src/data/data_frame.dart` | DataFrame class — port from playground |
| `lib/src/data/df_registry.dart` | Handle-based DataFrame storage — port from playground |
| `lib/src/functions/df_functions.dart` | 44 df_* host functions returning `List<HostFunction>` |
| `test/src/data/df_registry_test.dart` | Tests |
| `test/src/functions/df_functions_test.dart` | Tests |

## Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Per-thread `DfRegistry`, registered as `df` category |

## 44 Functions (from playground `dispatch.dart`)

- **Create** (3): df_create, df_from_csv, df_from_json
- **Inspect** (9): df_shape, df_columns, df_head, df_tail, df_describe, etc.
- **Transform** (13): df_select, df_filter, df_sort, df_group_agg, df_merge, etc.
- **Aggregate** (8): df_mean, df_sum, df_min, df_max, df_std, df_corr, etc.
- **Lifecycle** (2): df_dispose, df_dispose_all

## Design

- `List<Map<String, dynamic>>` data model (same as playground)
- Handle-based: Python gets integer IDs, not raw data
- Per-thread DfRegistry — disposed with bridge
- WASM note: `df_create` with large datasets pays JSON serialization tax
  across JS boundary. Encourage `df_from_csv(url)` so Dart does the heavy
  fetching directly into DfRegistry, giving Python only the lightweight handle.

## Done When

- Python: `df = df_create([{'x': 1, 'y': 2}])` returns handle
- Python: `df_head(df)` returns rows
- Different threads have independent DataFrames
- `list_functions()` shows `df` category with 44 functions
- Works on both native and web
