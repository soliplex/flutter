# soliplex_cli

Interactive REPL for exercising `soliplex_agent` against a live backend.

## Quick Reference

```bash
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart run bin/soliplex_cli.dart
dart run bin/soliplex_cli.dart --soliplex http://localhost:8000 --room plain
dart run bin/soliplex_cli.dart --monty --room spike-20b
dart run bin/soliplex_cli.dart --monty --wasm-mode --room spike-20b

# Multiple prompts run sequentially in the same thread (shared state):
dart run bin/soliplex_cli.dart --monty --room spike-20b \
  -p "Write a function to add two numbers" \
  -p "Now call add(3, 4) and print the result" \
  -p "What functions have we defined so far?"
```

## Architecture

- `CliRunner` -- REPL loop, command dispatch, `_CliContext` state management
- `ClientFactory` (`createClients`) -- creates `ServerConnection` from host URL
- `ToolDefinitions` (`buildDemoToolRegistry`) -- demo tool registry (secret_number, echo)
- `ResultPrinter` (`formatResult`) -- formats `AgentResult` for terminal output

## Monty Mode

`--monty` enables the Monty Python sandbox via `extensionFactory` on `AgentRuntime`.
Each `AgentSession` gets its own `MontyScriptEnvironment` with `DefaultMontyBridge`,
`DfRegistry`, and `HostFunctionWiring`. When the LLM calls `execute_python` as a tool,
`AgentSession` auto-executes it through real Monty.

`--wasm-mode` uses `WebPlatformConstraints` (single bridge, no re-entrancy) to validate
WASM compatibility.

`FakeHostApi` stubs chart/platform calls for headless operation.

## Dependencies

- `args` -- command-line argument parsing
- `soliplex_agent` -- `AgentRuntime`, `AgentSession`, `AgentResult`
- `soliplex_client` -- `SoliplexApi`, `AgUiStreamClient`, `ToolRegistry`
- `soliplex_dataframe` -- `DfRegistry` (transitive via scripting)
- `soliplex_interpreter_monty` -- `DefaultMontyBridge` (transitive via scripting)
- `soliplex_logging` -- structured logging
- `soliplex_scripting` -- `MontyScriptEnvironment`, `HostFunctionWiring`, factory functions

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- Pure Dart only -- no Flutter imports
