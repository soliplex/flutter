// TODO(runyaga): Implement when soliplex_client ToolRegistry merges
// (PRs #291/#293). Depends on ClientTool, ToolExecutor, and Tool types
// from package:soliplex_client.

/// Factory for creating the `execute_python` client-side tool.
///
/// Stubbed until the tool-calling infrastructure lands in soliplex_client.
abstract final class PythonExecutorTool {
  /// The tool name registered with the backend.
  static const toolName = 'execute_python';

  // static ClientTool asClientTool({
  //   MontyPlatform? platform,
  //   MontyLimits limits = MontyLimitsDefaults.tool,
  // });

  // static Tool get definition;
}
