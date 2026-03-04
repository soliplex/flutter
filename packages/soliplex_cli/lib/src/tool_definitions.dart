import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart';

/// All demo tools available in the CLI.
///
/// Add new demo tools here; they'll be available via `--tools` filtering.
const _allDemoTools = [
  ClientTool(
    definition: Tool(
      name: 'secret_number',
      description: 'Returns the secret number.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    executor: _secretNumber,
  ),
  ClientTool(
    definition: Tool(
      name: 'echo',
      description: 'Echoes back the text argument.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'text': <String, dynamic>{
            'type': 'string',
            'description': 'The text to echo back.',
          },
        },
        'required': <String>['text'],
      },
    ),
    executor: _echo,
  ),
];

/// All known demo tool names (for validation).
Set<String> get availableDemoToolNames =>
    _allDemoTools.map((t) => t.definition.name).toSet();

/// Builds a [ToolRegistry] from demo tools.
///
/// When [enabledTools] is provided, only tools whose names are in the set
/// are registered. Unknown names are silently ignored (validate upstream).
ToolRegistry buildDemoToolRegistry({Set<String>? enabledTools}) {
  var registry = const ToolRegistry();
  for (final tool in _allDemoTools) {
    if (enabledTools == null || enabledTools.contains(tool.definition.name)) {
      registry = registry.register(tool);
    }
  }
  return registry;
}

Future<String> _secretNumber(ToolCallInfo toolCall, _) async => '42';

Future<String> _echo(ToolCallInfo toolCall, _) async {
  if (!toolCall.hasArguments) return '';
  final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
  return (args['text'] as String?) ?? '';
}
