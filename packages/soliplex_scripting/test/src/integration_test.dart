import 'dart:async';
import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart' show FakeAgentApi, HostApi;
import 'package:soliplex_client/soliplex_client.dart'
    show ToolCallInfo, ToolRegistry;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

const ThreadKey _key = (serverId: 's', roomId: 'r', threadId: 't');

/// Records calls and returns canned values.
class _FakeHostApi implements HostApi {
  final calls = <String, List<Object?>>{}; // method -> args

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) {
    calls['registerDataFrame'] = [columns];
    return 99;
  }

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) {
    calls['getDataFrame'] = [handle];
    return {
      'col': [1, 2],
    };
  }

  @override
  int registerChart(Map<String, Object?> chartConfig) {
    calls['registerChart'] = [chartConfig];
    return 55;
  }

  @override
  Future<Object?> invoke(
    String name,
    Map<String, Object?> args,
  ) async {
    calls['invoke'] = [name, args];
    return 'ok';
  }
}

/// A bridge that simulates executing code by:
/// 1. Looking up registered host functions matching Python calls.
/// 2. Emitting lifecycle events and calling the handler.
/// 3. Returning the handler result as text output.
class _ScriptableBridge implements MontyBridge {
  final _functions = <String, HostFunction>{};

  @override
  List<HostFunctionSchema> get schemas =>
      _functions.values.map((f) => f.schema).toList();

  @override
  void register(HostFunction function) {
    _functions[function.schema.name] = function;
  }

  @override
  void unregister(String name) {
    _functions.remove(name);
  }

  @override
  Stream<BridgeEvent> execute(String code) {
    final controller = StreamController<BridgeEvent>();
    unawaited(_run(code, controller));
    return controller.stream;
  }

  Future<void> _run(
    String code,
    StreamController<BridgeEvent> controller,
  ) async {
    controller
      ..add(const BridgeRunStarted(threadId: 't', runId: 'r'))
      ..add(const BridgeStepStarted(stepId: 'step-1'));

    // Parse a simple `fn(json_args)` call from the code.
    final match = RegExp(r'(\w+)\((.+)\)').firstMatch(code);
    if (match != null) {
      final fnName = match.group(1)!;
      final argsJson = match.group(2)!;
      final fn = _functions[fnName];

      if (fn != null) {
        controller
          ..add(BridgeToolCallStart(callId: 'c1', name: fnName))
          ..add(BridgeToolCallArgs(callId: 'c1', delta: argsJson));

        final args = Map<String, Object?>.from(
          jsonDecode(argsJson) as Map,
        );
        final result = await fn.handler(args);
        final resultStr = jsonEncode(result);

        controller
          ..add(const BridgeToolCallEnd(callId: 'c1'))
          ..add(BridgeToolCallResult(callId: 'c1', result: resultStr));
      }
    }

    controller
      ..add(const BridgeStepFinished(stepId: 'step-1'))
      ..add(const BridgeTextStart(messageId: 'msg-1'))
      ..add(
        const BridgeTextContent(messageId: 'msg-1', delta: 'done'),
      )
      ..add(const BridgeTextEnd(messageId: 'msg-1'))
      ..add(const BridgeRunFinished(threadId: 't', runId: 'r'));
    await controller.close();
  }

  @override
  void dispose() {}
}

void main() {
  group('Integration', () {
    test('executor → bridge → host function → result', () async {
      final hostApi = _FakeHostApi();
      final wiring = HostFunctionWiring(hostApi: hostApi);
      final cache = BridgeCache(
        limit: 2,
        bridgeFactory: _ScriptableBridge.new,
      );
      final executor = MontyToolExecutor(
        threadKey: _key,
        bridgeCache: cache,
        hostWiring: wiring,
      );

      final toolCall = ToolCallInfo(
        id: 'tc-integration',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({
          'code': 'df_create({"columns": {"x": [1, 2, 3]}})',
        }),
      );

      final result = await executor.execute(toolCall);

      expect(hostApi.calls, contains('registerDataFrame'));
      expect(
        hostApi.calls['registerDataFrame']![0],
        {
          'x': [1, 2, 3],
        },
      );
      expect(result, 'done');
      expect(cache.isExecuting(_key), isFalse);

      cache.disposeAll();
    });

    test('resolver + executor end-to-end', () async {
      final hostApi = _FakeHostApi();
      final wiring = HostFunctionWiring(hostApi: hostApi);
      final cache = BridgeCache(
        limit: 2,
        bridgeFactory: _ScriptableBridge.new,
      );
      final executor = MontyToolExecutor(
        threadKey: _key,
        bridgeCache: cache,
        hostWiring: wiring,
      );

      Future<ToolRegistry> inner(String roomId) async {
        return const ToolRegistry();
      }

      final resolver = ScriptingToolRegistryResolver(
        inner: inner,
        executor: executor,
      );

      final registry = await resolver.call('room-1');

      expect(
        registry.contains(PythonExecutorTool.toolName),
        isTrue,
      );

      final toolCall = ToolCallInfo(
        id: 'tc-e2e',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({
          'code': 'chart_create({"config": {"type": "line"}})',
        }),
      );

      final result = await registry.execute(toolCall);
      expect(result, 'done');
      expect(hostApi.calls, contains('registerChart'));

      cache.disposeAll();
    });
  });

  group('Integration: agent host functions', () {
    test('spawn_agent via executor → bridge → AgentApi', () async {
      final hostApi = _FakeHostApi();
      final agentApi = FakeAgentApi(
        spawnResult: 42,
        getResultResult: 'agent says hello',
      );
      final wiring = HostFunctionWiring(
        hostApi: hostApi,
        agentApi: agentApi,
      );
      final cache = BridgeCache(
        limit: 2,
        bridgeFactory: _ScriptableBridge.new,
      );
      final executor = MontyToolExecutor(
        threadKey: _key,
        bridgeCache: cache,
        hostWiring: wiring,
      );

      final toolCall = ToolCallInfo(
        id: 'tc-agent-spawn',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({
          'code': 'spawn_agent({"room": "echo", "prompt": "hi"})',
        }),
      );

      final result = await executor.execute(toolCall);
      expect(result, 'done');
      expect(agentApi.calls, contains('spawnAgent'));
      expect(agentApi.calls['spawnAgent']![0], 'echo');
      expect(agentApi.calls['spawnAgent']![1], 'hi');

      cache.disposeAll();
    });

    test('ask_llm via executor → bridge → spawn + getResult', () async {
      final hostApi = _FakeHostApi();
      final agentApi = FakeAgentApi(
        spawnResult: 7,
        getResultResult: 'the answer is 42',
      );
      final wiring = HostFunctionWiring(
        hostApi: hostApi,
        agentApi: agentApi,
      );
      final cache = BridgeCache(
        limit: 2,
        bridgeFactory: _ScriptableBridge.new,
      );
      final executor = MontyToolExecutor(
        threadKey: _key,
        bridgeCache: cache,
        hostWiring: wiring,
      );

      final toolCall = ToolCallInfo(
        id: 'tc-agent-ask',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({
          'code': 'ask_llm({"prompt": "what is 6*7?", "room": "math"})',
        }),
      );

      final result = await executor.execute(toolCall);
      expect(result, 'done');
      // ask_llm should have called spawnAgent then getResult.
      expect(agentApi.calls, contains('spawnAgent'));
      expect(agentApi.calls['spawnAgent']![0], 'math');
      expect(agentApi.calls['spawnAgent']![1], 'what is 6*7?');
      expect(agentApi.calls, contains('getResult'));
      expect(agentApi.calls['getResult']![0], 7);

      cache.disposeAll();
    });

    test('wait_all via executor → bridge → AgentApi', () async {
      final hostApi = _FakeHostApi();
      final agentApi = FakeAgentApi(
        waitAllResult: ['result-a', 'result-b'],
      );
      final wiring = HostFunctionWiring(
        hostApi: hostApi,
        agentApi: agentApi,
      );
      final cache = BridgeCache(
        limit: 2,
        bridgeFactory: _ScriptableBridge.new,
      );
      final executor = MontyToolExecutor(
        threadKey: _key,
        bridgeCache: cache,
        hostWiring: wiring,
      );

      final toolCall = ToolCallInfo(
        id: 'tc-agent-wait',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({
          'code': 'wait_all({"handles": [1, 2]})',
        }),
      );

      final result = await executor.execute(toolCall);
      expect(result, 'done');
      expect(agentApi.calls, contains('waitAll'));
      expect(agentApi.calls['waitAll']![0], [1, 2]);

      cache.disposeAll();
    });

    test('agent functions absent when no agentApi', () async {
      final hostApi = _FakeHostApi();
      final wiring = HostFunctionWiring(hostApi: hostApi);
      final bridge = _ScriptableBridge();
      wiring.registerOnto(bridge);

      final names = bridge.schemas.map((s) => s.name).toSet();
      expect(names, isNot(contains('spawn_agent')));
      expect(names, isNot(contains('ask_llm')));
      expect(names, isNot(contains('wait_all')));
      expect(names, isNot(contains('get_result')));
    });
  });
}
