# soliplex_agent

Pure Dart agent orchestration for Soliplex AI runtime.

## Quick Reference

```bash
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart test --coverage
```

## Architecture

### Runtime

- `AgentRuntime` -- top-level facade; spawns and manages `AgentSession` instances
- `AgentSession` -- single autonomous interaction; automates the tool-execution loop
- `AgentSessionState` -- enum (spawning, running, completed, ...)

### Run (single-run state machine)

- `RunOrchestrator` -- drives one AG-UI run: SSE stream, event processing, tool yielding
- `RunState` -- sealed hierarchy: Idle, Running, ToolYielding, Completed, Failed, Cancelled
- `ErrorClassifier` -- maps exceptions to `FailureReason`

### Models

- `AgentResult` -- sealed: AgentSuccess, AgentFailure, AgentTimedOut
- `FailureReason` -- categorised failure enum
- `ThreadKey` -- typedef record `(serverId, roomId, threadId)`

### Host

- `HostApi` -- abstract platform callback interface
- `PlatformConstraints` -- abstract platform limits
- `NativePlatformConstraints` / `WebPlatformConstraints` -- concrete implementations
- `FakeHostApi` -- test double

### Tools

- `ToolRegistryResolver` -- typedef factory returning `ToolRegistry` per room

## Dependencies

- `soliplex_client` -- REST API, AG-UI client, domain models
- `soliplex_logging` -- structured logging
- `meta` -- annotations

## Rules

- Follow KISS, YAGNI, SOLID
- No `// ignore:` directives
- Match surrounding code style
- Use `very_good_analysis` linting
- Pure Dart only -- no Flutter imports
- All types immutable where possible
