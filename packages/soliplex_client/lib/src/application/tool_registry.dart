import 'package:ag_ui/ag_ui.dart';
import 'package:meta/meta.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';

/// Signature for a function that executes a tool call.
///
/// Receives the [ToolCallInfo] (name, arguments, id) and returns a result
/// string. Throwing an exception marks the tool call as failed; the error
/// message is forwarded to the model.
typedef ToolExecutor = Future<String> Function(ToolCallInfo toolCall);

/// A client-side tool definition paired with its executor.
@immutable
class ClientTool {
  /// Creates a client-side tool.
  const ClientTool({
    required this.definition,
    required this.executor,
  });

  /// AG-UI [Tool] definition sent to the backend so the model knows this
  /// tool exists.
  final Tool definition;

  /// Function that executes the tool and returns a result string.
  final ToolExecutor executor;
}

/// Immutable registry of client-side tools.
///
/// Shared via a Riverpod provider so multiple notifier instances (current
/// singleton or future multiplexed family) use the same tool set.
///
/// Register tools at app startup; the registry is immutable once built.
/// Each [register] call returns a **new** registry instance.
@immutable
class ToolRegistry {
  /// Creates an empty registry.
  const ToolRegistry() : _tools = const {};

  const ToolRegistry._(this._tools);

  final Map<String, ClientTool> _tools;

  /// Registers a [ClientTool] and returns a new registry containing it.
  ///
  /// The tool is keyed by the tool definition's name.
  ToolRegistry register(ClientTool tool) {
    return ToolRegistry._({..._tools, tool.definition.name: tool});
  }

  /// Returns the [ClientTool] registered under [name].
  ///
  /// Throws [StateError] if no tool with that name is registered.
  ClientTool lookup(String name) {
    final tool = _tools[name];
    if (tool == null) {
      throw StateError('No tool registered with name "$name"');
    }
    return tool;
  }

  /// Executes the tool matching the given tool call's name.
  ///
  /// Returns the result string on success. On failure, returns the error
  /// message prefixed with `"Error: "`. Callers should check the
  /// [ToolCallInfo.status] they set based on whether this threw.
  Future<String> execute(ToolCallInfo toolCall) async {
    final tool = lookup(toolCall.name);
    return tool.executor(toolCall);
  }

  /// Whether a tool with [name] is registered.
  bool contains(String name) => _tools.containsKey(name);

  /// The number of registered tools.
  int get length => _tools.length;

  /// Whether the registry has no tools.
  bool get isEmpty => _tools.isEmpty;

  /// AG-UI [Tool] definitions for all registered tools.
  ///
  /// Pass this to [SimpleRunAgentInput.tools] so the model knows which
  /// client-side tools are available.
  List<Tool> get toolDefinitions =>
      _tools.values.map((ct) => ct.definition).toList(growable: false);
}
