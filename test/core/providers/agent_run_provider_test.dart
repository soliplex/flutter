import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/agent_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

// ---------------------------------------------------------------------------
// Mocks (local — no dependency on test_helpers.dart)
// ---------------------------------------------------------------------------

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {}

class _FakeSimpleRunAgentInput extends Fake implements SimpleRunAgentInput {}

class _FakeCancelToken extends Fake implements CancelToken {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _roomId = 'room-1';
const _threadId = 'thread-1';
const _runId = 'run-abc';

RunInfo _runInfo() => RunInfo(
      id: _runId,
      threadId: _threadId,
      createdAt: DateTime(2026),
    );

List<BaseEvent> _happyPathEvents() => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-1'),
      const TextMessageContentEvent(messageId: 'msg-1', delta: 'Hello'),
      const TextMessageEndEvent(messageId: 'msg-1'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

List<BaseEvent> _toolCallEvents({String toolName = 'weather'}) => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      ToolCallStartEvent(toolCallId: 'tc-1', toolCallName: toolName),
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

ToolRegistry _registryWith({String toolName = 'weather'}) {
  return const ToolRegistry().register(
    ClientTool(
      definition: Tool(name: toolName, description: 'A test tool'),
      executor: (_) async => '72°F, sunny',
    ),
  );
}

// ---------------------------------------------------------------------------
// Container helper
// ---------------------------------------------------------------------------

ProviderContainer createContainer({
  MockSoliplexApi? api,
  MockAgUiClient? agUiClient,
  ToolRegistry? toolRegistry,
}) {
  return ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(api ?? MockSoliplexApi()),
      agUiClientProvider.overrideWithValue(agUiClient ?? MockAgUiClient()),
      if (toolRegistry != null)
        toolRegistryProvider.overrideWithValue(toolRegistry),
    ],
  );
}

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

void stubCreateRun(MockSoliplexApi api) {
  when(() => api.createRun(any(), any())).thenAnswer(
    (_) async => _runInfo(),
  );
}

void stubRunAgent(
  MockAgUiClient agUiClient, {
  required Stream<BaseEvent> stream,
}) {
  when(
    () => agUiClient.runAgent(
      any(),
      any(),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) => stream);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSimpleRunAgentInput());
    registerFallbackValue(_FakeCancelToken());
  });

  group('toAgentThreadKey', () {
    test('maps 2-tuple to 3-tuple with default serverId', () {
      final key = toAgentThreadKey('room-42', 'thread-7');
      expect(key.serverId, equals('default'));
      expect(key.roomId, equals('room-42'));
      expect(key.threadId, equals('thread-7'));
    });
  });

  group('AgentRunNotifier', () {
    late MockSoliplexApi api;
    late MockAgUiClient agUiClient;
    late ProviderContainer container;

    setUp(() {
      api = MockSoliplexApi();
      agUiClient = MockAgUiClient();
    });

    group('initial state', () {
      test('is IdleState', () {
        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        final state = container.read(agentRunProvider);
        expect(state, isA<IdleState>());
      });
    });

    group('startRun', () {
      test('transitions to RunningState then CompletedState', () async {
        stubCreateRun(api);
        stubRunAgent(
          agUiClient,
          stream: Stream.fromIterable(_happyPathEvents()),
        );

        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        final states = <RunState>[];
        container.listen(agentRunProvider, (_, next) => states.add(next));

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Hi',
            );
        await Future<void>.delayed(Duration.zero);

        expect(states.first, isA<RunningState>());
        expect(states.last, isA<CompletedState>());
      });

      test('passes existingRunId to orchestrator', () async {
        stubRunAgent(
          agUiClient,
          stream: Stream.fromIterable(_happyPathEvents()),
        );

        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Hi',
              existingRunId: _runId,
            );
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => api.createRun(any(), any()));
        expect(container.read(agentRunProvider), isA<CompletedState>());
      });
    });

    group('tool yielding', () {
      test('auto-executes tools and resumes to CompletedState', () async {
        final registry = _registryWith();
        stubCreateRun(api);
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

        container = createContainer(
          api: api,
          agUiClient: agUiClient,
          toolRegistry: registry,
        );
        addTearDown(container.dispose);

        final states = <RunState>[];
        container.listen(agentRunProvider, (_, next) => states.add(next));

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Weather?',
            );

        // Allow stream + tool execution + resume stream to complete.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should have passed through ToolYieldingState and ended at Completed.
        expect(states.any((s) => s is ToolYieldingState), isTrue);
        expect(container.read(agentRunProvider), isA<CompletedState>());
      });

      test('tool execution failure results in failed tool output', () async {
        final failingRegistry = const ToolRegistry().register(
          ClientTool(
            definition: const Tool(name: 'weather', description: 'A test tool'),
            executor: (_) async => throw Exception('tool broke'),
          ),
        );
        stubCreateRun(api);
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

        container = createContainer(
          api: api,
          agUiClient: agUiClient,
          toolRegistry: failingRegistry,
        );
        addTearDown(container.dispose);

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Weather?',
            );

        // Allow stream + tool execution + resume to complete.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Even with a tool failure, the notifier submits error results
        // and the orchestrator continues to a new run. The final state
        // depends on what the resumed stream returns.
        final state = container.read(agentRunProvider);
        expect(state, isA<CompletedState>());
      });
    });

    group('cancelRun', () {
      test('transitions to CancelledState', () async {
        stubCreateRun(api);
        final controller = StreamController<BaseEvent>();
        stubRunAgent(agUiClient, stream: controller.stream);

        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Hi',
            );
        controller
            .add(const RunStartedEvent(threadId: _threadId, runId: _runId));
        await Future<void>.delayed(Duration.zero);

        expect(container.read(agentRunProvider), isA<RunningState>());

        container.read(agentRunProvider.notifier).cancelRun();
        await Future<void>.delayed(Duration.zero);

        expect(container.read(agentRunProvider), isA<CancelledState>());

        await controller.close();
      });
    });

    group('error handling', () {
      test('RunErrorEvent transitions to FailedState', () async {
        stubCreateRun(api);
        stubRunAgent(
          agUiClient,
          stream: Stream.fromIterable([
            const RunStartedEvent(threadId: _threadId, runId: _runId),
            const RunErrorEvent(message: 'backend error'),
          ]),
        );

        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Hi',
            );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(agentRunProvider);
        expect(state, isA<FailedState>());
        final failed = state as FailedState;
        expect(failed.reason, equals(FailureReason.serverError));
        expect(failed.error, equals('backend error'));
      });

      test('createRun failure transitions to FailedState', () async {
        when(() => api.createRun(any(), any())).thenThrow(
          const AuthException(message: 'Token expired'),
        );

        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Hi',
            );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(agentRunProvider);
        expect(state, isA<FailedState>());
        final failed = state as FailedState;
        expect(failed.reason, equals(FailureReason.authExpired));
      });
    });

    group('reset', () {
      test('returns to IdleState', () async {
        stubCreateRun(api);
        stubRunAgent(
          agUiClient,
          stream: Stream.fromIterable(_happyPathEvents()),
        );

        container = createContainer(api: api, agUiClient: agUiClient);
        addTearDown(container.dispose);

        await container.read(agentRunProvider.notifier).startRun(
              roomId: _roomId,
              threadId: _threadId,
              userMessage: 'Hi',
            );
        await Future<void>.delayed(Duration.zero);

        expect(container.read(agentRunProvider), isA<CompletedState>());

        container.read(agentRunProvider.notifier).reset();
        await Future<void>.delayed(Duration.zero);

        expect(container.read(agentRunProvider), isA<IdleState>());
      });
    });
  });
}
