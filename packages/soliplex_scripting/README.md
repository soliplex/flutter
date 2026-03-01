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
- `ScriptingToolRegistryResolver` -- decorator that wraps an inner `ToolRegistryResolver` and injects the `execute_python` tool

### Execution

- `MontyToolExecutor` -- acquires a bridge from cache, configures host functions, runs Python code, returns aggregated text output
- `BridgeCache` -- LRU pool of `MontyBridge` instances keyed by `ThreadKey`; respects concurrency limits

### Event Bridging

- `AgUiBridgeAdapter` -- transforms `Stream<BridgeEvent>` (from the interpreter) into `Stream<BaseEvent>` (AG-UI protocol) for live UI rendering

### Host Wiring

- `HostFunctionWiring` -- registers Dart callback functions (via `HostApi`) onto a `MontyBridge` so Python code can call back into the host
- `HostSchemaAgUi` -- extension on `HostFunctionSchema` that converts interpreter function metadata to AG-UI `Tool` definitions

## Dependencies

- `ag_ui` -- AG-UI protocol types
- `soliplex_agent` -- `ThreadKey`, `ToolRegistryResolver`, `ToolRegistry`
- `soliplex_client` -- `ToolCallInfo`, `ClientTool`
- `soliplex_interpreter_monty` -- `MontyBridge`, `BridgeEvent`, `HostFunctionRegistry`
- `meta` -- annotations

## Example

```dart
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

void main() {
  // 1. Create a bridge cache with concurrency limit
  final cache = BridgeCache(limit: 4);

  // 2. Wire host functions
  final wiring = HostFunctionWiring(hostApi: myHostApi);

  // 3. Create executor for a thread
  final executor = MontyToolExecutor(
    threadKey: (serverId: 'default', roomId: 'r1', threadId: 't1'),
    bridgeCache: cache,
    hostWiring: wiring,
  );

  // 4. Wrap the base tool resolver to add execute_python
  final resolver = ScriptingToolRegistryResolver(
    inner: baseToolResolver,
    executor: executor,
  );
}
```
