# soliplex_scripting

Wiring package bridging Monty interpreter events to ag-ui protocol.

## Quick Reference

```bash
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart test --coverage
```

## Architecture

### Tool Definition

- `PythonExecutorTool` -- static `toolName` and AG-UI `Tool` definition for `execute_python`

### Execution

- `MontyScriptEnvironment` -- session-scoped `ScriptEnvironment` backed by a `MontyBridge`; owns bridge, `DfRegistry`, `StreamRegistry`; disposed by `AgentSession`
- `createMontyScriptEnvironmentFactory()` -- creates a `ScriptEnvironmentFactory` that produces fresh `MontyScriptEnvironment` per session

### Event Bridging

- `AgUiBridgeAdapter` -- transforms `Stream<BridgeEvent>` to `Stream<BaseEvent>` (AG-UI)

### Plugin System

- `PluginRegistry` -- collects `MontyPlugin`s with namespace validation, function collision detection, and `attachTo(bridge)` / `disposeAll()` lifecycle
- `LegacyUnprefixedPlugin` -- mixin for plugins whose function names predate the `namespace_` prefix convention

### Plugins (in `lib/src/plugins/`)

| Plugin | Namespace | Functions | Notes |
|--------|-----------|-----------|-------|
| `DfPlugin` | `df` | 37 DataFrame ops | Wraps `buildDfFunctions(DfRegistry)` |
| `ChartPlugin` | `chart` | `chart_create`, `chart_update` | Delegates to `HostApi` |
| `PlatformPlugin` | `platform` | `host_invoke`, `sleep`, `fetch`, `log`, `get_auth_token` | Legacy (unprefixed) |
| `StreamPlugin` | `stream` | `stream_subscribe`, `stream_next`, `stream_close` | |
| `FormPlugin` | `form` | `form_create`, `form_set_errors` | |
| `AgentPlugin` | `agent` | `spawn_agent`, `wait_all`, `get_result`, `agent_watch`, `cancel_agent`, `agent_status`, `ask_llm` | Legacy (unprefixed); `ask_llm` deprecated in favor of `LlmPlugin` |
| `BlackboardPlugin` | `blackboard` | `blackboard_write`, `blackboard_read`, `blackboard_keys` | |
| `LlmPlugin` | `llm` | `llm_complete`, `llm_chat` | Strict prefix; delegates to `AgentApi` |
| `McpPlugin` | `mcp` | `mcp_call_tool`, `mcp_list_tools`, `mcp_list_servers` | Strict prefix; injected callbacks |

### Other

- `HostSchemaAgUi` -- extension converting `HostFunctionSchema` to AG-UI `Tool`

## Dependencies

- `ag_ui` -- AG-UI protocol types
- `soliplex_agent` -- `ScriptEnvironment`, `ScriptEnvironmentFactory`, `ClientTool`
- `soliplex_client` -- `ToolCallInfo`, `ClientTool`
- `soliplex_interpreter_monty` -- `MontyBridge`, `BridgeEvent`, `HostFunctionRegistry`
- `dart_monty_platform_interface` -- `MontyLimits` type for bridge resource limits
- `meta` -- annotations

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- Pure Dart only -- no Flutter imports
- All types immutable where possible
