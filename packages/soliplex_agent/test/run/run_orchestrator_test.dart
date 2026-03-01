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

const ThreadKey _key = (
  serverId: 'srv-1',
  roomId: 'room-1',
  threadId: 'thread-1',
);

const _runId = 'run-abc';

RunInfo _runInfo() =>
    RunInfo(id: _runId, threadId: _key.threadId, createdAt: DateTime(2026));

List<BaseEvent> _happyPathEvents() => [
      const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-1'),
      const TextMessageContentEvent(messageId: 'msg-1', delta: 'Hello'),
      const TextMessageEndEvent(messageId: 'msg-1'),
      const RunFinishedEvent(threadId: 'thread-1', runId: _runId),
    ];

List<BaseEvent> _toolCallEvents({String toolName = 'weather'}) => [
      const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      ToolCallStartEvent(toolCallId: 'tc-1', toolCallName: toolName),
      const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{"city":"NYC"}'),
      const ToolCallEndEvent(toolCallId: 'tc-1'),
      const RunFinishedEvent(threadId: 'thread-1', runId: _runId),
    ];

List<BaseEvent> _resumeTextEvents() => [
      const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-2'),
      const TextMessageContentEvent(messageId: 'msg-2', delta: 'Sunny'),
      const TextMessageEndEvent(messageId: 'msg-2'),
      const RunFinishedEvent(threadId: 'thread-1', runId: _runId),
    ];

ToolRegistry _registryWith({String toolName = 'weather'}) {
  return const ToolRegistry().register(
    ClientTool(
      definition: Tool(name: toolName, description: 'A test tool'),
      executor: (_) async => 'result',
    ),
  );
}

List<ToolCallInfo> _executedTools() => [
      const ToolCallInfo(
        id: 'tc-1',
        name: 'weather',
        arguments: '{"city":"NYC"}',
        status: ToolCallStatus.completed,
        result: '72°F, sunny',
      ),
    ];

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSimpleRunAgentInput());
    registerFallbackValue(_FakeCancelToken());
  });
  late MockSoliplexApi api;
  late MockAgUiClient agUiClient;
  late MockLogger logger;
  late RunOrchestrator orchestrator;

  setUp(() {
    api = MockSoliplexApi();
    agUiClient = MockAgUiClient();
    logger = MockLogger();
    orchestrator = RunOrchestrator(
      api: api,
      agUiClient: agUiClient,
      toolRegistry: const ToolRegistry(),
      platformConstraints: const NativePlatformConstraints(),
      logger: logger,
    );
  });

  tearDown(() {
    orchestrator.dispose();
  });

  void stubCreateRun() {
    when(() => api.createRun(any(), any())).thenAnswer((_) async => _runInfo());
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

  group('happy path', () {
    test('streams to CompletedState', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Hi');

      // Give stream time to complete
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());
      final completed = orchestrator.currentState as CompletedState;
      expect(completed.threadKey, equals(_key));
      expect(completed.runId, equals(_runId));
    });

    test('stateChanges emits transitions', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final states = <RunState>[];
      orchestrator.stateChanges.listen(states.add);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      // Expect: RunningState (initial), then updates per event, CompletedState
      expect(states.first, isA<RunningState>());
      expect(states.last, isA<CompletedState>());
    });

    test('currentState matches last emission', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      RunState? lastEmitted;
      orchestrator.stateChanges.listen((s) => lastEmitted = s);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, equals(lastEmitted));
    });

    test('existingRunId skips createRun', () async {
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      await orchestrator.startRun(
        key: _key,
        userMessage: 'Hi',
        existingRunId: _runId,
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => api.createRun(any(), any()));
      expect(orchestrator.currentState, isA<CompletedState>());
    });
  });

  group('error', () {
    test('RunErrorEvent transitions to FailedState(serverError)', () async {
      stubCreateRun();
      stubRunAgent(
        stream: Stream.fromIterable([
          const RunStartedEvent(threadId: 'thread-1', runId: _runId),
          const RunErrorEvent(message: 'backend error'),
        ]),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.serverError));
      expect(failed.error, equals('backend error'));
    });

    test(
      'HTTP 401 TransportError transitions to FailedState(authExpired)',
      () async {
        stubCreateRun();
        stubRunAgent(
          stream: Stream.error(
            const TransportError('Unauthorized', statusCode: 401),
          ),
        );

        await orchestrator.startRun(key: _key, userMessage: 'Hi');
        await Future<void>.delayed(Duration.zero);

        expect(orchestrator.currentState, isA<FailedState>());
        final failed = orchestrator.currentState as FailedState;
        expect(failed.reason, equals(FailureReason.authExpired));
      },
    );

    test(
      'HTTP 429 TransportError transitions to FailedState(rateLimited)',
      () async {
        stubCreateRun();
        stubRunAgent(
          stream: Stream.error(
            const TransportError('Too many requests', statusCode: 429),
          ),
        );

        await orchestrator.startRun(key: _key, userMessage: 'Hi');
        await Future<void>.delayed(Duration.zero);

        expect(orchestrator.currentState, isA<FailedState>());
        final failed = orchestrator.currentState as FailedState;
        expect(failed.reason, equals(FailureReason.rateLimited));
      },
    );

    test(
      'stream ends without terminal event transitions to networkLost',
      () async {
        stubCreateRun();
        stubRunAgent(
          stream: Stream.fromIterable([
            const RunStartedEvent(threadId: 'thread-1', runId: _runId),
            const TextMessageStartEvent(messageId: 'msg-1'),
          ]),
        );

        await orchestrator.startRun(key: _key, userMessage: 'Hi');
        await Future<void>.delayed(Duration.zero);

        expect(orchestrator.currentState, isA<FailedState>());
        final failed = orchestrator.currentState as FailedState;
        expect(failed.reason, equals(FailureReason.networkLost));
      },
    );

    test('createRun throws transitions to FailedState', () async {
      when(
        () => api.createRun(any(), any()),
      ).thenThrow(const AuthException(message: 'Token expired'));

      await orchestrator.startRun(key: _key, userMessage: 'Hi');

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.authExpired));
    });
  });

  group('cancel', () {
    test('cancelRun transitions to CancelledState', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<RunningState>());

      orchestrator.cancelRun();

      expect(orchestrator.currentState, isA<CancelledState>());
      final cancelled = orchestrator.currentState as CancelledState;
      expect(cancelled.threadKey, equals(_key));
      expect(cancelled.conversation, isNotNull);

      await controller.close();
    });

    test('cancelRun while idle is a no-op', () {
      expect(orchestrator.currentState, isA<IdleState>());
      orchestrator.cancelRun();
      expect(orchestrator.currentState, isA<IdleState>());
    });
  });

  group('guard', () {
    test('startRun while running throws StateError', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        () => orchestrator.startRun(key: _key, userMessage: 'Again'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already active'),
          ),
        ),
      );

      await controller.close();
    });
  });

  group('reset', () {
    test('reset transitions to IdleState', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());

      orchestrator.reset();

      expect(orchestrator.currentState, isA<IdleState>());
    });
  });

  group('tool yielding', () {
    test('pending client tools → ToolYieldingState', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_toolCallEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<ToolYieldingState>());
      final yielding = orchestrator.currentState as ToolYieldingState;
      expect(yielding.pendingToolCalls, hasLength(1));
      expect(yielding.pendingToolCalls.first.name, equals('weather'));
      expect(yielding.toolDepth, equals(0));
    });

    test('no pending client tools → CompletedState', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_toolCallEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());
    });

    test('server-side tools (not in registry) → CompletedState', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(toolName: 'other_tool'),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      stubRunAgent(
        stream: Stream.fromIterable(
          _toolCallEvents(toolName: 'server_only_tool'),
        ),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());
    });
  });

  group('submitToolOutputs', () {
    late int callCount;

    void stubRunAgentSequential({
      required Stream<BaseEvent> first,
      required Stream<BaseEvent> second,
    }) {
      callCount = 0;
      when(
        () => agUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        callCount++;
        return callCount == 1 ? first : second;
      });
    }

    test('resume → Running → Completed', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      stubRunAgentSequential(
        first: Stream.fromIterable(_toolCallEvents()),
        second: Stream.fromIterable(_resumeTextEvents()),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<ToolYieldingState>());

      await orchestrator.submitToolOutputs(_executedTools());
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());
    });

    test('throws when not in ToolYieldingState', () {
      expect(
        () => orchestrator.submitToolOutputs(_executedTools()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Not in ToolYieldingState'),
          ),
        ),
      );
    });

    test('throws when disposed', () async {
      orchestrator.dispose();
      expect(
        () => orchestrator.submitToolOutputs(_executedTools()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    });
  });

  group('tool chain', () {
    test('2 rounds of yield/submit/resume', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      var callCount = 0;
      when(
        () => agUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        callCount++;
        if (callCount <= 2) {
          return Stream.fromIterable(_toolCallEvents());
        }
        return Stream.fromIterable(_resumeTextEvents());
      });

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<ToolYieldingState>());
      final yield1 = orchestrator.currentState as ToolYieldingState;
      expect(yield1.toolDepth, equals(0));

      await orchestrator.submitToolOutputs(_executedTools());
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<ToolYieldingState>());
      final yield2 = orchestrator.currentState as ToolYieldingState;
      expect(yield2.toolDepth, equals(1));

      await orchestrator.submitToolOutputs(_executedTools());
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<CompletedState>());
    });
  });

  group('depth limit', () {
    test('exceed max → FailedState(toolExecutionFailed)', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      when(
        () => agUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(_toolCallEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);

      for (var i = 0; i < 10; i++) {
        expect(orchestrator.currentState, isA<ToolYieldingState>());
        await orchestrator.submitToolOutputs(_executedTools());
        await Future<void>.delayed(Duration.zero);
      }

      expect(orchestrator.currentState, isA<ToolYieldingState>());
      await orchestrator.submitToolOutputs(_executedTools());

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.toolExecutionFailed));
      expect(failed.error, contains('depth limit'));
    });
  });

  group('cancel during yield', () {
    test('cancelRun → CancelledState', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_toolCallEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<ToolYieldingState>());

      orchestrator.cancelRun();

      expect(orchestrator.currentState, isA<CancelledState>());
      final cancelled = orchestrator.currentState as CancelledState;
      expect(cancelled.conversation, isNotNull);
    });

    test('startRun blocked during ToolYieldingState', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_toolCallEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<ToolYieldingState>());

      expect(
        () => orchestrator.startRun(key: _key, userMessage: 'Again'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already active'),
          ),
        ),
      );
    });
  });

  group('cancel during async gap', () {
    test('dispose during startRun await aborts', () async {
      final createRunCompleter = Completer<RunInfo>();
      when(
        () => api.createRun(any(), any()),
      ).thenAnswer((_) => createRunCompleter.future);
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      // Start run — will suspend on createRun.
      unawaited(orchestrator.startRun(key: _key, userMessage: 'Hi'));
      await Future<void>.delayed(Duration.zero);

      // Dispose while awaiting createRun.
      orchestrator.dispose();

      // Complete the createRun after disposal.
      createRunCompleter.complete(_runInfo());
      await Future<void>.delayed(Duration.zero);

      // Should not have subscribed to stream.
      verifyNever(
        () => agUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('cancelRun during submitToolOutputs await aborts', () async {
      orchestrator = RunOrchestrator(
        api: api,
        agUiClient: agUiClient,
        toolRegistry: _registryWith(),
        platformConstraints: const NativePlatformConstraints(),
        logger: logger,
      );
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_toolCallEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Weather?');
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.currentState, isA<ToolYieldingState>());

      // Make the resume createRun hang.
      final resumeCompleter = Completer<RunInfo>();
      when(
        () => api.createRun(any(), any()),
      ).thenAnswer((_) => resumeCompleter.future);

      unawaited(orchestrator.submitToolOutputs(_executedTools()));
      await Future<void>.delayed(Duration.zero);

      // Cancel while awaiting resume createRun.
      orchestrator.cancelRun();

      // Complete the createRun after cancellation.
      resumeCompleter.complete(_runInfo());
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CancelledState>());
    });
  });

  group('dispose', () {
    test('cleans up resources', () async {
      orchestrator.dispose();

      expect(
        () => orchestrator.startRun(key: _key, userMessage: 'Hi'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    });

    test('stateChanges stream closes on dispose', () async {
      final done = Completer<void>();
      orchestrator.stateChanges.listen(null, onDone: done.complete);

      orchestrator.dispose();

      await expectLater(done.future, completes);
    });
  });
}
