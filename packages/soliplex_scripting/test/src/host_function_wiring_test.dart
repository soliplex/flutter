import 'package:soliplex_agent/soliplex_agent.dart' show FakeAgentApi, HostApi;
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

    group('agent category absent when agentApi is null', () {
      test('does not register agent functions', () {
        final b = _RecordingBridge();
        HostFunctionWiring(hostApi: _FakeHostApi()).registerOnto(b);

        final names = b.registered.map((f) => f.schema.name).toSet();
        expect(names, isNot(contains('spawn_agent')));
        expect(names, isNot(contains('wait_all')));
        expect(names, isNot(contains('get_result')));
        expect(names, isNot(contains('ask_llm')));
        expect(b.registered, hasLength(6)); // 4 domain + 2 introspection
      });
    });
  });

  group('HostFunctionWiring with AgentApi', () {
    late _RecordingBridge bridge;
    late _FakeHostApi hostApi;
    late FakeAgentApi agentApi;
    late HostFunctionWiring wiring;

    setUp(() {
      bridge = _RecordingBridge();
      hostApi = _FakeHostApi();
      agentApi = FakeAgentApi(
        spawnResult: 10,
        getResultResult: 'agent output',
        waitAllResult: ['r1', 'r2'],
      );
      wiring = HostFunctionWiring(hostApi: hostApi, agentApi: agentApi);
    });

    test('registers agent functions when agentApi provided', () {
      wiring.registerOnto(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll([
          'spawn_agent',
          'wait_all',
          'get_result',
          'ask_llm',
        ]),
      );
      // 4 domain + 4 agent + 2 introspection
      expect(bridge.registered, hasLength(10));
    });

    group('agent handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        wiring.registerOnto(bridge);
        byName = {
          for (final f in bridge.registered) f.schema.name: f,
        };
      });

      test('spawn_agent delegates to AgentApi.spawnAgent', () async {
        final result = await byName['spawn_agent']!.handler({
          'room': 'weather',
          'prompt': 'Is it raining?',
        });

        expect(result, 10);
        expect(
          agentApi.calls['spawnAgent'],
          ['weather', 'Is it raining?', null],
        );
      });

      test('wait_all delegates to AgentApi.waitAll', () async {
        final result = await byName['wait_all']!.handler({
          'handles': <Object?>[1, 2],
        });

        expect(result, ['r1', 'r2']);
        expect(agentApi.calls['waitAll'], [
          [1, 2],
          null,
        ]);
      });

      test('get_result delegates to AgentApi.getResult', () async {
        final result = await byName['get_result']!.handler({
          'handle': 5,
        });

        expect(result, 'agent output');
        expect(agentApi.calls['getResult'], [5, null]);
      });

      test('ask_llm spawns agent and gets result', () async {
        final result = await byName['ask_llm']!.handler({
          'prompt': 'What is 2+2?',
          'room': 'math',
        });

        expect(result, 'agent output');
        expect(agentApi.calls['spawnAgent'], ['math', 'What is 2+2?', null]);
        expect(agentApi.calls['getResult'], [10, null]);
      });

      test('ask_llm uses "general" as default room', () async {
        await byName['ask_llm']!.handler({
          'prompt': 'Hello',
          'room': 'general',
        });

        expect(agentApi.calls['spawnAgent']![0], 'general');
      });

      test('spawn_agent schema has correct params', () {
        final schema = byName['spawn_agent']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'room');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[1].name, 'prompt');
        expect(schema.params[1].type, HostParamType.string);
      });

      test('wait_all schema has list param', () {
        final schema = byName['wait_all']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handles');
        expect(schema.params[0].type, HostParamType.list);
      });

      test('get_result schema has integer param', () {
        final schema = byName['get_result']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
      });

      test('ask_llm schema has string prompt and optional room', () {
        final schema = byName['ask_llm']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'prompt');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[0].isRequired, isTrue);
        expect(schema.params[1].name, 'room');
        expect(schema.params[1].type, HostParamType.string);
        expect(schema.params[1].isRequired, isFalse);
        expect(schema.params[1].defaultValue, 'general');
      });
    });
  });
}
