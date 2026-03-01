import 'package:soliplex_agent/soliplex_agent.dart' show ToolRegistryResolver;
import 'package:soliplex_client/soliplex_client.dart'
    show ClientTool, ToolRegistry;
import 'package:soliplex_scripting/src/monty_tool_executor.dart';
import 'package:soliplex_scripting/src/python_executor_tool.dart';

/// Wraps an inner [ToolRegistryResolver] and appends the `execute_python`
/// client-side tool to every resolved [ToolRegistry].
///
/// This allows the scripting layer to be composed transparently with the
/// existing tool resolution pipeline.
class ScriptingToolRegistryResolver {
  ScriptingToolRegistryResolver({
    required ToolRegistryResolver inner,
    required MontyToolExecutor executor,
  })  : _inner = inner,
        _executor = executor;

  final ToolRegistryResolver _inner;
  final MontyToolExecutor _executor;

  /// Resolves the inner registry for [roomId] and appends `execute_python`.
  Future<ToolRegistry> call(String roomId) async {
    final registry = await _inner(roomId);
    return registry.register(
      ClientTool(
        definition: PythonExecutorTool.definition,
        executor: _executor.execute,
      ),
    );
  }
}
