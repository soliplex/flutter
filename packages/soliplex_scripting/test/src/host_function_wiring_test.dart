import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
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
      wiring = HostFunctionWiring(hostApi: hostApi);
    });

    test('registerOnto registers the 4 host functions + introspection', () {
      wiring.registerOnto(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      // 4 domain functions + 2 introspection builtins
      expect(names, containsAll(['df_create', 'df_get', 'chart_create']));
      expect(names, contains('host_invoke'));
      expect(names, contains('list_functions'));
      expect(names, contains('help'));
      expect(bridge.registered, hasLength(6));
    });

    test('registers correct function names', () {
      wiring.registerOnto(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toList();
      // Domain functions appear before introspection builtins.
      expect(names.sublist(0, 4), [
        'df_create',
        'df_get',
        'chart_create',
        'host_invoke',
      ]);
    });

    group('handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        wiring.registerOnto(bridge);
        byName = {
          for (final f in bridge.registered) f.schema.name: f,
        };
      });

      test('df_create delegates to HostApi.registerDataFrame', () async {
        final result = await byName['df_create']!.handler({
          'columns': <String, Object?>{
            'a': [1, 2],
          },
        });

        expect(result, 42);
        expect(hostApi.calls, contains('registerDataFrame'));
      });

      test('df_get delegates to HostApi.getDataFrame', () async {
        final result = await byName['df_get']!.handler({'handle': 5});

        expect(result, isA<Map<String, List<Object?>>>());
        expect(hostApi.calls['getDataFrame'], [5]);
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
