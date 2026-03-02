import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';

/// Creates paired [HostApi] + [DfRegistry] for a single bridge session.
///
/// The [HostApi] delegates DataFrame operations to the returned [DfRegistry],
/// guaranteeing shared state. Both must be passed to `HostFunctionWiring`
/// so that df_* host functions and [HostApi] methods operate on the same store.
///
/// [onChartCreated] is called when Python code calls `chart_create(config)`.
/// Each call returns a NEW pair — never cached.
({HostApi hostApi, DfRegistry dfRegistry}) createFlutterHostBundle({
  required void Function(int id, DebugChartConfig config) onChartCreated,
}) {
  final registry = DfRegistry();
  final api = _FlutterHostApi(
    dfRegistry: registry,
    onChartCreated: onChartCreated,
  );
  return (hostApi: api, dfRegistry: registry);
}

/// Flutter-side [HostApi] with isolated per-bridge state.
///
/// Created per-bridge via [createFlutterHostBundle], NOT via a Riverpod
/// Provider. Callbacks notify the owning screen/notifier of new charts
/// without requiring global state.
class _FlutterHostApi implements HostApi {
  _FlutterHostApi({
    required DfRegistry dfRegistry,
    required this.onChartCreated,
  }) : _dfRegistry = dfRegistry;

  final DfRegistry _dfRegistry;
  final _charts = <int, Map<String, Object?>>{};
  int _nextChartId = 1;

  final void Function(int id, DebugChartConfig config) onChartCreated;

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) {
    final columnNames = columns.keys.toList();
    final rowCount = columns.values.isEmpty ? 0 : columns.values.first.length;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < rowCount; i++) {
      final row = <String, dynamic>{};
      for (final col in columnNames) {
        row[col] = columns[col]![i];
      }
      rows.add(row);
    }
    return _dfRegistry.register(DataFrame(rows));
  }

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) {
    // Check existence to avoid catching ArgumentError (avoid_catching_errors).
    if (!_dfRegistry.containsHandle(handle)) return null;
    final df = _dfRegistry.get(handle);
    if (df.rows.isEmpty) return {};
    final cols = df.columns;
    return {
      for (final col in cols) col: df.columnValues(col),
    };
  }

  @override
  int registerChart(Map<String, Object?> chartConfig) {
    final id = _nextChartId++;
    _charts[id] = chartConfig;
    final config = DebugChartConfig.fromMap(chartConfig);
    onChartCreated(id, config);
    return id;
  }

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async {
    return switch (name) {
      _ => throw UnimplementedError('Host operation $name not yet supported'),
    };
  }
}
