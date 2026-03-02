import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

/// Records all [register] calls for verification.
class _RecordingBridge implements MontyBridge {
  final registered = <HostFunction>[];
  final unregistered = <String>[];

  @override
  List<HostFunctionSchema> get schemas =>
      registered.map((f) => f.schema).toList();

  @override
  void register(HostFunction function) => registered.add(function);

  @override
  void unregister(String name) => unregistered.add(name);

  @override
  Stream<BridgeEvent> execute(String code) => const Stream.empty();

  @override
  void dispose() {}
}

/// Records calls to [HostApi] methods and returns canned values.
class _FakeHostApi implements HostApi {
  final calls = <String, List<Object?>>{}; // name -> args list

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) {
    calls['registerDataFrame'] = [columns];
    return 42;
  }

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) {
    calls['getDataFrame'] = [handle];
    return {
      'x': [1, 2, 3],
    };
  }

  @override
  int registerChart(Map<String, Object?> chartConfig) {
    calls['registerChart'] = [chartConfig];
    return 7;
  }

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async {
    calls['invoke'] = [name, args];
    return 'invoked';
  }
}

void main() {
  group('HostFunctionWiring', () {
    late _RecordingBridge bridge;
    late _FakeHostApi hostApi;
    late HostFunctionWiring wiring;

    setUp(() {
      bridge = _RecordingBridge();
      hostApi = _FakeHostApi();
      wiring = HostFunctionWiring(
        hostApi: hostApi,
        dfRegistry: DfRegistry(),
      );
    });

    test('registerOnto registers df + chart + platform + introspection', () {
      wiring.registerOnto(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      // 37 df + 1 chart + 1 platform + 2 introspection = 41
      expect(bridge.registered, hasLength(41));
      expect(names, contains('df_create'));
      expect(names, contains('df_head'));
      expect(names, contains('df_filter'));
      expect(names, contains('chart_create'));
      expect(names, contains('host_invoke'));
      expect(names, contains('list_functions'));
      expect(names, contains('help'));
    });

    group('handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        wiring.registerOnto(bridge);
        byName = {
          for (final f in bridge.registered) f.schema.name: f,
        };
      });

      test('df_create creates via DfRegistry', () async {
        final result = await byName['df_create']!.handler({
          'data': <Object?>[
            <String, Object?>{'a': 1, 'b': 2},
          ],
          'columns': null,
        });

        expect(result, isA<int>());
        expect(result! as int, isPositive);
      });

      test('df_head returns rows', () async {
        // First create a DataFrame
        final handle = (await byName['df_create']!.handler({
          'data': <Object?>[
            <String, Object?>{'x': 1},
            <String, Object?>{'x': 2},
            <String, Object?>{'x': 3},
          ],
          'columns': null,
        }))! as int;

        final rows = await byName['df_head']!.handler({
          'handle': handle,
          'n': 2,
        });
        expect(rows, isA<List<Object?>>());
        expect((rows! as List<Object?>).length, 2);
      });

      test('chart_create delegates to HostApi.registerChart', () async {
        final result = await byName['chart_create']!.handler({
          'config': <String, Object?>{'type': 'bar'},
        });

        expect(result, 7);
        expect(hostApi.calls, contains('registerChart'));
      });

      test('host_invoke delegates to HostApi.invoke', () async {
        final result = await byName['host_invoke']!.handler({
          'name': 'native.clipboard',
          'args': <String, Object?>{'action': 'read'},
        });

        expect(result, 'invoked');
        expect(hostApi.calls['invoke'], [
          'native.clipboard',
          {'action': 'read'},
        ]);
      });
    });
  });
}
