import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';

/// Converts a Dart value to a Python literal string.
String _toPythonLiteral(Object? value) {
  if (value == null) return 'None';
  if (value is bool) return value ? 'True' : 'False';
  if (value is num) return value.toString();
  if (value is String) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
    return "'$escaped'";
  }
  if (value is List) {
    return '[${value.map(_toPythonLiteral).join(', ')}]';
  }
  if (value is Map) {
    final entries = value.entries
        .map((e) => '${_toPythonLiteral(e.key)}: ${_toPythonLiteral(e.value)}')
        .join(', ');
    return '{$entries}';
  }
  return "'$value'";
}

/// Executes Monty-compatible Python schema validators at runtime.
///
/// Fetched Python code (generated from backend Pydantic models) is cached
/// per schema name. [validate] composes the code with raw JSON input and
/// runs it through [MontyPlatform.run], returning a typed dict.
class SchemaExecutor {
  SchemaExecutor({MontyPlatform? platform}) : _explicitPlatform = platform;

  final MontyPlatform? _explicitPlatform;
  final Map<String, String> _schemas = {};

  MontyPlatform get _platform => _explicitPlatform ?? MontyPlatform.instance;

  /// Names of all loaded schemas.
  Iterable<String> get schemaNames => _schemas.keys;

  /// Whether any schemas have been loaded.
  bool get hasSchemas => _schemas.isNotEmpty;

  /// Caches Python validator code keyed by schema name.
  ///
  /// Each value should be a Monty-compatible Python function definition
  /// named `validate_<schemaName>(raw)` that returns a dict.
  void loadSchemas(Map<String, String> schemas) {
    _schemas.addAll(schemas);
  }

  /// Validates [rawJson] against the named schema.
  ///
  /// Composes Python code:
  /// ```python
  /// raw = __input__
  /// <schema validator function>
  /// validate_<schemaName>(raw)
  /// ```
  ///
  /// Returns the validated dict from the Python function.
  /// Throws [ArgumentError] if the schema name is unknown.
  /// Throws [MontyException] if the Python code fails.
  Future<Map<String, Object?>> validate(
    String schemaName,
    Map<String, Object?> rawJson,
  ) async {
    final schemaCode = _schemas[schemaName];
    if (schemaCode == null) {
      throw ArgumentError.value(schemaName, 'schemaName', 'Unknown schema');
    }

    final literal = _toPythonLiteral(rawJson);
    final code = 'raw = $literal\n$schemaCode\nvalidate_$schemaName(raw)';

    final result = await _platform.run(code);

    if (result.isError) {
      throw result.error!;
    }

    return result.value! as Map<String, Object?>;
  }
}
