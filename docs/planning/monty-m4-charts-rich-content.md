# M4: Charts + Rich Content in Chat

**Roadmap:** [monty-integration-roadmap.md](monty-integration-roadmap.md)
**Depends on:** M2 (DataFrame Engine)
**Benefits from:** M3 (Event Passthrough)

---

## Problem

Charting playground works standalone but charts can't render
inline in chat.

## Delivers

Python creates charts → they render as widgets in chat.

## New Files (in `packages/soliplex_monty/`)

| File | What |
|------|------|
| `lib/src/charting/chart_config.dart` | Immutable chart configuration |
| `lib/src/charting/chart_builder.dart` | Handle-based chart management — port from playground |
| `lib/src/functions/chart_functions.dart` | 11 chart_* host functions for `chart` category |
| `lib/src/widgets/chart_message_widget.dart` | Renders ChartConfig as inline Cristalyse widget |
| `lib/src/widgets/df_preview_widget.dart` | Renders DataFrame preview as data table |
| `test/src/charting/chart_builder_test.dart` | Tests |

## Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Per-thread ChartBuilder, `chart` category |
| `lib/features/chat/widgets/chat_message_widget.dart` | Detect structured JSON in ToolCallResult, route to chart/df widgets |

## Structured Payloads in ToolCallResult

```json
{"type": "chart", "chart_id": 1, "config": {...}}
{"type": "df_preview", "handle": 3, "columns": [...], "rows": [...]}
```

Chat widget checks for JSON with `"type"` key → routes to widget.
Falls back to code block.

## Done When

- Python: `chart_line(df, 'x', 'y')` renders chart inline in chat
- Python: `df_head(df)` renders data table inline
- Multiple charts in one execution all render
- Unknown structured types fall back to code blocks
- Works on both native and web
