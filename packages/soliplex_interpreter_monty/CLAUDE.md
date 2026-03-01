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

### Bridge (core agentic pipeline)

- `MontyBridge` — abstract bridge interface (`Stream<BridgeEvent> execute(code)`)
- `DefaultMontyBridge` — Monty start/resume loop, host function dispatch, emits `Stream<BridgeEvent>`
- `BridgeEvent` — sealed hierarchy (12 subtypes): protocol-agnostic lifecycle events

### Host Functions

- `HostFunction` — schema + async handler pair
- `HostFunctionSchema` — name, description, params with `mapAndValidate()`
- `HostFunctionRegistry` — groups HostFunctions by category, bulk-registers onto bridge
- `HostParam` / `HostParamType` — parameter definitions with validation

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

- `dart_monty_platform_interface` — MontyPlatform, MockMontyPlatform, all data types
- `meta` — @immutable annotations

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- All types immutable where possible
