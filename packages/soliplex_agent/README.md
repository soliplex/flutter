# soliplex_agent

Pure Dart agent orchestration for Soliplex AI runtime.

## Quick Start

```bash
cd packages/soliplex_agent
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Runtime

- `AgentRuntime` -- top-level facade; spawns and manages `AgentSession` instances
- `AgentSession` -- single autonomous interaction; automates the tool-execution loop
- `AgentSessionState` -- enum representing the public lifecycle (spawning, running, completed, ...)

### Run (single-run state machine)

- `RunOrchestrator` -- drives one AG-UI run: starts the SSE stream, processes events, yields for tool calls
- `RunState` -- sealed hierarchy (Idle, Running, ToolYielding, Completed, Failed, Cancelled)
- `ErrorClassifier` -- maps low-level exceptions to `FailureReason`

### Models

- `AgentResult` -- sealed result (AgentSuccess, AgentFailure, AgentTimedOut)
- `FailureReason` -- categorised failure enum (network, timeout, cancelled, ...)
- `ThreadKey` -- typedef record `(serverId, roomId, threadId)` identifying a conversation

### Host

- `HostApi` -- abstract interface for platform callbacks (e.g. data-frame, chart)
- `PlatformConstraints` -- abstract interface describing platform limits
- `NativePlatformConstraints` / `WebPlatformConstraints` -- concrete implementations
- `FakeHostApi` -- test double

### Tools

- `ToolRegistryResolver` -- typedef for a factory function that returns a `ToolRegistry` per room

## Dependencies

- `soliplex_client` -- REST API, AG-UI client, domain models
- `soliplex_logging` -- structured logging
- `meta` -- annotations

## Example

```dart
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

Future<void> main() async {
  // 1. Build dependencies
  final api = SoliplexApi(/* ... */);
  final agUiClient = AgUiClient(/* ... */);
  final logger = LogManager.instance.getLogger('example');

  // 2. Create runtime
  final runtime = AgentRuntime(
    api: api,
    agUiClient: agUiClient,
    toolRegistryResolver: (_) async => ToolRegistry(),
    platform: const NativePlatformConstraints(),
    logger: logger,
  );

  // 3. Spawn a session and await the result
  final session = await runtime.spawn(
    roomId: 'plain',
    prompt: 'Hello!',
  );

  final result = await session.result;
  switch (result) {
    case AgentSuccess(:final output):
      print('Success: $output');
    case AgentFailure(:final reason):
      print('Failed: $reason');
    case AgentTimedOut():
      print('Timed out');
  }

  await runtime.dispose();
}
```
