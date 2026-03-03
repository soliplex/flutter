# Soliplex Packages

This directory contains 12 self-contained packages that make up the Soliplex
monorepo. Each package has its own `pubspec.yaml`, test suite, and README.

## Dependency Graph

```text
soliplex_logging           (leaf — pure Dart)
soliplex_schema            (leaf — pure Dart)
soliplex_dataframe         (leaf — pure Dart)
soliplex_skills            (leaf — pure Dart)
soliplex_interpreter_monty (leaf — pure Dart)

soliplex_client            → logging
soliplex_client_native     → client                         (Flutter)
soliplex_agent             → client, logging
soliplex_scripting         → agent, client, dataframe, interpreter_monty
soliplex_cli               → agent, client, logging
soliplex_tui               → agent, logging
soliplex_monty             → interpreter_monty (via dart_monty)  (Flutter)
```

## Package Overview

| Package | Type | Description |
|---------|------|-------------|
| [soliplex_logging](soliplex_logging/) | Pure Dart | Centralized logging, DiskQueue, BackendLogSink |
| [soliplex_schema](soliplex_schema/) | Pure Dart | Runtime JSON Schema parsing for AG-UI features |
| [soliplex_dataframe](soliplex_dataframe/) | Pure Dart | Pandas-like DataFrame engine with handle-based registry |
| [soliplex_skills](soliplex_skills/) | Pure Dart | Skill loading and execution (.md and .py files) |
| [soliplex_interpreter_monty](soliplex_interpreter_monty/) | Pure Dart | Monty Python sandbox bridge |
| [soliplex_client](soliplex_client/) | Pure Dart | REST API client, AG-UI protocol, domain models |
| [soliplex_client_native](soliplex_client_native/) | Flutter | Native HTTP platform adapters (Cupertino) |
| [soliplex_agent](soliplex_agent/) | Pure Dart | Agent orchestration (RunOrchestrator, AgentRuntime) |
| [soliplex_scripting](soliplex_scripting/) | Pure Dart | Wires AG-UI events to the Monty interpreter bridge |
| [soliplex_cli](soliplex_cli/) | Pure Dart | Interactive REPL for exercising soliplex_agent |
| [soliplex_tui](soliplex_tui/) | Pure Dart | Rich terminal UI for the agent backend |
| [soliplex_monty](soliplex_monty/) | Flutter | Monty Python bridge with Flutter widgets |

## Working on a Package

```bash
cd packages/<package_name>

# Pure Dart packages
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos

# Flutter packages (soliplex_client_native, soliplex_monty)
flutter pub get
flutter test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Rules

- Pure Dart packages must not import `package:flutter/*`.
- Platform-specific code goes in `soliplex_client_native`.
- All packages use `very_good_analysis` for linting.
- Each package must pass `dart analyze --fatal-infos` with zero issues.
