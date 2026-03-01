# soliplex_cli

Interactive REPL for exercising `soliplex_agent` against a live backend.

## Quick Reference

```bash
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart run bin/soliplex_cli.dart
dart run bin/soliplex_cli.dart --host http://localhost:8000 --room plain
```

## Architecture

- `CliRunner` -- REPL loop, command dispatch, `_CliContext` state management
- `ClientFactory` (`createClients`) -- creates `SoliplexApi` + `AgUiClient` from host URL
- `ToolDefinitions` (`buildDemoToolRegistry`) -- demo tool registry (secret_number, echo)
- `ResultPrinter` (`formatResult`) -- formats `AgentResult` for terminal output

## Dependencies

- `args` -- command-line argument parsing
- `soliplex_agent` -- `AgentRuntime`, `AgentSession`, `AgentResult`
- `soliplex_client` -- `SoliplexApi`, `AgUiClient`, `ToolRegistry`
- `soliplex_logging` -- structured logging

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- Pure Dart only -- no Flutter imports
