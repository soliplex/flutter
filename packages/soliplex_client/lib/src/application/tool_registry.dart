import 'dart:async';

import 'package:ag_ui/ag_ui.dart' show Tool;
import 'package:meta/meta.dart';

import 'package:soliplex_client/src/domain/chat_message.dart';

/// Function signature for tool executors.
typedef ToolExecutor = FutureOr<String> Function(ToolCallInfo call);

/// A client-side tool registration containing both definition and executor.
///
/// The [definition] is the AG-UI Tool schema sent to the server so the LLM
/// knows about the tool. The [executor] is the function that runs locally
/// when the server requests the tool be called.
@immutable
class ClientTool {
  /// Creates a client tool with a definition and executor.
  const ClientTool({required this.definition, required this.executor});

  /// The AG-UI tool definition (name, description, parameters schema).
  final Tool definition;

  /// The function that executes the tool locally.
  final ToolExecutor executor;
}

/// Immutable registry for client-side tools.
///
/// Stores both tool definitions (for server communication) and executors
/// (for local execution). The definitions are sent to the server so the
/// LLM can call client-side tools.
@immutable
class ToolRegistry {
  /// Creates a tool registry with the given tools.
  const ToolRegistry({this.tools = const {}});

  /// Map of tool names to their client tool registrations.
  final Map<String, ClientTool> tools;

  /// Returns a new registry with the tool registered.
  ///
  /// [definition] is sent to the server so the LLM knows about the tool.
  /// [executor] runs locally when the tool is called.
  ToolRegistry register(Tool definition, ToolExecutor executor) {
    return ToolRegistry(
      tools: {
        ...tools,
        definition.name: ClientTool(definition: definition, executor: executor),
      },
    );
  }

  /// Returns true if a tool with [name] is registered.
  bool hasExecutor(String name) => tools.containsKey(name);

  /// Returns all tool definitions for sending to the server.
  List<Tool> get definitions => tools.values.map((t) => t.definition).toList();

  /// Executes the tool and returns the result.
  /// Throws [StateError] if no executor is registered for the tool.
  Future<String> execute(ToolCallInfo call) async {
    final clientTool = tools[call.name];
    if (clientTool == null) {
      throw StateError('No executor registered for tool: ${call.name}');
    }
    return clientTool.executor(call);
  }
}
