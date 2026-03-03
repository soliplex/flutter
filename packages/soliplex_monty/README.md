# soliplex_monty

Flutter package bridging the Monty sandboxed Python interpreter into the Soliplex application. It enables execution of Python code -- including LLM-generated code that can call back to registered Dart host functions -- and provides Flutter widgets for interactive Python consoles.

## Quick Start

```bash
cd packages/soliplex_monty
flutter pub get
flutter test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Bridge

- `MontyBridge` -- Abstract interface for executing Python code that can call registered Dart host functions, emitting a stream of AG-UI `BaseEvent`s.
- `DefaultMontyBridge` -- The default `MontyBridge` implementation that orchestrates the Monty start/resume loop and dispatches calls to host functions.
- `HostFunctionRegistry` -- Groups `HostFunction`s by category and registers them (plus introspection built-ins) onto a `MontyBridge`.
- `HostFunction` -- A Dart function callable from Python, composed of a `HostFunctionSchema` and a `HostFunctionHandler`.
- `HostFunctionSchema` -- Defines the name, description, and parameters for a `HostFunction`.
- `HostParam` -- Defines a single parameter for a `HostFunctionSchema`.
- `HostParamType` -- Enum of supported data types for a `HostParam` (`string`, `int`, `float`, `bool`, `list`, `map`).
- `ToolDefinitionConverter` -- Converts `HostFunctionSchema`s into AG-UI `Tool` definitions for an LLM.

### Execution

- `MontyExecutionService` -- A simplified service to execute Python code and stream console output, without host function support.
- `ExecutionResult` -- Contains the return value, resource usage, and console output of a successful execution.
- `ConsoleEvent` -- A sealed class for events from `MontyExecutionService`: `ConsoleOutput`, `ConsoleComplete`, `ConsoleError`.

### Widgets

- `PythonRunButton` -- An `IconButton` that executes Python code via `MontyExecutionService`, optionally collecting user input via a form dialog.
- `ConsoleOutputView` -- A widget that renders a stream of `ConsoleEvent`s as a formatted, auto-scrolling console.

### Data and Tools

- `DataFrame` -- Represents tabular data that can be manipulated by Python code.
- `DfRegistry` -- Manages `DataFrame` instances by name, making them accessible to Python.
- `buildDfFunctions()` -- Provides a set of built-in `HostFunction`s for creating and manipulating `DataFrame`s from Python.
- `SchemaExecutor` -- Executes Python-based schema validators against JSON data at runtime.
- `PythonExecutorTool` -- Defines the `execute_python` tool schema for use with an agent framework.
- `InputVariable` -- Describes a variable to be collected from the user before executing code with `PythonRunButton`.
- `InputVariableType` -- Enum of supported types for an `InputVariable` (`string`, `int`, `float`, `bool`).
- `MontyLimitsDefaults` -- Provides default `MontyLimits` constants for different execution contexts (e.g., `tool`, `playButton`).

## Dependencies

- `ag_ui` -- Provides the `Tool` and `BaseEvent` models for integration with the agent framework.
- `dart_monty_platform_interface` -- Core platform interface for interacting with the sandboxed Monty Python interpreter.
- `flutter` -- Flutter framework for widgets.
- `meta` -- Annotations like `@immutable`.

## Example

```dart
import 'package:soliplex_monty/soliplex_monty.dart';

void main() async {
  // 1. Create a simple execution service (no host functions).
  final service = MontyExecutionService();

  // 2. Execute Python code and listen for console events.
  await for (final event in service.execute('print("Hello from Python!")')) {
    switch (event) {
      case ConsoleOutput(:final text):
        print('OUTPUT: $text');
      case ConsoleComplete(:final result):
        print('Done. Return value: ${result.value}');
      case ConsoleError(:final error):
        print('Error: ${error.message}');
    }
  }

  service.dispose();
}
```
