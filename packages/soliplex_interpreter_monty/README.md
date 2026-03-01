# soliplex_interpreter_monty

Pure Dart package bridging the Monty sandboxed Python interpreter into Soliplex.

## Quick Start

```bash
cd packages/soliplex_interpreter_monty
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Bridge (core agentic pipeline)

- `MontyBridge` -- abstract bridge interface (`Stream<BridgeEvent> execute(code)`)
- `DefaultMontyBridge` -- Monty start/resume loop, host function dispatch, emits `Stream<BridgeEvent>`
- `BridgeEvent` -- sealed hierarchy (12 subtypes): protocol-agnostic lifecycle events

### Host Functions

- `HostFunction` -- schema + async handler pair
- `HostFunctionSchema` -- name, description, params with `mapAndValidate()`
- `HostFunctionRegistry` -- groups HostFunctions by category, bulk-registers onto bridge
- `HostParam` / `HostParamType` -- parameter definitions with validation

### Execution

- `MontyExecutionService` -- simple start/resume loop producing `Stream<ConsoleEvent>` (play button)
- `ConsoleEvent` -- sealed hierarchy: ConsoleOutput, ConsoleComplete, ConsoleError
- `ExecutionResult` -- return value + resource usage + collected output

### Utilities

- `SchemaExecutor` -- Python-based schema validation via Monty
- `InputVariable` / `InputVariableType` -- form input variable definitions
- `MontyLimitsDefaults` -- preset resource limits (tool vs play-button)
- `introspection_functions` -- list_functions + help builtins
- `ToolDefinitionConverter` / `ToolNameMapping` -- backend tool def to bridge schema conversion

## Dependencies

- `dart_monty_platform_interface` -- MontyPlatform, MockMontyPlatform, all data types
- `meta` -- @immutable annotations

## Example

```dart
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

Future<void> main() async {
  // 1. Create a bridge (requires a MontyPlatform implementation)
  final bridge = DefaultMontyBridge(platform: myMontyPlatform);

  // 2. Register host functions (optional)
  final registry = HostFunctionRegistry();
  registry.registerOnto(bridge);

  // 3. Execute Python code and listen for events
  final events = bridge.execute('print("Hello from Monty!")');
  await for (final event in events) {
    switch (event) {
      case BridgeTextContent(:final text):
        print('Output: $text');
      case BridgeRunFinished():
        print('Done.');
      default:
        break;
    }
  }
}
```
