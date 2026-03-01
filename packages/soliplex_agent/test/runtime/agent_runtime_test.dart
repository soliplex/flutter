import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {}

class MockLogger extends Mock implements Logger {}

class _FakeSimpleRunAgentInput extends Fake implements SimpleRunAgentInput {}

class _FakeCancelToken extends Fake implements CancelToken {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _roomId = 'room-1';
const _threadId = 'thread-1';
const _runId = 'run-abc';

ThreadInfo _threadInfo() =>
    ThreadInfo(id: _threadId, roomId: _roomId, createdAt: DateTime(2026));

ThreadInfo _threadInfoWithRun() => ThreadInfo(
      id: _threadId,
      roomId: _roomId,
      initialRunId: _runId,
      createdAt: DateTime(2026),
    );

RunInfo _runInfo() =>
    RunInfo(id: _runId, threadId: _threadId, createdAt: DateTime(2026));

List<BaseEvent> _happyPathEvents() => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-1'),
      const TextMessageContentEvent(messageId: 'msg-1', delta: 'Hello'),
      const TextMessageEndEvent(messageId: 'msg-1'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

List<BaseEvent> _toolCallEvents() => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const ToolCallStartEvent(toolCallId: 'tc-1', toolCallName: 'weather'),
      const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{"city":"NYC"}'),
      const ToolCallEndEvent(toolCallId: 'tc-1'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

List<BaseEvent> _resumeTextEvents() => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-2'),
      const TextMessageContentEvent(messageId: 'msg-2', delta: 'Sunny'),
      const TextMessageEndEvent(messageId: 'msg-2'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

ToolRegistry _weatherRegistry() {
  return const ToolRegistry().register(
    ClientTool(
      definition: const Tool(name: 'weather', description: 'Weather tool'),
      executor: (_) async => '72°F, sunny',
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSimpleRunAgentInput());
    registerFallbackValue(_FakeCancelToken());
  });

  late MockSoliplexApi api;
  late MockAgUiClient agUiClient;
  late MockLogger logger;
  late AgentRuntime runtime;

  AgentRuntime createRuntime({
    PlatformConstraints? platform,
    ToolRegistryResolver? resolver,
  }) {
    return AgentRuntime(
      api: api,
      agUiClient: agUiClient,
      toolRegistryResolver: resolver ?? (_) async => const ToolRegistry(),
      platform: platform ?? const NativePlatformConstraints(),
      logger: logger,
    );
  }

  setUp(() {
    api = MockSoliplexApi();
    agUiClient = MockAgUiClient();
    logger = MockLogger();
    runtime = createRuntime();
  });

  tearDown(() async {
    await runtime.dispose();
  });

  void stubCreateThread({ThreadInfo? info}) {
    when(
      () => api.createThread(any()),
    ).thenAnswer((_) async => (info ?? _threadInfo(), <String, dynamic>{}));
  }

  void stubCreateRun() {
    when(() => api.createRun(any(), any())).thenAnswer((_) async => _runInfo());
  }

  void stubDeleteThread() {
    when(() => api.deleteThread(any(), any())).thenAnswer((_) async {});
  }

  void stubRunAgent({required Stream<BaseEvent> stream}) {
    when(
      () => agUiClient.runAgent(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => stream);
  }

  group('spawn', () {
    test('creates thread, starts session, returns AgentSuccess', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Hello');
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
      expect(session.threadKey.serverId, equals('default'));
      expect(session.threadKey.roomId, equals(_roomId));
      expect(session.threadKey.threadId, equals(_threadId));

      verify(() => api.createThread(_roomId)).called(1);
    });

    test('reuses threadId when provided, skips createThread', () async {
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = await runtime.spawn(
        roomId: _roomId,
        prompt: 'Hello',
        threadId: 'existing-thread',
        ephemeral: false,
      );
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
      expect(session.threadKey.threadId, equals('existing-thread'));
      verifyNever(() => api.createThread(any()));
    });

    test('uses initialRunId from createThread', () async {
      stubCreateThread(info: _threadInfoWithRun());
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Hello');

      await session.result;
      // Should NOT call createRun because initialRunId was provided
      verifyNever(() => api.createRun(any(), any()));
    });

    test('session appears in activeSessions', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Hello');

      expect(runtime.activeSessions, contains(session));

      controller.add(const RunStartedEvent(threadId: _threadId, runId: _runId));
      await Future<void>.delayed(Duration.zero);

      await controller.close();
      // After stream closes, session might complete via networkLost
      await session.result;
    });
  });

  group('getSession', () {
    test('finds session by ThreadKey', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Hello');

      final found = runtime.getSession(session.threadKey);
      expect(found, equals(session));

      controller.add(const RunStartedEvent(threadId: _threadId, runId: _runId));
      await controller.close();
      await session.result;
    });

    test('returns null for unknown key', () {
      const unknown = (serverId: 'x', roomId: 'x', threadId: 'x');
      expect(runtime.getSession(unknown), isNull);
    });
  });

  group('sessionChanges', () {
    test('emits on spawn and completion', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final emissions = <List<AgentSession>>[];
      runtime.sessionChanges.listen(emissions.add);

      await runtime.spawn(roomId: _roomId, prompt: 'Hello');

      // Wait for session to complete and be cleaned up
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // At least one emission from spawn
      expect(emissions, isNotEmpty);
    });
  });

  group('waitAll', () {
    test('collects all results', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final s1 = await runtime.spawn(roomId: _roomId, prompt: 'A');
      final s2 = await runtime.spawn(roomId: _roomId, prompt: 'B');

      final results = await runtime.waitAll([s1, s2]);

      expect(results, hasLength(2));
      expect(results.every((r) => r is AgentSuccess), isTrue);
    });
  });

  group('waitAny', () {
    test('returns first completed result', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final s1 = await runtime.spawn(roomId: _roomId, prompt: 'A');
      final s2 = await runtime.spawn(roomId: _roomId, prompt: 'B');

      final result = await runtime.waitAny([s1, s2]);

      expect(result, isA<AgentSuccess>());
    });
  });

  group('WASM guard', () {
    test('blocks second spawn on non-reentrant platform', () async {
      runtime = createRuntime(platform: const WebPlatformConstraints());

      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      await runtime.spawn(roomId: _roomId, prompt: 'A');

      expect(
        () => runtime.spawn(roomId: _roomId, prompt: 'B'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('WASM'),
          ),
        ),
      );

      // Clean up
      _happyPathEvents().forEach(controller.add);
      await controller.close();
    });
  });

  group('concurrency guard', () {
    test('blocks spawn at max concurrent limit', () async {
      runtime = createRuntime(
        platform: const NativePlatformConstraints(maxConcurrentBridges: 2),
      );

      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      final controller = StreamController<BaseEvent>.broadcast();
      stubRunAgent(stream: controller.stream);

      await runtime.spawn(roomId: _roomId, prompt: 'A');
      await runtime.spawn(roomId: _roomId, prompt: 'B');

      expect(
        () => runtime.spawn(roomId: _roomId, prompt: 'C'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Concurrency limit'),
          ),
        ),
      );

      // Clean up
      _happyPathEvents().forEach(controller.add);
      await controller.close();
    });
  });

  group('ephemeral', () {
    test('deletes thread on completion', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Hello');

      await session.result;
      // Give time for completion handler
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => api.deleteThread(_roomId, _threadId)).called(1);
    });

    test('does not delete thread for non-ephemeral', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = await runtime.spawn(
        roomId: _roomId,
        prompt: 'Hello',
        threadId: 'existing',
        ephemeral: false,
      );

      await session.result;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => api.deleteThread(any(), any()));
    });
  });

  group('cancelAll', () {
    test('cancels all active sessions', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      final controller = StreamController<BaseEvent>.broadcast();
      stubRunAgent(stream: controller.stream);

      final s1 = await runtime.spawn(roomId: _roomId, prompt: 'A');
      final s2 = await runtime.spawn(roomId: _roomId, prompt: 'B');

      controller.add(const RunStartedEvent(threadId: _threadId, runId: _runId));
      await Future<void>.delayed(Duration.zero);

      await runtime.cancelAll();

      final r1 = await s1.result;
      final r2 = await s2.result;

      expect(r1, isA<AgentFailure>());
      expect(r2, isA<AgentFailure>());

      await controller.close();
    });
  });

  group('dispose', () {
    test('subsequent spawn throws', () async {
      await runtime.dispose();

      expect(
        () => runtime.spawn(roomId: _roomId, prompt: 'Hello'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    });

    test('cleans up ephemeral threads', () async {
      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      final controller = StreamController<BaseEvent>.broadcast();
      stubRunAgent(stream: controller.stream);

      await runtime.spawn(roomId: _roomId, prompt: 'A');
      controller.add(const RunStartedEvent(threadId: _threadId, runId: _runId));
      await Future<void>.delayed(Duration.zero);

      await runtime.dispose();

      verify(() => api.deleteThread(_roomId, _threadId)).called(1);

      await controller.close();
    });
  });

  group('error propagation', () {
    test('createThread failure propagates', () async {
      when(
        () => api.createThread(any()),
      ).thenThrow(const AuthException(message: 'Token expired'));

      expect(
        () => runtime.spawn(roomId: _roomId, prompt: 'Hello'),
        throwsA(isA<AuthException>()),
      );
    });

    test('resolver failure propagates', () async {
      runtime = createRuntime(
        resolver: (_) async => throw StateError('No tools'),
      );
      stubCreateThread();

      expect(
        () => runtime.spawn(roomId: _roomId, prompt: 'Hello'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('end-to-end', () {
    test('spawn → tool yield → auto-execute → resume → AgentSuccess', () async {
      final registry = _weatherRegistry();
      runtime = createRuntime(resolver: (_) async => registry);

      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();

      var callCount = 0;
      when(
        () => agUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        callCount++;
        return callCount == 1
            ? Stream.fromIterable(_toolCallEvents())
            : Stream.fromIterable(_resumeTextEvents());
      });

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Weather?');
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
      final success = result as AgentSuccess;
      expect(success.output, equals('Sunny'));
      expect(callCount, equals(2));
    });
  });

  group('serverId', () {
    test('defaults to "default"', () {
      expect(runtime.serverId, equals('default'));
    });

    test('custom serverId appears in ThreadKey', () async {
      runtime = AgentRuntime(
        api: api,
        agUiClient: agUiClient,
        toolRegistryResolver: (_) async => const ToolRegistry(),
        platform: const NativePlatformConstraints(),
        logger: logger,
        serverId: 'staging.soliplex.io',
      );

      stubCreateThread();
      stubCreateRun();
      stubDeleteThread();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = await runtime.spawn(roomId: _roomId, prompt: 'Hello');

      expect(session.threadKey.serverId, equals('staging.soliplex.io'));
      await session.result;
    });
  });
}
