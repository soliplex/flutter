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

### Host Wiring

- `HostFunctionWiring` -- registers Dart callbacks onto `MontyBridge` via `HostApi`; agent calls (`ask_llm`, `get_result`, `wait_all`) guarded by `agentTimeout` (default 30s)
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
