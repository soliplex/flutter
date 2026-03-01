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

List<BaseEvent> _happyPathEvents(String text) => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-1'),
      TextMessageContentEvent(messageId: 'msg-1', delta: text),
      const TextMessageEndEvent(messageId: 'msg-1'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSimpleRunAgentInput());
    registerFallbackValue(_FakeCancelToken());
  });

  late MockSoliplexApi api;
  late MockAgUiClient agUiClient;
  late MockLogger logger;
  late AgentRuntime runtime;
  late RuntimeAgentApi agentApi;

  setUp(() {
    api = MockSoliplexApi();
    agUiClient = MockAgUiClient();
    logger = MockLogger();
    runtime = AgentRuntime(
      api: api,
      agUiClient: agUiClient,
      toolRegistryResolver: (_) async => const ToolRegistry(),
      platform: const NativePlatformConstraints(),
      logger: logger,
    );
    agentApi = RuntimeAgentApi(runtime: runtime);
  });

  tearDown(() async {
    await runtime.dispose();
  });

  void stubHappyPath(String text) {
    when(
      () => api.createThread(any()),
    ).thenAnswer((_) async => (_threadInfo(), <String, dynamic>{}));
    when(() => api.createRun(any(), any())).thenAnswer(
      (_) async =>
          RunInfo(id: _runId, threadId: _threadId, createdAt: DateTime(2026)),
    );
    when(() => api.deleteThread(any(), any())).thenAnswer((_) async {});
    when(
      () => agUiClient.runAgent(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => Stream.fromIterable(_happyPathEvents(text)));
  }

  group('RuntimeAgentApi', () {
    test('spawnAgent returns incrementing handles', () async {
      stubHappyPath('Hello');

      final h1 = await agentApi.spawnAgent(_roomId, 'prompt A');
      final h2 = await agentApi.spawnAgent(_roomId, 'prompt B');

      expect(h1, equals(1));
      expect(h2, equals(2));
    });

    test('getResult returns output text', () async {
      stubHappyPath('Agent output');

      final handle = await agentApi.spawnAgent(_roomId, 'test');
      final result = await agentApi.getResult(handle);

      expect(result, equals('Agent output'));
    });

    test('waitAll collects results from multiple sessions', () async {
      stubHappyPath('Result');

      final h1 = await agentApi.spawnAgent(_roomId, 'A');
      final h2 = await agentApi.spawnAgent(_roomId, 'B');

      final results = await agentApi.waitAll([h1, h2]);

      expect(results, hasLength(2));
      expect(results, everyElement(equals('Result')));
    });

    test('cancelAgent cancels session', () async {
      final controller = StreamController<BaseEvent>.broadcast();
      when(
        () => api.createThread(any()),
      ).thenAnswer((_) async => (_threadInfo(), <String, dynamic>{}));
      when(() => api.createRun(any(), any())).thenAnswer(
        (_) async =>
            RunInfo(id: _runId, threadId: _threadId, createdAt: DateTime(2026)),
      );
      when(() => api.deleteThread(any(), any())).thenAnswer((_) async {});
      when(
        () => agUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => controller.stream);

      final handle = await agentApi.spawnAgent(_roomId, 'test');
      controller.add(const RunStartedEvent(threadId: _threadId, runId: _runId));
      await Future<void>.delayed(Duration.zero);

      final cancelled = await agentApi.cancelAgent(handle);
      expect(cancelled, isTrue);

      await controller.close();
    });

    test('unknown handle throws ArgumentError', () async {
      expect(
        () => agentApi.getResult(999),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unknown agent handle'),
          ),
        ),
      );
    });

    test('waitAll with unknown handle throws ArgumentError', () async {
      expect(() => agentApi.waitAll([999]), throwsA(isA<ArgumentError>()));
    });

    test('cancelAgent with unknown handle throws ArgumentError', () async {
      expect(() => agentApi.cancelAgent(999), throwsA(isA<ArgumentError>()));
    });
  });
}
