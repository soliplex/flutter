# soliplex_interpreter_monty

Pure Dart package bridging Monty sandboxed Python interpreter into Soliplex.

## Quick Reference

```bash
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart test --coverage
```

## Architecture

### Bridge (re-exported from `dart_monty_bridge`)

All core bridge types are provided by `dart_monty_bridge` and re-exported:

- `MontyBridge`, `DefaultMontyBridge`, `EventLoopBridge`
- `BridgeEvent` sealed hierarchy (15 subtypes)
- `HostFunction`, `HostFunctionSchema`, `HostParam`, `HostParamType`
- `HostFunctionRegistry`, `MontyPlugin`, `IsolatePlugin`

### Execution

- `MontyExecutionService` — simple start/resume loop producing `Stream<ConsoleEvent>` (play button)
- `ConsoleEvent` — sealed hierarchy: ConsoleOutput, ConsoleComplete, ConsoleError
- `ExecutionResult` — return value + resource usage + collected output

### Utilities

- `SchemaExecutor` — Python-based schema validation via Monty
- `InputVariable` / `InputVariableType` — form input variable definitions
- `MontyLimitsDefaults` — preset resource limits (tool vs play-button)
- `introspection_functions` — list_functions + help builtins
- `ToolDefinitionConverter` / `ToolNameMapping` — backend tool def → bridge schema conversion

## Dependencies

- `dart_monty_bridge` — DefaultMontyBridge, BridgeEvent, HostFunction, MontyPlugin, etc.
- `dart_monty_platform_interface` — MontyPlatform, MockMontyPlatform, all data types
- `meta` — @immutable annotations

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- All types immutable where possible
