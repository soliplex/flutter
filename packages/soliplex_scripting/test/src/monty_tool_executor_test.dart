import 'dart:async';
import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

const ThreadKey _key = (serverId: 's', roomId: 'r', threadId: 't');

/// A bridge that returns a configurable event stream and tracks registrations.
class _FakeBridge implements MontyBridge {
  _FakeBridge({Stream<BridgeEvent>? events})
      : _events = events ?? const Stream.empty();

  final Stream<BridgeEvent> _events;
  final registered = <HostFunction>[];
  bool disposed = false;

  @override
  List<HostFunctionSchema> get schemas =>
      registered.map((f) => f.schema).toList();

  @override
  void register(HostFunction function) => registered.add(function);

  @override
  void unregister(String name) {
    registered.removeWhere((f) => f.schema.name == name);
  }

  @override
  Stream<BridgeEvent> execute(String code) => _events;

  @override
  void dispose() => disposed = true;
}

/// Minimal HostApi that does nothing — wiring isn't the focus here.
class _StubHostApi implements HostApi {
  @override
  int registerDataFrame(Map<String, List<Object?>> columns) => 1;

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => null;

  @override
  int registerChart(Map<String, Object?> chartConfig) => 1;

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async => null;
}

ToolCallInfo _toolCall(String code) => ToolCallInfo(
      id: 'tc-1',
      name: 'execute_python',
      arguments: jsonEncode({'code': code}),
    );

void main() {
  group('MontyToolExecutor', () {
    group('_extractCode', () {
      test('extracts code from valid JSON', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeTextContent(messageId: 'm', delta: 'ok'),
          const BridgeRunFinished(threadId: 't', runId: 'r'),
        ]);
        final bridge = _FakeBridge(events: events);
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        final result = await executor.execute(_toolCall('print("hi")'));
        expect(result, 'ok');
      });

      test('throws ArgumentError on invalid JSON', () async {
        final bridge = _FakeBridge();
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        expect(
          () => executor.execute(
            const ToolCallInfo(
              id: 'tc-1',
              name: 'execute_python',
              arguments: 'not json',
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when code key is missing', () async {
        final bridge = _FakeBridge();
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        expect(
          () => executor.execute(
            ToolCallInfo(
              id: 'tc-1',
              name: 'execute_python',
              arguments: jsonEncode({'notCode': 'x'}),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when code is empty string', () async {
        final bridge = _FakeBridge();
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        expect(
          () => executor.execute(
            ToolCallInfo(
              id: 'tc-1',
              name: 'execute_python',
              arguments: jsonEncode({'code': ''}),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('execute flow', () {
      test('collects text content deltas', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeTextStart(messageId: 'm1'),
          const BridgeTextContent(messageId: 'm1', delta: 'Hello'),
          const BridgeTextContent(messageId: 'm1', delta: ' World'),
          const BridgeTextEnd(messageId: 'm1'),
          const BridgeRunFinished(threadId: 't', runId: 'r'),
        ]);

        final bridge = _FakeBridge(events: events);
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        final result =
            await executor.execute(_toolCall('print("Hello World")'));
        expect(result, 'Hello World');
      });

      test('registers host functions onto bridge', () async {
        final bridge = _FakeBridge();
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        await executor.execute(_toolCall('x = 1'));
        // 4 domain functions + 2 introspection builtins
        expect(bridge.registered, hasLength(6));
      });

      test('releases bridge even on error', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeRunError(message: 'boom'),
        ]);

        final bridge = _FakeBridge(events: events);
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        expect(
          () => executor.execute(_toolCall('raise Exception()')),
          throwsA(isA<StateError>()),
        );

        // Wait for the async error to propagate.
        await Future<void>.delayed(Duration.zero);
        expect(cache.isExecuting(_key), isFalse);
      });

      test('BridgeRunError propagates as StateError', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeRunError(message: 'NameError: x is not defined'),
        ]);

        final bridge = _FakeBridge(events: events);
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        expect(
          executor.execute(_toolCall('print(x)')),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('NameError'),
            ),
          ),
        );
      });

      test('returns empty string when no text events', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeRunFinished(threadId: 't', runId: 'r'),
        ]);

        final bridge = _FakeBridge(events: events);
        final cache = BridgeCache(limit: 1, bridgeFactory: () => bridge);
        final executor = MontyToolExecutor(
          threadKey: _key,
          bridgeCache: cache,
          hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
        );

        final result = await executor.execute(_toolCall('x = 1'));
        expect(result, isEmpty);
      });
    });
  });
}
