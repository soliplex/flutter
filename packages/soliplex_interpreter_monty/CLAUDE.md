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

- `MontyExecutionService` — core start/resume loop producing `Stream<ConsoleEvent>`
- `PythonExecutorTool` — ClientTool factory (STUBBED until soliplex_client PRs merge)
- `HostFunctionRegistry` — register and group HostFunctions
- `introspection_functions` — list_functions + help builtins

## Dependencies

- `dart_monty_platform_interface` — MontyPlatform, MockMontyPlatform, all data types
- `ag_ui` — Tool definition types

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- All types immutable where possible
