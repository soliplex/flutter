import 'package:ag_ui/ag_ui.dart' show BaseEvent, Tool;
import 'package:soliplex_interpreter_monty/src/bridge/host_function.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';

/// Bridge for LLM-generated Python calling registered Dart host functions.
///
/// Executes Python code in the Monty sandbox, dispatches external function
/// calls to registered [HostFunction] handlers, and emits ag-ui [BaseEvent]s.
abstract class MontyBridge {
  /// All registered function schemas.
  List<HostFunctionSchema> get schemas;

  /// Exports all schemas as ag-ui [Tool] definitions for LLM system prompts.
  List<Tool> toAgUiTools();

  /// Registers a host function.
  void register(HostFunction function);

  /// Unregisters a host function by name.
  void unregister(String name);

  /// Executes [code] and returns a stream of ag-ui events.
  ///
  /// Events follow the ag-ui lifecycle:
  /// 1. `RunStartedEvent`
  /// 2. Per external function call: Step/ToolCall events + handler execution
  /// 3. Buffered print output flushed as TextMessage events
  /// 4. `RunFinishedEvent` or `RunErrorEvent`
  Stream<BaseEvent> execute(String code);

  /// Releases resources.
  void dispose();
}
