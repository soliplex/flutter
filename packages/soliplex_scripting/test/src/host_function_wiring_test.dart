import 'dart:async';

import 'package:soliplex_agent/soliplex_agent.dart'
    show
        AgentApi,
        AgentFailure,
        AgentResult,
        AgentSuccess,
        AgentTimedOut,
        FailureReason,
        FakeAgentApi,
        FakeBlackboardApi,
        HostApi;
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
  bool updateChart(int chartId, Map<String, Object?> chartConfig) {
    calls['updateChart'] = [chartId, chartConfig];
    return true;
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
      wiring = HostFunctionWiring(hostApi: hostApi, dfRegistry: DfRegistry());
    });

    test('registerOnto registers df + chart + platform + introspection', () {
      wiring.registerOnto(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      // 37 df + 2 chart + 4 platform + 2 introspection = 45
      expect(bridge.registered, hasLength(45));
      expect(names, contains('df_create'));
      expect(names, contains('df_head'));
      expect(names, contains('df_filter'));
      expect(names, contains('chart_create'));
      expect(names, contains('chart_update'));
      expect(names, contains('host_invoke'));
      expect(names, contains('sleep'));
      expect(names, contains('fetch'));
      expect(names, contains('log'));
      expect(names, contains('list_functions'));
      expect(names, contains('help'));
    });

    group('handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        wiring.registerOnto(bridge);
        byName = {for (final f in bridge.registered) f.schema.name: f};
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

      test('log delegates to HostApi.invoke with log namespace', () async {
        final result = await byName['log']!.handler({
          'message': 'hello world',
          'level': 'info',
        });

        expect(result, 'invoked');
        expect(hostApi.calls['invoke']![0], 'log');
        final logArgs = hostApi.calls['invoke']![1]! as Map<String, Object?>;
        expect(logArgs['message'], 'hello world');
        expect(logArgs['level'], 'info');
      });

      test('log defaults level to info', () {
        final schema = byName['log']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'message');
        expect(schema.params[1].name, 'level');
        expect(schema.params[1].defaultValue, 'info');
      });

      test('fetch schema has url, method, headers, body', () {
        final schema = byName['fetch']!.schema;
        expect(schema.params, hasLength(4));
        expect(schema.params[0].name, 'url');
        expect(schema.params[0].isRequired, isTrue);
        expect(schema.params[1].name, 'method');
        expect(schema.params[1].defaultValue, 'GET');
        expect(schema.params[2].name, 'headers');
        expect(schema.params[2].isRequired, isFalse);
        expect(schema.params[3].name, 'body');
        expect(schema.params[3].isRequired, isFalse);
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
        expect(
          b.registered,
          hasLength(45),
        ); // 37 df + 2 chart + 4 platform + 2 introspection
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
          'agent_watch',
          'cancel_agent',
          'agent_status',
          'ask_llm',
        ]),
      );
      // 37 df + 2 chart + 4 platform + 7 agent + 2 introspection = 52
      expect(bridge.registered, hasLength(52));
    });

    group('agent handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        wiring.registerOnto(bridge);
        byName = {for (final f in bridge.registered) f.schema.name: f};
      });

      test('spawn_agent delegates to AgentApi.spawnAgent', () async {
        final result = await byName['spawn_agent']!.handler({
          'room': 'weather',
          'prompt': 'Is it raining?',
        });

        expect(result, 10);
        expect(agentApi.calls['spawnAgent'], [
          'weather',
          'Is it raining?',
          null,
          null,
        ]);
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
        final result = await byName['get_result']!.handler({'handle': 5});

        expect(result, 'agent output');
        expect(agentApi.calls['getResult'], [5, null]);
      });

      test('ask_llm spawns agent and gets result', () async {
        final result = await byName['ask_llm']!.handler({
          'prompt': 'What is 2+2?',
          'room': 'math',
        });

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['text'], 'agent output');
        expect(map['thread_id'], 'fake-thread-id');
        expect(agentApi.calls['spawnAgent'], [
          'math',
          'What is 2+2?',
          null,
          null,
        ]);
        expect(agentApi.calls['getResult'], [10, null]);
      });

      test('agent_watch returns success dict', () async {
        agentApi.watchResult = const AgentSuccess(
          threadKey: (serverId: 's', roomId: 'r', threadId: 't'),
          output: 'done!',
          runId: 'run-1',
        );

        final result = await byName['agent_watch']!.handler({'handle': 10});

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['status'], 'success');
        expect(map['output'], 'done!');
        expect(agentApi.calls['watchAgent']![0], 10);
      });

      test('agent_watch returns failed dict', () async {
        agentApi.watchResult = const AgentFailure(
          threadKey: (serverId: 's', roomId: 'r', threadId: 't'),
          reason: FailureReason.serverError,
          error: 'boom',
          partialOutput: 'partial',
        );

        final result = await byName['agent_watch']!.handler({'handle': 5});

        final map = result! as Map<String, Object?>;
        expect(map['status'], 'failed');
        expect(map['reason'], 'serverError');
        expect(map['error'], 'boom');
        expect(map['partial_output'], 'partial');
      });

      test('agent_watch returns timed_out dict', () async {
        agentApi.watchResult = const AgentTimedOut(
          threadKey: (serverId: 's', roomId: 'r', threadId: 't'),
          elapsed: Duration(seconds: 15),
        );

        final result = await byName['agent_watch']!.handler({'handle': 3});

        final map = result! as Map<String, Object?>;
        expect(map['status'], 'timed_out');
        expect(map['elapsed_seconds'], 15);
      });

      test('agent_watch delegates to AgentApi.watchAgent', () async {
        await byName['agent_watch']!.handler({
          'handle': 7,
        });

        expect(agentApi.calls['watchAgent']![0], 7);
      });

      test('cancel_agent delegates to AgentApi.cancelAgent', () async {
        final result = await byName['cancel_agent']!.handler({'handle': 8});

        expect(result, isTrue);
        expect(agentApi.calls['cancelAgent'], [8]);
      });

      test('cancel_agent schema has handle param', () {
        final schema = byName['cancel_agent']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
      });

      test('agent_status delegates to AgentApi.agentStatus', () async {
        agentApi.statusResult = 'completed';

        final result = await byName['agent_status']!.handler({'handle': 3});

        expect(result, 'completed');
        expect(agentApi.calls['agentStatus'], [3]);
      });

      test('agent_status schema has handle param', () {
        final schema = byName['agent_status']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
      });

      test('ask_llm uses "general" as default room', () async {
        await byName['ask_llm']!.handler({
          'prompt': 'Hello',
          'room': 'general',
        });

        expect(agentApi.calls['spawnAgent']![0], 'general');
      });

      test('ask_llm passes thread_id for continuity', () async {
        await byName['ask_llm']!.handler({
          'prompt': 'Continue',
          'room': 'math',
          'thread_id': 'tid-123',
        });

        expect(agentApi.calls['spawnAgent']![2], 'tid-123');
      });

      test('spawn_agent schema has room, prompt, and optional thread_id', () {
        final schema = byName['spawn_agent']!.schema;
        expect(schema.params, hasLength(3));
        expect(schema.params[0].name, 'room');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[0].isRequired, isTrue);
        expect(schema.params[1].name, 'prompt');
        expect(schema.params[1].type, HostParamType.string);
        expect(schema.params[1].isRequired, isTrue);
        expect(schema.params[2].name, 'thread_id');
        expect(schema.params[2].type, HostParamType.string);
        expect(schema.params[2].isRequired, isFalse);
      });

      test('spawn_agent passes thread_id when provided', () async {
        await byName['spawn_agent']!.handler({
          'room': 'weather',
          'prompt': 'Continue',
          'thread_id': 'tid-456',
        });

        expect(agentApi.calls['spawnAgent']![2], 'tid-456');
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

      test('agent_watch schema has handle and optional timeout', () {
        final schema = byName['agent_watch']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
        expect(schema.params[0].isRequired, isTrue);
        expect(schema.params[1].name, 'timeout_seconds');
        expect(schema.params[1].type, HostParamType.number);
        expect(schema.params[1].isRequired, isFalse);
      });

      test('ask_llm schema has prompt, room, and thread_id', () {
        final schema = byName['ask_llm']!.schema;
        expect(schema.params, hasLength(3));
        expect(schema.params[0].name, 'prompt');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[0].isRequired, isTrue);
        expect(schema.params[1].name, 'room');
        expect(schema.params[1].type, HostParamType.string);
        expect(schema.params[1].isRequired, isFalse);
        expect(schema.params[1].defaultValue, 'general');
        expect(schema.params[2].name, 'thread_id');
        expect(schema.params[2].type, HostParamType.string);
        expect(schema.params[2].isRequired, isFalse);
      });
    });
  });

  group('HostFunctionWiring with BlackboardApi', () {
    late _RecordingBridge bridge;
    late _FakeHostApi hostApi;
    late FakeBlackboardApi blackboardApi;
    late HostFunctionWiring wiring;

    setUp(() {
      bridge = _RecordingBridge();
      hostApi = _FakeHostApi();
      blackboardApi = FakeBlackboardApi();
      wiring = HostFunctionWiring(
        hostApi: hostApi,
        blackboardApi: blackboardApi,
      );
    });

    test('registers blackboard functions when blackboardApi provided', () {
      wiring.registerOnto(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll(['blackboard_write', 'blackboard_read', 'blackboard_keys']),
      );
      // 37 df + 2 chart + 4 platform + 3 blackboard + 2 introspection = 48
      expect(bridge.registered, hasLength(48));
    });

    test('blackboard category absent when blackboardApi is null', () {
      final b = _RecordingBridge();
      HostFunctionWiring(hostApi: _FakeHostApi()).registerOnto(b);

      final names = b.registered.map((f) => f.schema.name).toSet();
      expect(names, isNot(contains('blackboard_write')));
      expect(names, isNot(contains('blackboard_read')));
      expect(names, isNot(contains('blackboard_keys')));
    });

    group('blackboard handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        wiring.registerOnto(bridge);
        byName = {for (final f in bridge.registered) f.schema.name: f};
      });

      test('blackboard_write delegates to BlackboardApi.write', () async {
        await byName['blackboard_write']!.handler({
          'key': 'score',
          'value': 42,
        });

        expect(blackboardApi.store['score'], 42);
        expect(blackboardApi.calls['write'], ['score', 42]);
      });

      test('blackboard_write accepts null value', () async {
        await byName['blackboard_write']!.handler({
          'key': 'cleared',
          'value': null,
        });

        expect(blackboardApi.store['cleared'], isNull);
        expect(blackboardApi.calls['write'], ['cleared', null]);
      });

      test('blackboard_read delegates to BlackboardApi.read', () async {
        blackboardApi.store['greeting'] = 'hello';

        final result = await byName['blackboard_read']!.handler({
          'key': 'greeting',
        });

        expect(result, 'hello');
        expect(blackboardApi.calls['read'], ['greeting']);
      });

      test('blackboard_read returns null for missing key', () async {
        final result = await byName['blackboard_read']!.handler({
          'key': 'absent',
        });

        expect(result, isNull);
      });

      test('blackboard_keys delegates to BlackboardApi.keys', () async {
        blackboardApi.store['a'] = 1;
        blackboardApi.store['b'] = 2;

        final result = await byName['blackboard_keys']!.handler({});

        expect(result, isA<List<String>>());
        expect(result! as List<String>, containsAll(['a', 'b']));
      });

      test('blackboard_keys returns empty list for empty store', () async {
        final result = await byName['blackboard_keys']!.handler({});

        expect(result, <String>[]);
      });

      test('blackboard_write schema has key and optional value', () {
        final schema = byName['blackboard_write']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'key');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[0].isRequired, isTrue);
        expect(schema.params[1].name, 'value');
        expect(schema.params[1].type, HostParamType.any);
        expect(schema.params[1].isRequired, isFalse);
      });

      test('blackboard_read schema has key param', () {
        final schema = byName['blackboard_read']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'key');
        expect(schema.params[0].type, HostParamType.string);
      });

      test('blackboard_keys schema has no params', () {
        final schema = byName['blackboard_keys']!.schema;
        expect(schema.params, isEmpty);
      });
    });
  });

  group('agent timeout', () {
    test('ask_llm times out with configured agentTimeout', () async {
      final slowApi = _NeverResolvingAgentApi();
      final b = _RecordingBridge();
      HostFunctionWiring(
        hostApi: _FakeHostApi(),
        agentApi: slowApi,
        agentTimeout: const Duration(milliseconds: 50),
      ).registerOnto(b);

      final byName = {for (final f in b.registered) f.schema.name: f};
      await expectLater(
        byName['ask_llm']!.handler({'prompt': 'slow', 'room': 'general'}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('get_result times out with configured agentTimeout', () async {
      final slowApi = _NeverResolvingAgentApi();
      final b = _RecordingBridge();
      HostFunctionWiring(
        hostApi: _FakeHostApi(),
        agentApi: slowApi,
        agentTimeout: const Duration(milliseconds: 50),
      ).registerOnto(b);

      final byName = {for (final f in b.registered) f.schema.name: f};
      await expectLater(
        byName['get_result']!.handler({'handle': 1}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('agent_watch times out with configured agentTimeout', () async {
      final slowApi = _NeverResolvingAgentApi();
      final b = _RecordingBridge();
      HostFunctionWiring(
        hostApi: _FakeHostApi(),
        agentApi: slowApi,
        agentTimeout: const Duration(milliseconds: 50),
      ).registerOnto(b);

      final byName = {for (final f in b.registered) f.schema.name: f};
      await expectLater(
        byName['agent_watch']!.handler({'handle': 1}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('wait_all times out with configured agentTimeout', () async {
      final slowApi = _NeverResolvingAgentApi();
      final b = _RecordingBridge();
      HostFunctionWiring(
        hostApi: _FakeHostApi(),
        agentApi: slowApi,
        agentTimeout: const Duration(milliseconds: 50),
      ).registerOnto(b);

      final byName = {for (final f in b.registered) f.schema.name: f};
      await expectLater(
        byName['wait_all']!.handler({
          'handles': <Object?>[1, 2],
        }),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}

/// Agent API that never resolves any future — for timeout testing.
class _NeverResolvingAgentApi implements AgentApi {
  @override
  Future<int> spawnAgent(
    String roomId,
    String prompt, {
    String? threadId,
    Duration? timeout,
  }) =>
      Completer<int>().future;

  @override
  String getThreadId(int handle) => 'never';

  @override
  Future<List<String>> waitAll(List<int> handles, {Duration? timeout}) =>
      Completer<List<String>>().future;

  @override
  Future<String> getResult(int handle, {Duration? timeout}) =>
      Completer<String>().future;

  @override
  Future<AgentResult> watchAgent(int handle, {Duration? timeout}) =>
      Completer<AgentResult>().future;

  @override
  Future<bool> cancelAgent(int handle) => Completer<bool>().future;

  @override
  String agentStatus(int handle) => 'running';
}
