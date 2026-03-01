import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Wires [HostApi] methods to [HostFunction]s and registers them onto a
/// [MontyBridge] via a [HostFunctionRegistry].
///
/// Each category maps Python-callable function names to the corresponding
/// [HostApi] method:
///
/// | Category | Python name    | HostApi method       |
/// |----------|---------------|----------------------|
/// | data     | `df_create`   | `registerDataFrame`  |
/// | data     | `df_get`      | `getDataFrame`       |
/// | chart    | `chart_create`| `registerChart`      |
/// | platform | `host_invoke` | `invoke`             |
class HostFunctionWiring {
  HostFunctionWiring({required HostApi hostApi}) : _hostApi = hostApi;

  final HostApi _hostApi;

  /// Registers all host function categories (plus introspection builtins)
  /// onto [bridge].
  void registerOnto(MontyBridge bridge) {
    (HostFunctionRegistry()
          ..addCategory('data', _dataFunctions())
          ..addCategory('chart', _chartFunctions())
          ..addCategory('platform', _platformFunctions()))
        .registerAllOnto(bridge);
  }

  List<HostFunction> _dataFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'df_create',
            description: 'Create a DataFrame from column data.',
            params: [
              HostParam(
                name: 'columns',
                type: HostParamType.map,
                description: 'Column name to values mapping.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['columns'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'columns', 'Expected a map.');
            }
            return _hostApi.registerDataFrame(_castColumns(raw));
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'df_get',
            description: 'Retrieve a DataFrame by handle.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Integer handle returned by df_create.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = args['handle'];
            if (handle is! int) {
              throw ArgumentError.value(
                handle,
                'handle',
                'Expected an integer.',
              );
            }
            return _hostApi.getDataFrame(handle);
          },
        ),
      ];

  List<HostFunction> _chartFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'chart_create',
            description: 'Create a chart from a configuration map.',
            params: [
              HostParam(
                name: 'config',
                type: HostParamType.map,
                description: 'Chart configuration.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['config'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'config', 'Expected a map.');
            }
            return _hostApi.registerChart(Map<String, Object?>.from(raw));
          },
        ),
      ];

  List<HostFunction> _platformFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'host_invoke',
            description: 'Invoke a named host operation.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Namespaced operation name.',
              ),
              HostParam(
                name: 'args',
                type: HostParamType.map,
                description: 'Arguments for the operation.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name'];
            if (name is! String) {
              throw ArgumentError.value(name, 'name', 'Expected a string.');
            }
            final rawArgs = args['args'];
            if (rawArgs is! Map) {
              throw ArgumentError.value(rawArgs, 'args', 'Expected a map.');
            }
            return _hostApi.invoke(name, Map<String, Object?>.from(rawArgs));
          },
        ),
      ];

  /// Casts a raw map (from Python dict) to the typed column map that
  /// [HostApi.registerDataFrame] expects.
  ///
  /// Throws [ArgumentError] if keys are not strings or values are not lists.
  static Map<String, List<Object?>> _castColumns(Map<dynamic, dynamic> raw) {
    final result = <String, List<Object?>>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(
          entry.key,
          'columns key',
          'Expected a string.',
        );
      }
      if (entry.value is! List) {
        throw ArgumentError.value(
          entry.value,
          'columns["${entry.key}"]',
          'Expected a list.',
        );
      }
      result[entry.key as String] = List<Object?>.from(entry.value as List);
    }
    return result;
  }
}
