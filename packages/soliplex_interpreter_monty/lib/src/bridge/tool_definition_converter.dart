import 'dart:developer' as developer;

import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';

/// Pairs the Monty function name with the ToolRegistry lookup name.
///
/// - [pythonName]: The `kind` field — what Python calls
///   (e.g. `get_current_datetime`)
/// - [registryName]: The `tool_name` field — what ag-ui uses
///   (e.g. `soliplex.tools.get_current_datetime`)
/// - [schema]: The [HostFunctionSchema] registered with the bridge
@immutable
class ToolNameMapping {
  const ToolNameMapping({
    required this.pythonName,
    required this.registryName,
    required this.schema,
  });

  /// Function name callable from Python code.
  final String pythonName;

  /// Tool name used for ToolRegistry lookup.
  final String registryName;

  /// Host function schema for the bridge.
  final HostFunctionSchema schema;
}

/// Converts a raw tool definition map to a [HostFunctionSchema].
///
/// Expects backend fields:
/// - `kind` → schema name (Python-callable identifier)
/// - `tool_description` → schema description
/// - `extra_parameters` → JSON Schema with `properties` and `required`
///
/// Returns `null` if the tool def is missing a `kind`.
HostFunctionSchema? toolDefToHostSchema(Map<String, dynamic> toolDef) {
  final kind = toolDef['kind'] as String?;
  if (kind == null || kind.isEmpty) return null;

  final description = (toolDef['tool_description'] as String?) ?? '';
  final extraParams = toolDef['extra_parameters'] as Map<String, dynamic>?;
  final params = _parseParams(extraParams);

  return HostFunctionSchema(
    name: kind,
    description: description,
    params: params,
  );
}

/// Converts JSON Schema `properties` + `required` to [HostParam] list.
///
/// Each property key becomes a param name. The `type` field maps to
/// [HostParamType] via [_jsonSchemaTypeToParamType]. Unknown types
/// default to [HostParamType.string] with a warning.
List<HostParam> jsonSchemaPropsToParams(
  Map<String, dynamic> properties,
  Set<String> required,
) {
  return properties.entries.map((entry) {
    final name = entry.key;
    final prop = entry.value as Map<String, dynamic>? ?? const {};
    final typeStr = (prop['type'] as String?) ?? 'string';
    final type = _jsonSchemaTypeToParamType(typeStr);
    final description = prop['description'] as String?;

    return HostParam(
      name: name,
      type: type,
      isRequired: required.contains(name),
      description: description,
    );
  }).toList(growable: false);
}

/// Converts a list of raw tool definition maps to [ToolNameMapping]s.
///
/// Skips tool defs that are missing `kind` or `tool_name`.
List<ToolNameMapping> roomToolDefsToMappings(
  List<Map<String, dynamic>> toolDefs,
) {
  final mappings = <ToolNameMapping>[];

  for (final toolDef in toolDefs) {
    final kind = toolDef['kind'] as String?;
    final toolName = toolDef['tool_name'] as String?;
    if (kind == null || kind.isEmpty) continue;
    if (toolName == null || toolName.isEmpty) continue;

    final schema = toolDefToHostSchema(toolDef);
    if (schema == null) continue;

    mappings.add(
      ToolNameMapping(
        pythonName: kind,
        registryName: toolName,
        schema: schema,
      ),
    );
  }

  return mappings;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

List<HostParam> _parseParams(Map<String, dynamic>? extraParams) {
  if (extraParams == null || extraParams.isEmpty) return const [];

  final properties =
      extraParams['properties'] as Map<String, dynamic>? ?? const {};
  if (properties.isEmpty) return const [];

  final requiredList = extraParams['required'] as List<dynamic>? ?? const [];
  final requiredSet = requiredList.map((e) => e.toString()).toSet();

  return jsonSchemaPropsToParams(properties, requiredSet);
}

HostParamType _jsonSchemaTypeToParamType(String type) {
  return switch (type) {
    'string' => HostParamType.string,
    'integer' => HostParamType.integer,
    'number' => HostParamType.number,
    'boolean' => HostParamType.boolean,
    'array' => HostParamType.list,
    'object' => HostParamType.map,
    _ => () {
        developer.log(
          'Unknown JSON Schema type "$type", defaulting to string',
          name: 'ToolDefinitionConverter',
        );
        return HostParamType.string;
      }(),
  };
}
