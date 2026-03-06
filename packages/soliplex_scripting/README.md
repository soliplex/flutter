# soliplex_scripting

Wiring package that bridges `soliplex_interpreter_monty` events to the AG-UI protocol, making the Monty Python sandbox available as an agent tool.

## Quick Start

```bash
cd packages/soliplex_scripting
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Tool Definition

- `PythonExecutorTool` -- static `toolName` (`execute_python`) and AG-UI `Tool` definition schema

### Execution

- `MontyScriptEnvironment` -- session-scoped `ScriptEnvironment` backed by a `MontyBridge`; owns bridge, `DfRegistry`, `StreamRegistry`; disposed automatically by `AgentSession`
- `createMontyScriptEnvironmentFactory()` -- creates a `ScriptEnvironmentFactory` that produces a fresh `MontyScriptEnvironment` per session

### Event Bridging

- `AgUiBridgeAdapter` -- transforms `Stream<BridgeEvent>` (from the interpreter) into `Stream<BaseEvent>` (AG-UI protocol) for live UI rendering

### Host Wiring

- `HostFunctionWiring` -- registers Dart callback functions (via `HostApi`) onto a `MontyBridge` so Python code can call back into the host
- `HostSchemaAgUi` -- extension on `HostFunctionSchema` that converts interpreter function metadata to AG-UI `Tool` definitions

## Dependencies

- `ag_ui` -- AG-UI protocol types
- `soliplex_agent` -- `ScriptEnvironment`, `ScriptEnvironmentFactory`, `ClientTool`
- `soliplex_client` -- `ToolCallInfo`
- `soliplex_interpreter_monty` -- `MontyBridge`, `BridgeEvent`, `HostFunctionRegistry`, `MontyLimitsDefaults`
- `dart_monty_platform_interface` -- `MontyLimits` type for bridge resource limits
- `meta` -- annotations

## Defaults

| Parameter | Default | Notes |
|-----------|---------|-------|
| `MontyScriptEnvironment.executionTimeout` | 30 s | Dart-side safety net for code execution |
| `HostFunctionWiring.agentTimeout` | 30 s | Timeout for `ask_llm`, `get_result`, `wait_all` |

For interactive demos (play button), use `MontyLimitsDefaults.playButton` (10s, 32 MB)
and longer execution/agent timeouts (e.g. 60s).

## Example

```dart
import 'package:soliplex_scripting/soliplex_scripting.dart';

void main() {
  // Create a factory that produces session-scoped environments.
  final factory = createMontyScriptEnvironmentFactory(
    hostApi: myHostApi,
    agentApi: myAgentApi,  // optional, enables spawn_agent/ask_llm
    limits: MontyLimitsDefaults.tool, // 5s, 16 MB
  );

  // Pass to AgentRuntime via wrapScriptEnvironmentFactory().
  // Each session gets its own bridge + registries, disposed on session end.
  //
  // final runtime = AgentRuntime(
  //   connection: connection,
  //   toolRegistryResolver: resolver,
  //   extensionFactory: wrapScriptEnvironmentFactory(factory),
  //   platform: NativePlatformConstraints(),
  //   logger: logger,
  // );
}
```
