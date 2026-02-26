import 'package:ag_ui/ag_ui.dart' show Tool;

/// Constants for the `execute_python` client-side tool.
///
/// Provides the tool name and ag-ui [Tool] definition that gets registered
/// with the ToolRegistry when a MontyBridge is available.
abstract final class PythonExecutorTool {
  /// The tool name registered with the backend.
  static const toolName = 'execute_python';

  /// AG-UI tool definition sent to the backend so the LLM can call it.
  static const definition = Tool(
    name: toolName,
    description: 'Execute Python code in a sandboxed interpreter. '
        'The code can call registered tool functions directly. '
        'Returns the text output or error message.',
    parameters: {
      'type': 'object',
      'properties': {
        'code': {
          'type': 'string',
          'description': 'Python source code to execute',
        },
      },
      'required': ['code'],
    },
  );
}
