import 'package:soliplex_agent/soliplex_agent.dart' show AgentApi, HostApi;
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
  HostFunctionWiring({required HostApi hostApi, AgentApi? agentApi})
      : _hostApi = hostApi,
        _agentApi = agentApi;

  final HostApi _hostApi;
  final AgentApi? _agentApi;

  /// Registers all host function categories (plus introspection builtins)
  /// onto [bridge].
  void registerOnto(MontyBridge bridge) {
    final registry = HostFunctionRegistry()
      ..addCategory('data', _dataFunctions())
      ..addCategory('chart', _chartFunctions())
      ..addCategory('platform', _platformFunctions());
    if (_agentApi != null) {
      registry.addCategory('agent', _agentFunctions());
    }
    registry.registerAllOnto(bridge);
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

  List<HostFunction> _agentFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'spawn_agent',
            description: 'Spawn an L2 sub-agent in a room.',
            params: [
              HostParam(
                name: 'room',
                type: HostParamType.string,
                description: 'Room ID to spawn the agent in.',
              ),
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'Prompt for the agent.',
              ),
            ],
          ),
          handler: (args) async {
            final room = args['room']! as String;
            final prompt = args['prompt']! as String;
            return _agentApi!.spawnAgent(room, prompt);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'wait_all',
            description: 'Wait for all agents to complete.',
            params: [
              HostParam(
                name: 'handles',
                type: HostParamType.list,
                description: 'List of agent handles.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['handles']! as List<Object?>;
            final handles = raw.cast<int>();
            return _agentApi!.waitAll(handles);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'get_result',
            description: 'Get the result of a completed agent.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Agent handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = args['handle']! as int;
            return _agentApi!.getResult(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'ask_llm',
            description: 'Spawn an agent and return its result in one call.',
            params: [
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'Prompt for the agent.',
              ),
              HostParam(
                name: 'room',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'general',
                description: 'Room ID (defaults to "general").',
              ),
            ],
          ),
          handler: (args) async {
            final prompt = args['prompt']! as String;
            final room = args['room']! as String;
            final api = _agentApi!;
            final handle = await api.spawnAgent(room, prompt);
            return api.getResult(handle);
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
