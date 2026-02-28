import 'package:soliplex_client/soliplex_client.dart';

/// Converts a raw tool definition map to an ag_ui [Tool].
///
/// Maps backend field names to ag_ui fields:
/// - `tool_name` → `name`
/// - `tool_description` → `description`
/// - `extra_parameters` → `parameters`
Tool toolDefinitionToAgUiTool(Map<String, dynamic> toolDef) {
  return Tool(
    name: (toolDef['tool_name'] as String?) ?? '',
    description: (toolDef['tool_description'] as String?) ?? '',
    parameters: toolDef['extra_parameters'],
  );
}

/// Converts all tool definitions from a [Room] to ag_ui [Tool] objects.
///
/// Filters out tools with empty names since they are invalid.
List<Tool> roomToolsToAgUi(Room room) {
  return room.toolDefinitions
      .map(toolDefinitionToAgUiTool)
      .where((tool) => tool.name.isNotEmpty)
      .toList(growable: false);
}
