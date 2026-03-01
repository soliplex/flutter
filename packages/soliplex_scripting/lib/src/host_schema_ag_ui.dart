import 'package:ag_ui/ag_ui.dart' show Tool;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Extension that adds ag-ui [Tool] export to [HostFunctionSchema].
///
/// This lives in `soliplex_scripting` (not the interpreter) to keep
/// `soliplex_interpreter_monty` free of ag-ui dependencies.
extension HostSchemaAgUi on HostFunctionSchema {
  /// Exports this schema as an ag-ui [Tool] for LLM system prompts.
  Tool toAgUiTool() {
    final properties = <String, Object?>{};
    final required = <String>[];

    for (final param in params) {
      properties[param.name] = <String, Object?>{
        'type': param.type.jsonSchemaType,
        if (param.description != null) 'description': param.description,
      };
      if (param.isRequired) {
        required.add(param.name);
      }
    }

    return Tool(
      name: name,
      description: description,
      parameters: <String, Object?>{
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
      },
    );
  }
}
