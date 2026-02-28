# soliplex_monty

Flutter package bridging Monty sandboxed Python interpreter into Soliplex.

## Quick Reference

```bash
flutter pub get
dart format . --set-exit-if-changed
flutter analyze --fatal-infos
flutter test
flutter test --coverage
```

## Architecture

- `MontyExecutionService` — core start/resume loop producing `Stream<ConsoleEvent>`
- `PythonExecutorTool` — ClientTool factory (STUBBED until soliplex_client PRs merge)
- `PythonRunButton` — play button widget with input variable form validation
- `ConsoleOutputView` — streaming monospace output renderer

## Dependencies

- `dart_monty_platform_interface` — MontyPlatform, MockMontyPlatform, all data types
- `soliplex_client` — (future) ToolRegistry, ClientTool, Tool, ToolCallInfo

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- All types immutable where possible
