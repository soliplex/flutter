import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:signals_core/signals_core.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiStreamClient, SoliplexApi;
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_tui/src/tool_definitions.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockSoliplexApi extends Mock implements SoliplexApi {}

class _MockAgUiStreamClient extends Mock implements AgUiStreamClient {}

class _MockLogger extends Mock implements Logger {}

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

RunInfo _runInfo() =>
    RunInfo(id: _runId, threadId: _threadId, createdAt: DateTime(2026));

List<BaseEvent> _textEvents({String text = 'Hello from agent'}) => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-1'),
      TextMessageContentEvent(messageId: 'msg-1', delta: text),
      const TextMessageEndEvent(messageId: 'msg-1'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

List<BaseEvent> _toolCallThenTextEvents({
  String toolName = 'secret_number',
  String toolCallId = 'tc-1',
  String args = '{}',
}) =>
    [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      ToolCallStartEvent(toolCallId: toolCallId, toolCallName: toolName),
      ToolCallArgsEvent(toolCallId: toolCallId, delta: args),
      ToolCallEndEvent(toolCallId: toolCallId),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

List<BaseEvent> _resumeTextEvents({String text = 'The answer is 42'}) => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-2'),
      TextMessageContentEvent(messageId: 'msg-2', delta: text),
      const TextMessageEndEvent(messageId: 'msg-2'),
      const RunFinishedEvent(threadId: _threadId, runId: _runId),
    ];

List<BaseEvent> _errorEvents({String message = 'Backend failure'}) => [
      const RunStartedEvent(threadId: _threadId, runId: _runId),
      RunErrorEvent(message: message),
    ];

// ---------------------------------------------------------------------------
// JSON envelope builder — mirrors _runHeadlessJson logic
// ---------------------------------------------------------------------------

/// Runs the headless JSON pipeline against a mocked runtime and returns
/// the parsed JSON envelope.
Future<Map<String, dynamic>> runJsonPipeline({
  required AgentRuntime runtime,
  required List<String> messages,
}) async {
  final sw = Stopwatch()..start();
  final seenToolIds = <String>{};
  final allToolCalls = <Map<String, dynamic>>[];
  final errors = <String>[];
  var turns = 0;
  String? agentOutput;

  for (final message in messages) {
    turns++;

    final session = await runtime.spawn(
      roomId: _roomId,
      prompt: message,
      threadId: _threadId,
    );

    final cleanup = effect(() {
      final state = session.runState.value;
      if (state is ToolYieldingState) {
        for (final tc in state.pendingToolCalls) {
          if (seenToolIds.add(tc.id)) {
            allToolCalls.add({
              'id': tc.id,
              'name': tc.name,
              if (tc.hasArguments) 'arguments': tc.arguments,
            });
          }
        }
      }
    });

    final result = await session.result;
    cleanup();

    switch (result) {
      case AgentSuccess(:final output):
        agentOutput = output;
      case AgentFailure(:final error):
        errors.add(error);
      case AgentTimedOut(:final elapsed):
        errors.add('Timed out after $elapsed');
    }
  }

  sw.stop();

  return {
    'status': errors.isEmpty ? 'ok' : 'error',
    'turns': turns,
    'wall_time_ms': sw.elapsedMilliseconds,
    'agent_result': agentOutput,
    'tool_calls': allToolCalls,
    if (errors.isNotEmpty) 'errors': errors,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSimpleRunAgentInput());
    registerFallbackValue(_FakeCancelToken());
  });

  late _MockSoliplexApi api;
  late _MockAgUiStreamClient agUiStreamClient;
  late _MockLogger logger;

  AgentRuntime createRuntime({ToolRegistry? toolRegistry}) {
    return AgentRuntime(
      connection: ServerConnection(
        serverId: 'default',
        api: api,
        agUiStreamClient: agUiStreamClient,
      ),
      llmProvider: AgUiLlmProvider(
        api: api,
        agUiStreamClient: agUiStreamClient,
      ),
      toolRegistryResolver: (_) async => toolRegistry ?? const ToolRegistry(),
      platform: const NativePlatformConstraints(),
      logger: logger,
    );
  }

  void stubCreateThread() {
    when(
      () => api.createThread(any()),
    ).thenAnswer((_) async => (_threadInfo(), <String, dynamic>{}));
  }

  void stubCreateRun() {
    when(() => api.createRun(any(), any())).thenAnswer((_) async => _runInfo());
  }

  var runAgentCallCount = 0;

  void stubRunAgent(List<Stream<BaseEvent>> streams) {
    runAgentCallCount = 0;
    when(
      () => agUiStreamClient.runAgent(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) {
      final stream = streams[runAgentCallCount];
      runAgentCallCount++;
      return stream;
    });
  }

  setUp(() {
    api = _MockSoliplexApi();
    agUiStreamClient = _MockAgUiStreamClient();
    logger = _MockLogger();
  });

  group('L1 headless JSON', () {
    test('single-turn text response produces valid envelope', () async {
      stubCreateThread();
      stubCreateRun();
      stubRunAgent([Stream.fromIterable(_textEvents())]);

      final runtime = createRuntime();
      addTearDown(runtime.dispose);

      final envelope = await runJsonPipeline(
        runtime: runtime,
        messages: ['hello'],
      );

      expect(envelope['status'], 'ok');
      expect(envelope['turns'], 1);
      expect(envelope['wall_time_ms'], isA<int>());
      expect(envelope['agent_result'], 'Hello from agent');
      expect(envelope['tool_calls'], isEmpty);
      expect(envelope.containsKey('errors'), isFalse);

      // Verify it serializes to valid JSON.
      final json = jsonEncode(envelope);
      expect(() => jsonDecode(json), returnsNormally);
    });

    test('tool call is collected in envelope', () async {
      stubCreateThread();
      stubCreateRun();
      stubRunAgent([
        Stream.fromIterable(_toolCallThenTextEvents()),
        Stream.fromIterable(_resumeTextEvents()),
      ]);

      final registry = buildDemoToolRegistry(enabledTools: {'secret_number'});
      final runtime = createRuntime(toolRegistry: registry);
      addTearDown(runtime.dispose);

      final envelope = await runJsonPipeline(
        runtime: runtime,
        messages: ['what is the secret number?'],
      );

      expect(envelope['status'], 'ok');
      expect(envelope['agent_result'], 'The answer is 42');
      expect(envelope['tool_calls'], isA<List<dynamic>>());

      final toolCalls =
          (envelope['tool_calls'] as List).cast<Map<String, dynamic>>();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first['name'], 'secret_number');
      expect(toolCalls.first['id'], 'tc-1');
    });

    test('agent error produces error envelope', () async {
      stubCreateThread();
      stubCreateRun();
      stubRunAgent([Stream.fromIterable(_errorEvents())]);

      final runtime = createRuntime();
      addTearDown(runtime.dispose);

      final envelope = await runJsonPipeline(
        runtime: runtime,
        messages: ['cause error'],
      );

      expect(envelope['status'], 'error');
      expect(envelope['turns'], 1);
      expect(envelope['errors'], isA<List<dynamic>>());
      expect(envelope['errors'] as List<dynamic>, isNotEmpty);
      expect(envelope['agent_result'], isNull);
    });

    test('multi-turn counts turns correctly', () async {
      stubCreateThread();
      stubCreateRun();
      stubRunAgent([
        Stream.fromIterable(_textEvents(text: 'first')),
        Stream.fromIterable(_textEvents(text: 'second')),
      ]);

      final runtime = createRuntime();
      addTearDown(runtime.dispose);

      final envelope = await runJsonPipeline(
        runtime: runtime,
        messages: ['msg1', 'msg2'],
      );

      expect(envelope['status'], 'ok');
      expect(envelope['turns'], 2);
      // agent_result is the last turn's output.
      expect(envelope['agent_result'], 'second');
    });

    test('tool call IDs are deduplicated', () async {
      stubCreateThread();
      stubCreateRun();
      // Same tool call ID appears in the yield — should only be
      // collected once.
      stubRunAgent([
        Stream.fromIterable(_toolCallThenTextEvents()),
        Stream.fromIterable(_resumeTextEvents()),
      ]);

      final registry = buildDemoToolRegistry(enabledTools: {'secret_number'});
      final runtime = createRuntime(toolRegistry: registry);
      addTearDown(runtime.dispose);

      final envelope = await runJsonPipeline(
        runtime: runtime,
        messages: ['test dedup'],
      );

      final toolCalls =
          (envelope['tool_calls'] as List).cast<Map<String, dynamic>>();
      final ids = toolCalls.map((tc) => tc['id']).toSet();
      // No duplicates.
      expect(ids.length, toolCalls.length);
    });
  });
}
