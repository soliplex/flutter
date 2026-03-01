import 'dart:collection';
import 'dart:convert';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

void main() {
  late MockMontyPlatform mock;
  late DefaultMontyBridge bridge;

  setUp(() {
    mock = MockMontyPlatform();
    bridge = DefaultMontyBridge(platform: mock);
  });

  tearDown(() {
    bridge.dispose();
  });

  group('happy path', () {
    test('emits RunStarted → RunFinished for code with no calls', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(value: 42, usage: _usage)),
      );

      final events = await bridge.execute('42').toList();

      expect(events, hasLength(2));
      expect(events[0], isA<BridgeRunStarted>());
      expect(events[1], isA<BridgeRunFinished>());
    });

    test('dispatches tool call with correct event sequence', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'search',
            description: 'Search docs',
            params: [
              HostParam(name: 'query', type: HostParamType.string),
            ],
          ),
          handler: (args) async => 'result for ${args['query']}',
        ),
      );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'search',
            arguments: ['test query'],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await bridge.execute('search("test query")').toList();

      // RunStarted, StepStarted, ToolCallStart, ToolCallArgs,
      // ToolCallEnd, ToolCallResult, StepFinished, RunFinished
      expect(events, hasLength(8));
      expect(events[0], isA<BridgeRunStarted>());
      expect(events[1], isA<BridgeStepStarted>());
      expect(events[2], isA<BridgeToolCallStart>());
      expect(events[3], isA<BridgeToolCallArgs>());
      expect(events[4], isA<BridgeToolCallEnd>());
      expect(events[5], isA<BridgeToolCallResult>());
      expect(events[6], isA<BridgeStepFinished>());
      expect(events[7], isA<BridgeRunFinished>());

      // Verify args JSON
      final argsEvent = events[3] as BridgeToolCallArgs;
      final argsMap = jsonDecode(argsEvent.delta) as Map<String, Object?>;
      expect(argsMap['query'], 'test query');

      // Verify result content
      final resultEvent = events[5] as BridgeToolCallResult;
      expect(resultEvent.result, 'result for test query');

      // Verify futures path was used
      expect(mock.resumeAsFutureCount, 1);
      expect(mock.lastResolveFuturesResults![1], 'result for test query');
    });

    test('handles multiple tool calls in sequence', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'add',
            description: 'Add numbers',
            params: [
              HostParam(name: 'a', type: HostParamType.integer),
              HostParam(name: 'b', type: HostParamType.integer),
            ],
          ),
          handler: (args) async => (args['a']! as int) + (args['b']! as int),
        ),
      );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'add',
            arguments: [1, 2],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1]),
        )
        ..enqueueProgress(
          const MontyPending(
            functionName: 'add',
            arguments: [3, 4],
            callId: 2,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [2]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(value: 10, usage: _usage)),
        );

      final events = await bridge.execute('add(1,2) + add(3,4)').toList();

      // RunStarted + 2 * (Step+ToolCall events) + RunFinished
      final toolCallResults = events.whereType<BridgeToolCallResult>().toList();
      expect(toolCallResults, hasLength(2));
      expect(toolCallResults[0].result, '3');
      expect(toolCallResults[1].result, '7');
    });
  });

  group('print output', () {
    test('buffers print and flushes as TextMessage events', () async {
      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: '__console_write__',
            arguments: ['hello\n'],
          ),
        )
        ..enqueueProgress(
          const MontyPending(
            functionName: '__console_write__',
            arguments: ['world\n'],
          ),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events =
          await bridge.execute('print("hello"); print("world")').toList();

      final textStart = events.whereType<BridgeTextStart>().toList();
      final textContent = events.whereType<BridgeTextContent>().toList();
      final textEnd = events.whereType<BridgeTextEnd>().toList();

      expect(textStart, hasLength(1));
      expect(textContent, hasLength(1));
      expect(textContent.first.delta, 'hello\nworld\n');
      expect(textEnd, hasLength(1));
    });

    test('no TextMessage events when no print output', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(value: 42, usage: _usage)),
      );

      final events = await bridge.execute('42').toList();

      expect(events.whereType<BridgeTextStart>(), isEmpty);
      expect(events.whereType<BridgeTextContent>(), isEmpty);
      expect(events.whereType<BridgeTextEnd>(), isEmpty);
    });
  });

  group('error handling', () {
    test('emits BridgeRunError for Python exceptions', () async {
      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(
            error: MontyException(message: 'NameError: x is not defined'),
            usage: _usage,
          ),
        ),
      );

      final events = await bridge.execute('x').toList();

      expect(events.last, isA<BridgeRunError>());
      expect(
        (events.last as BridgeRunError).message,
        'NameError: x is not defined',
      );
    });

    test('resumes with error for unknown functions', () async {
      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'unknown_fn',
            arguments: [],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyComplete(
            result: MontyResult(
              error: MontyException(message: 'Unknown function: unknown_fn'),
              usage: _usage,
            ),
          ),
        );

      await bridge.execute('unknown_fn()').toList();

      // Should have called resumeWithError
      expect(mock.resumeErrorMessages, hasLength(1));
      expect(
        mock.resumeErrorMessages.first,
        'Unknown function: unknown_fn',
      );
    });

    test('emits ToolCallResult with error when handler throws', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'fail',
            description: 'Always fails',
          ),
          handler: (args) async => throw Exception('handler error'),
        ),
      );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fail',
            arguments: [],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1]),
        )
        ..enqueueProgress(
          const MontyComplete(
            result: MontyResult(usage: _usage),
          ),
        );

      final events = await bridge.execute('fail()').toList();

      final results = events.whereType<BridgeToolCallResult>().toList();
      expect(results, hasLength(1));
      expect(results.first.result, contains('handler error'));

      // Error routed through resolveFutures errors map
      expect(mock.lastResolveFuturesErrors![1], contains('handler error'));
    });
  });

  group('state guards', () {
    test('throws when executing while already running', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      // Start first execution (don't await)
      bridge.execute('1');

      expect(() => bridge.execute('2'), throwsStateError);
    });

    test('throws when disposed', () {
      bridge.dispose();
      expect(() => bridge.execute('1'), throwsStateError);
    });

    test('throws on register after dispose', () {
      bridge.dispose();
      expect(
        () => bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'x',
              description: 'x',
            ),
            handler: (args) async => null,
          ),
        ),
        throwsStateError,
      );
    });

    test('throws on unregister after dispose', () {
      bridge.dispose();
      expect(() => bridge.unregister('x'), throwsStateError);
    });
  });

  group('registration', () {
    test('schemas returns registered function schemas', () {
      bridge
        ..register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'a',
              description: 'A',
            ),
            handler: (args) async => null,
          ),
        )
        ..register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'b',
              description: 'B',
            ),
            handler: (args) async => null,
          ),
        );

      expect(bridge.schemas.map((s) => s.name), containsAll(['a', 'b']));
    });

    test('unregister removes function', () {
      bridge
        ..register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'temp',
              description: 'Temporary',
            ),
            handler: (args) async => null,
          ),
        )
        ..unregister('temp');
      expect(bridge.schemas, isEmpty);
    });

    test('registers external functions with Monty', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'my_tool',
            description: 'My tool',
          ),
          handler: (args) async => null,
        ),
      );

      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      await bridge.execute('1').toList();

      // Verify external functions list includes __console_write__ + my_tool
      expect(
        mock.lastStartExternalFunctions,
        containsAll(['__console_write__', 'my_tool']),
      );
    });
  });

  group('async/futures (M13)', () {
    test('single host function uses resumeAsFuture', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'fetch',
            description: 'Fetch data',
            params: [
              HostParam(name: 'url', type: HostParamType.string),
            ],
          ),
          handler: (args) async => 'data from ${args['url']}',
        ),
      );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fetch',
            arguments: ['example.com'],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events =
          await bridge.execute('await fetch("example.com")').toList();

      expect(mock.resumeAsFutureCount, 1);
      expect(mock.lastResolveFuturesResults![1], 'data from example.com');

      final results = events.whereType<BridgeToolCallResult>().toList();
      expect(results, hasLength(1));
      expect(results.first.result, 'data from example.com');
    });

    test('multiple concurrent futures resolved together', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'fetch',
            description: 'Fetch data',
            params: [
              HostParam(name: 'url', type: HostParamType.string),
            ],
          ),
          handler: (args) async => 'data from ${args['url']}',
        ),
      );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fetch',
            arguments: ['a'],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fetch',
            arguments: ['b'],
            callId: 2,
          ),
        )
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fetch',
            arguments: ['c'],
            callId: 3,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1, 2, 3]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await bridge.execute('asyncio.gather(...)').toList();

      expect(mock.resumeAsFutureCount, 3);
      expect(mock.lastResolveFuturesResults, {
        1: 'data from a',
        2: 'data from b',
        3: 'data from c',
      });

      final results = events.whereType<BridgeToolCallResult>().toList();
      expect(results, hasLength(3));
    });

    test('handler failure populates errors map', () async {
      bridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'fail',
            description: 'Always fails',
          ),
          handler: (args) async => throw Exception('boom'),
        ),
      );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fail',
            arguments: [],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await bridge.execute('await fail()').toList();

      expect(mock.resumeAsFutureCount, 1);
      expect(mock.lastResolveFuturesResults, isEmpty);
      expect(mock.lastResolveFuturesErrors![1], contains('boom'));

      final results = events.whereType<BridgeToolCallResult>().toList();
      expect(results.first.result, contains('boom'));
    });

    test('mixed success and failure', () async {
      bridge
        ..register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'succeed',
              description: 'Succeeds',
            ),
            handler: (args) async => 'ok',
          ),
        )
        ..register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'fail',
              description: 'Fails',
            ),
            handler: (args) async => throw Exception('nope'),
          ),
        );

      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'succeed',
            arguments: [],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyPending(
            functionName: 'fail',
            arguments: [],
            callId: 2,
          ),
        )
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1, 2]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      await bridge.execute('gather(...)').toList();

      expect(mock.lastResolveFuturesResults, {1: 'ok'});
      expect(mock.lastResolveFuturesErrors![2], contains('nope'));
    });

    test('console write stays synchronous', () async {
      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: '__console_write__',
            arguments: ['hello\n'],
          ),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      await bridge.execute('print("hello")').toList();

      expect(mock.resumeAsFutureCount, 0);
      expect(mock.resumeReturnValues, [null]);
    });

    test('non-future platform uses sync path', () async {
      final syncMock = _SyncOnlyMockPlatform();
      final syncBridge = DefaultMontyBridge(platform: syncMock);
      addTearDown(syncBridge.dispose);

      syncBridge.register(
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'search',
            description: 'Search',
            params: [
              HostParam(name: 'query', type: HostParamType.string),
            ],
          ),
          handler: (args) async => 'found ${args['query']}',
        ),
      );

      syncMock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'search',
            arguments: ['test'],
            callId: 1,
          ),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await syncBridge.execute('search("test")').toList();

      // Should have used resume() not resumeAsFuture()
      expect(syncMock.lastResumeReturnValue, 'found test');

      final results = events.whereType<BridgeToolCallResult>().toList();
      expect(results.first.result, 'found test');
    });

    test('MontyResolveFutures fallback without futures', () async {
      final syncMock = _SyncOnlyMockPlatform();
      final syncBridge = DefaultMontyBridge(platform: syncMock);
      addTearDown(syncBridge.dispose);

      syncMock
        ..enqueueProgress(
          const MontyResolveFutures(pendingCallIds: [1]),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await syncBridge.execute('async_call()').toList();

      expect(events.first, isA<BridgeRunStarted>());
      expect(events.last, isA<BridgeRunFinished>());
      // Should have called resume(null) as fallback
      expect(syncMock.lastResumeReturnValue, null);
    });
  });
}

/// Mock platform that does NOT implement [MontyFutureCapable].
///
/// Used to test that [DefaultMontyBridge] falls back to synchronous behavior
/// when the platform does not support futures.
class _SyncOnlyMockPlatform extends MontyPlatform {
  final Queue<MontyProgress> _progressQueue = Queue<MontyProgress>();
  final List<Object?> resumeReturnValues = [];
  final List<String> resumeErrorMessages = [];

  Object? get lastResumeReturnValue =>
      resumeReturnValues.isEmpty ? null : resumeReturnValues.last;

  void enqueueProgress(MontyProgress progress) {
    _progressQueue.add(progress);
  }

  @override
  Future<MontyProgress> start(
    String code, {
    Map<String, Object?>? inputs,
    List<String>? externalFunctions,
    MontyLimits? limits,
    String? scriptName,
  }) async =>
      _dequeueProgress();

  @override
  Future<MontyProgress> resume(Object? returnValue) async {
    resumeReturnValues.add(returnValue);
    return _dequeueProgress();
  }

  @override
  Future<MontyProgress> resumeWithError(String errorMessage) async {
    resumeErrorMessages.add(errorMessage);
    return _dequeueProgress();
  }

  @override
  Future<MontyResult> run(
    String code, {
    Map<String, Object?>? inputs,
    MontyLimits? limits,
    String? scriptName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async {}

  MontyProgress _dequeueProgress() {
    if (_progressQueue.isEmpty) {
      throw StateError('No progress enqueued.');
    }
    return _progressQueue.removeFirst();
  }
}
