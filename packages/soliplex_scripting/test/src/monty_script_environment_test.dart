import 'dart:async';
import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart' show ToolExecutionContext;
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

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

ToolCallInfo _toolCall(String code) => ToolCallInfo(
      id: 'tc-1',
      name: 'execute_python',
      arguments: jsonEncode({'code': code}),
    );

/// Stub context — tools in these tests ignore the context parameter.
class _FakeContext implements ToolExecutionContext {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

final _ctx = _FakeContext();

void main() {
  group('MontyScriptEnvironment', () {
    group('tools', () {
      test('exposes execute_python tool', () {
        final env = MontyScriptEnvironment(
          bridge: _FakeBridge(),
          dfRegistry: DfRegistry(),
          streamRegistry: StreamRegistry(),
        );

        expect(env.tools, hasLength(1));
        expect(
          env.tools.first.definition.name,
          equals(PythonExecutorTool.toolName),
        );

        env.dispose();
      });
    });

    group('execution', () {
      test('collects text content deltas', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeTextContent(messageId: 'm', delta: 'Hello'),
          const BridgeTextContent(messageId: 'm', delta: ' World'),
          const BridgeRunFinished(threadId: 't', runId: 'r'),
        ]);
        final env = MontyScriptEnvironment(
          bridge: _FakeBridge(events: events),
          dfRegistry: DfRegistry(),
          streamRegistry: StreamRegistry(),
        );
        addTearDown(env.dispose);

        final result = await env.tools.first.executor(
          _toolCall('print("hi")'),
          _ctx,
        );

        expect(result, equals('Hello World'));
      });

      test('BridgeRunError propagates as StateError', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeRunError(message: 'NameError: x is not defined'),
        ]);
        final env = MontyScriptEnvironment(
          bridge: _FakeBridge(events: events),
          dfRegistry: DfRegistry(),
          streamRegistry: StreamRegistry(),
        );
        addTearDown(env.dispose);

        expect(
          env.tools.first.executor(_toolCall('print(x)'), _ctx),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('NameError'),
            ),
          ),
        );
      });

      test('timeout throws TimeoutException', () async {
        final controller = StreamController<BridgeEvent>();
        final env = MontyScriptEnvironment(
          bridge: _FakeBridge(events: controller.stream),
          dfRegistry: DfRegistry(),
          streamRegistry: StreamRegistry(),
          executionTimeout: const Duration(milliseconds: 50),
        );
        addTearDown(() {
          env.dispose();
          unawaited(controller.close());
        });

        await expectLater(
          env.tools.first.executor(_toolCall('while True: pass'), _ctx),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('returns empty string when no text events', () async {
        final events = Stream.fromIterable([
          const BridgeRunStarted(threadId: 't', runId: 'r'),
          const BridgeRunFinished(threadId: 't', runId: 'r'),
        ]);
        final env = MontyScriptEnvironment(
          bridge: _FakeBridge(events: events),
          dfRegistry: DfRegistry(),
          streamRegistry: StreamRegistry(),
        );
        addTearDown(env.dispose);

        final result = await env.tools.first.executor(_toolCall('x = 1'), _ctx);

        expect(result, isEmpty);
      });
    });

    group('extractCode', () {
      test('extracts code from valid JSON', () {
        final result = MontyScriptEnvironment.extractCode(
          _toolCall('print("hi")'),
        );

        expect(result, equals('print("hi")'));
      });

      test('throws ArgumentError on invalid JSON', () {
        expect(
          () => MontyScriptEnvironment.extractCode(
            const ToolCallInfo(
              id: 'tc-1',
              name: 'execute_python',
              arguments: 'not json',
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when code key is missing', () {
        expect(
          () => MontyScriptEnvironment.extractCode(
            ToolCallInfo(
              id: 'tc-1',
              name: 'execute_python',
              arguments: jsonEncode({'notCode': 'x'}),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when code is empty string', () {
        expect(
          () => MontyScriptEnvironment.extractCode(
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

    group('dispose', () {
      test('disposes bridge, dfRegistry, and streamRegistry', () {
        final bridge = _FakeBridge();
        final dfRegistry = DfRegistry();
        final streamRegistry = StreamRegistry();
        MontyScriptEnvironment(
          bridge: bridge,
          dfRegistry: dfRegistry,
          streamRegistry: streamRegistry,
        ).dispose();

        expect(bridge.disposed, isTrue);
      });

      test('double dispose is safe', () {
        final bridge = _FakeBridge();
        MontyScriptEnvironment(
          bridge: bridge,
          dfRegistry: DfRegistry(),
          streamRegistry: StreamRegistry(),
        )
          ..dispose()
          ..dispose();

        expect(bridge.disposed, isTrue);
      });
    });
  });
}
