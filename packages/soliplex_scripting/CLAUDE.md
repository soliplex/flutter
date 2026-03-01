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
- `ScriptingToolRegistryResolver` -- decorator wrapping an inner resolver to inject `execute_python`

### Execution

- `MontyToolExecutor` -- acquires bridge from cache, configures host functions, runs code, returns text
- `BridgeCache` -- LRU pool of `MontyBridge` instances keyed by `ThreadKey`

### Event Bridging

- `AgUiBridgeAdapter` -- transforms `Stream<BridgeEvent>` to `Stream<BaseEvent>` (AG-UI)

### Host Wiring

- `HostFunctionWiring` -- registers Dart callbacks onto `MontyBridge` via `HostApi`
- `HostSchemaAgUi` -- extension converting `HostFunctionSchema` to AG-UI `Tool`

## Dependencies

- `ag_ui` -- AG-UI protocol types
- `soliplex_agent` -- `ThreadKey`, `ToolRegistryResolver`, `ToolRegistry`
- `soliplex_client` -- `ToolCallInfo`, `ClientTool`
- `soliplex_interpreter_monty` -- `MontyBridge`, `BridgeEvent`, `HostFunctionRegistry`
- `meta` -- annotations

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- Pure Dart only -- no Flutter imports
- All types immutable where possible
