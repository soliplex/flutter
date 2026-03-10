import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Plugin exposing chart creation and update to Monty scripts.
class ChartPlugin extends MontyPlugin {
  ChartPlugin({required HostApi hostApi}) : _hostApi = hostApi;

  final HostApi _hostApi;

  @override
  String get namespace => 'chart';

  @override
  List<HostFunction> get functions => [
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
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'chart_update',
            description: 'Update an existing chart with a new configuration.',
            params: [
              HostParam(
                name: 'chart_id',
                type: HostParamType.integer,
                description: 'Chart handle returned by chart_create.',
              ),
              HostParam(
                name: 'config',
                type: HostParamType.map,
                description: 'New chart configuration.',
              ),
            ],
          ),
          handler: (args) async {
            final chartId = (args['chart_id']! as num).toInt();
            final raw = args['config'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'config', 'Expected a map.');
            }
            return _hostApi.updateChart(
              chartId,
              Map<String, Object?>.from(raw),
            );
          },
        ),
      ];
}
