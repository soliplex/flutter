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
      const TextMessageContentEvent(messageId: 'msg-1', delta: 'Hello world'),
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

ToolRegistry _registryWith({
  String toolName = 'weather',
  Future<String> Function(ToolCallInfo)? executor,
}) {
  return const ToolRegistry().register(
    ClientTool(
      definition: Tool(name: toolName, description: 'A test tool'),
      executor: executor ?? (_) async => '72°F, sunny',
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a session wired to real RunOrchestrator with given deps.
AgentSession createSession({
  required MockSoliplexApi api,
  required MockAgUiClient agUiClient,
  required MockLogger logger,
  ToolRegistry? toolRegistry,
  bool ephemeral = false,
}) {
  final registry = toolRegistry ?? const ToolRegistry();
  final orchestrator = RunOrchestrator(
    api: api,
    agUiClient: agUiClient,
    toolRegistry: registry,
    platformConstraints: const NativePlatformConstraints(),
    logger: logger,
  );
  return AgentSession(
    threadKey: _key,
    ephemeral: ephemeral,
    orchestrator: orchestrator,
    toolRegistry: registry,
    logger: logger,
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

  setUp(() {
    api = MockSoliplexApi();
    agUiClient = MockAgUiClient();
    logger = MockLogger();
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
    test('completes with AgentSuccess', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Hi');
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
      final success = result as AgentSuccess;
      expect(success.output, equals('Hello world'));
      expect(success.runId, equals(_runId));
      expect(success.threadKey, equals(_key));
    });

    test('state transitions spawning → running → completed', () async {
      stubCreateRun();

      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(session.dispose);

      expect(session.state, equals(AgentSessionState.spawning));

      await session.start(userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);
      expect(session.state, equals(AgentSessionState.running));

      _happyPathEvents().skip(1).forEach(controller.add);
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(session.state, equals(AgentSessionState.completed));
    });
  });

  group('auto-execute', () {
    test('yield → execute → resume → AgentSuccess', () async {
      final registry = _registryWith();
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
        return callCount == 1
            ? Stream.fromIterable(_toolCallEvents())
            : Stream.fromIterable(_resumeTextEvents());
      });

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
        toolRegistry: registry,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Weather?');
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
      final success = result as AgentSuccess;
      expect(success.output, equals('Sunny'));
    });

    test('double yield: 2 rounds of tool execution', () async {
      final registry = _registryWith();
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

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
        toolRegistry: registry,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Weather?');
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
      expect(callCount, equals(3));
    });

    test('tool error → ToolCallStatus.failed, session continues', () async {
      final registry = _registryWith(
        executor: (_) async => throw Exception('API down'),
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
        return callCount == 1
            ? Stream.fromIterable(_toolCallEvents())
            : Stream.fromIterable(_resumeTextEvents());
      });

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
        toolRegistry: registry,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Weather?');
      final result = await session.result;

      expect(result, isA<AgentSuccess>());
    });
  });

  group('cancel', () {
    test('cancel during running → AgentFailure(cancelled)', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);

      session.cancel();
      final result = await session.result;

      expect(result, isA<AgentFailure>());
      final failure = result as AgentFailure;
      expect(failure.reason, equals(FailureReason.cancelled));
      expect(session.state, equals(AgentSessionState.cancelled));

      await controller.close();
    });

    test('cancel on already-terminal session is no-op', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Hi');
      await session.result;

      expect(session.state, equals(AgentSessionState.completed));
      session.cancel(); // should not throw
      expect(session.state, equals(AgentSessionState.completed));
    });
  });

  group('failure', () {
    test('stream error → AgentFailure', () async {
      stubCreateRun();
      stubRunAgent(
        stream: Stream.fromIterable([
          const RunStartedEvent(threadId: 'thread-1', runId: _runId),
          const RunErrorEvent(message: 'backend error'),
        ]),
      );

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(session.dispose);

      await session.start(userMessage: 'Hi');
      final result = await session.result;

      expect(result, isA<AgentFailure>());
      final failure = result as AgentFailure;
      expect(failure.reason, equals(FailureReason.serverError));
      expect(session.state, equals(AgentSessionState.failed));
    });
  });

  group('timeout', () {
    test('awaitResult with short timeout → AgentTimedOut', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(() async {
        session.dispose();
        await controller.close();
      });

      await session.start(userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);

      final result = await session.awaitResult(
        timeout: const Duration(milliseconds: 10),
      );

      expect(result, isA<AgentTimedOut>());
    });
  });

  group('dispose', () {
    test('dispose before completion completes with internalError', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );

      await session.start(userMessage: 'Hi');
      session.dispose();

      final result = await session.result;
      expect(result, isA<AgentFailure>());
      final failure = result as AgentFailure;
      expect(failure.reason, equals(FailureReason.internalError));

      await controller.close();
    });
  });

  group('id', () {
    test('id contains threadId', () {
      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
      );
      addTearDown(session.dispose);

      expect(session.id, contains(_key.threadId));
    });
  });

  group('ephemeral', () {
    test('ephemeral flag is preserved', () {
      final session = createSession(
        api: api,
        agUiClient: agUiClient,
        logger: logger,
        ephemeral: true,
      );
      addTearDown(session.dispose);

      expect(session.ephemeral, isTrue);
    });
  });
}
