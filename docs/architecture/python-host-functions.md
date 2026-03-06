# Python Host Function Inventory

Complete inventory of Dart functions callable from Python scripts via the
Monty interpreter bridge. Functions are organized by category and source
package.

## Summary

| Category | Count | Package |
|----------|------:|---------|
| DataFrame | 37 | soliplex\_scripting |
| Chart | 2 | soliplex\_scripting |
| Form | 2 | soliplex\_scripting |
| Platform | 4 | soliplex\_scripting |
| Streams | 3 | soliplex\_scripting |
| Blackboard | 3 | soliplex\_scripting |
| Agent | 7 | soliplex\_scripting |
| Isolate | 5 | dart\_monty\_bridge |
| Event Loop | 2 | dart\_monty\_bridge |
| Introspection | 2 | dart\_monty\_bridge |
| **Total** | **67** | |

## DataFrame (`df_*`)

Data manipulation functions backed by `soliplex_dataframe`. All operate on
integer handles returned by `df_create`.

| Function | Params | Description |
|----------|--------|-------------|
| `df_create` | `data: list`, `columns?: list` | Create a DataFrame from row maps or list-of-lists with column names |
| `df_from_csv` | `csv: string` | Parse CSV text into a DataFrame |
| `df_from_json` | `json: string` | Parse JSON text into a DataFrame |
| `df_shape` | `handle: int` | Return `[rows, cols]` |
| `df_columns` | `handle: int` | Return column names |
| `df_head` | `handle: int`, `n?: int` | First N rows (default 5) |
| `df_tail` | `handle: int`, `n?: int` | Last N rows (default 5) |
| `df_describe` | `handle: int` | Statistical summary |
| `df_to_csv` | `handle: int` | Export as CSV string |
| `df_to_json` | `handle: int` | Export as JSON string |
| `df_to_list` | `handle: int` | Export as list of row maps |
| `df_column_values` | `handle: int`, `column: string` | Get values for one column |
| `df_select` | `handle: int`, `columns: list` | Select columns, return new handle |
| `df_filter` | `handle: int`, `column: string`, `op: string`, `value` | Filter rows, return new handle |
| `df_sort` | `handle: int`, `column: string`, `ascending?: bool` | Sort rows, return new handle |
| `df_group_agg` | `handle: int`, `group_cols: list`, `agg_map: map` | Multi-column group-by with aggregation map, return new handle |
| `df_add_column` | `handle: int`, `name: string`, `values: list` | Add column, return new handle |
| `df_drop` | `handle: int`, `columns: list` | Drop columns, return new handle |
| `df_rename` | `handle: int`, `mapping: map` | Rename columns, return new handle |
| `df_merge` | `handle: int`, `other_handle: int`, `on: list`, `how?: string` | Join two DataFrames on columns, return new handle |
| `df_concat` | `handles: list`, `axis?: int` | Concatenate DataFrames, return new handle |
| `df_fillna` | `handle: int`, `value` | Fill missing values, return new handle |
| `df_dropna` | `handle: int` | Drop rows with missing values, return new handle |
| `df_transpose` | `handle: int` | Transpose, return new handle |
| `df_sample` | `handle: int`, `n?: int`, `frac?: number` | Random sample, return new handle |
| `df_nlargest` | `handle: int`, `n: int`, `column: string` | Top N rows by column, return new handle |
| `df_nsmallest` | `handle: int`, `n: int`, `column: string` | Bottom N rows by column, return new handle |
| `df_mean` | `handle: int`, `column?: string` | Mean of column(s) |
| `df_sum` | `handle: int`, `column?: string` | Sum of column(s) |
| `df_min` | `handle: int`, `column?: string` | Min of column(s) |
| `df_max` | `handle: int`, `column?: string` | Max of column(s) |
| `df_std` | `handle: int`, `column?: string` | Standard deviation of column(s) |
| `df_corr` | `handle: int` | Correlation matrix, return new handle |
| `df_unique` | `handle: int`, `column: string` | Unique values in column |
| `df_value_counts` | `handle: int`, `column: string` | Value frequency counts |
| `df_dispose` | `handle: int` | Release a single DataFrame |
| `df_dispose_all` | | Release all DataFrames |

## Chart (`chart_*`)

Charting functions backed by `HostApi.registerChart`.

| Function | Params | Description |
|----------|--------|-------------|
| `chart_create` | `config: map` | Create a chart from configuration |
| `chart_update` | `chart_id: int`, `config: map` | Update an existing chart |

## Form (`form_*`)

Form functions backed by `FormApi`.

| Function | Params | Description |
|----------|--------|-------------|
| `form_create` | `fields: list` | Create a form with field definitions |
| `form_set_errors` | `handle: int`, `errors: map` | Set validation errors on a form |

## Platform

General platform bridge functions.

| Function | Params | Description |
|----------|--------|-------------|
| `host_invoke` | `name: string`, `args: map` | Invoke an arbitrary platform callback |
| `sleep` | `ms: int` | Pause execution for N milliseconds |
| `fetch` | `url: string`, `method?: string`, `headers?: map`, `body?: string` | HTTP request. Returns `{status, body, headers}` |
| `log` | `message: string`, `level?: string` | Log a message. Levels: debug, info, warning, error |

## Streams (`stream_*`)

Server-sent event stream consumption.

| Function | Params | Description |
|----------|--------|-------------|
| `stream_subscribe` | `name: string` | Subscribe to a named stream, return handle |
| `stream_next` | `handle: int` | Await next event from stream |
| `stream_close` | `handle: int` | Close a stream subscription |

## Blackboard (`blackboard_*`)

Shared key-value store for inter-agent communication.

| Function | Params | Description |
|----------|--------|-------------|
| `blackboard_write` | `key: string`, `value` | Write a value to the blackboard |
| `blackboard_read` | `key: string` | Read a value from the blackboard |
| `blackboard_keys` | | List all blackboard keys |

## Agent

Agent supervision and orchestration. Requires `AgentApi` to be wired.

| Function | Params | Description |
|----------|--------|-------------|
| `spawn_agent` | `room: string`, `prompt: string`, `thread_id?: string` | Spawn an L2 sub-agent, return handle |
| `wait_all` | `handles: list` | Wait for all agents to complete |
| `get_result` | `handle: int` | Get the result of a completed agent |
| `agent_watch` | `handle: int`, `timeout_seconds?: number` | Watch an agent until completion |
| `cancel_agent` | `handle: int` | Cancel a spawned agent |
| `agent_status` | `handle: int` | Poll agent lifecycle state |
| `ask_llm` | `prompt: string`, `room?: string`, `thread_id?: string` | Spawn + await in one call (convenience) |

## Isolate (`isolate_*`)

Child interpreter spawning via `IsolatePlugin` (dart\_monty\_bridge).
Each child gets its own `MontyPlatform` and `DefaultMontyBridge`.

| Function | Params | Description |
|----------|--------|-------------|
| `isolate_spawn` | `code: string`, `timeout_ms?: int`, `memory_bytes?: int` | Spawn code in a new interpreter, return handle |
| `isolate_await` | `handle: int` | Wait for child to complete |
| `isolate_await_all` | `handles: list` | Wait for multiple children |
| `isolate_is_alive` | `handle: int` | Check if child is still running |
| `isolate_cancel` | `handle: int` | Cancel a running child |

## Event Loop

Bidirectional Python/Dart state loop via `EventLoopBridge`.

| Function | Params | Description |
|----------|--------|-------------|
| `wait_for_event` | `state: map` | Yield state to Dart, block until next event |
| `render_ui` | `state: map` | Push UI state without blocking |

## Introspection

Built-in self-documentation functions (always available).

| Function | Params | Description |
|----------|--------|-------------|
| `list_functions` | | List all registered function names |
| `help` | `name: string` | Get schema/description for a function |

## Internal

Not callable by user code -- injected by the bridge infrastructure.

| Function | Description |
|----------|-------------|
| `__console_write__` | Intercepts Python `print()` calls for bridge output capture |
