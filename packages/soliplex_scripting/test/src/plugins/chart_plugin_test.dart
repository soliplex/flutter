import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('ChartPlugin', () {
    late _FakeHostApi hostApi;
    late ChartPlugin plugin;

    setUp(() {
      hostApi = _FakeHostApi();
      plugin = ChartPlugin(hostApi: hostApi);
    });

    test('namespace is chart', () {
      expect(plugin.namespace, 'chart');
    });

    test('provides 2 functions', () {
      expect(plugin.functions, hasLength(2));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['chart_create', 'chart_update']));
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['chart_create', 'chart_update']));
    });

    group('handlers', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('chart_create delegates to HostApi.registerChart', () async {
        final result = await byName['chart_create']!.handler({
          'config': <String, Object?>{'type': 'bar'},
        });

        expect(result, 7);
        expect(hostApi.calls, contains('registerChart'));
      });

      test('chart_create rejects non-map config', () async {
        await expectLater(
          byName['chart_create']!.handler({'config': 'not a map'}),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('chart_update delegates to HostApi.updateChart', () async {
        final result = await byName['chart_update']!.handler({
          'chart_id': 3,
          'config': <String, Object?>{'type': 'line'},
        });

        expect(result, isTrue);
        expect(hostApi.calls, contains('updateChart'));
      });

      test('chart_update rejects non-map config', () async {
        await expectLater(
          byName['chart_update']!.handler({'chart_id': 1, 'config': 'bad'}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}

class _FakeHostApi implements HostApi {
  final calls = <String, List<Object?>>{};

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) => 0;

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => null;

  @override
  int registerChart(Map<String, Object?> chartConfig) {
    calls['registerChart'] = [chartConfig];
    return 7;
  }

  @override
  bool updateChart(int chartId, Map<String, Object?> chartConfig) {
    calls['updateChart'] = [chartId, chartConfig];
    return true;
  }

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async => null;
}
