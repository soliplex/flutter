import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain show Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

import '../../helpers/mock_agui_stream.dart';
import '../../helpers/test_helpers.dart';

void main() {
  late FakeAgUiClient fakeAgUiClient;
  late MockSoliplexApi mockApi;

  setUpAll(() {
    registerFallbackValue(const SimpleRunAgentInput(messages: []));
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    fakeAgUiClient = FakeAgUiClient();
    mockApi = MockSoliplexApi();
  });

  /// Creates a [ProviderContainer] wired to the fake AG-UI client and mock API.
  ProviderContainer createContainer({ToolRegistry? toolRegistry}) {
    return ProviderContainer(
      overrides: [
        agUiClientProvider.overrideWithValue(fakeAgUiClient),
        apiProvider.overrideWithValue(mockApi),
        if (toolRegistry != null)
          toolRegistryProvider.overrideWithValue(toolRegistry),
      ],
    );
  }

  /// Stubs [MockSoliplexApi.createRun] to return sequential run IDs.
  void stubCreateRun() {
    var callIndex = 0;
    when(
      () => mockApi.createRun(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      callIndex++;
      return RunInfo(
        id: 'run-$callIndex',
        threadId: 'thread-1',
        createdAt: DateTime.now(),
      );
    });
  }

  /// Standard events for a run that ends with pending tool calls.
  List<BaseEvent> toolCallEvents({
    String toolCallId = 'tc-1',
    String toolName = 'search',
    String args = '{"q":"dart"}',
  }) {
    return [
      const RunStartedEvent(threadId: 'thread-1', runId: 'run-1'),
      ToolCallStartEvent(
        toolCallId: toolCallId,
        toolCallName: toolName,
      ),
      ToolCallArgsEvent(toolCallId: toolCallId, delta: args),
      ToolCallEndEvent(toolCallId: toolCallId),
      const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'),
    ];
  }

  /// Standard events for a run that produces a text response.
  List<BaseEvent> textResponseEvents({
    String messageId = 'msg-1',
    String text = 'Here is the result.',
  }) {
    return [
      const RunStartedEvent(threadId: 'thread-1', runId: 'run-2'),
      TextMessageStartEvent(messageId: messageId),
      TextMessageContentEvent(messageId: messageId, delta: text),
      TextMessageEndEvent(messageId: messageId),
      const RunFinishedEvent(threadId: 'thread-1', runId: 'run-2'),
    ];
  }

  /// Creates a simple tool registry with the given tools.
  ToolRegistry buildRegistry(
    Map<String, Future<String> Function(ToolCallInfo)> tools,
  ) {
    var registry = const ToolRegistry();
    for (final entry in tools.entries) {
      registry = registry.register(
        ClientTool(
          definition: Tool(name: entry.key, description: entry.key),
          executor: entry.value,
        ),
      );
    }
    return registry;
  }

  group('ActiveRunNotifier tool call orchestration', () {
    group('happy path', () {
      test('single tool → continuation → text response', () async {
        final toolRegistry = buildRegistry({
          'search': (_) async => '{"results": ["found it"]}',
        });

        var runCallCount = 0;
        fakeAgUiClient.onRunAgent = (endpoint, input) {
          runCallCount++;
          if (runCallCount == 1) {
            return buildMockEventStream(toolCallEvents());
          }
          return buildMockEventStream(textResponseEvents());
        };

        stubCreateRun();

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Search for dart',
        );

        // Allow async tool execution + continuation to complete.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        final completed = state as CompletedState;
        expect(completed.result, isA<Success>());

        // Verify two runAgent calls: initial + continuation.
        expect(fakeAgUiClient.runAgentCallCount, 2);

        // Verify continuation run included tool call message.
        expect(
          completed.messages.whereType<ToolCallMessage>(),
          hasLength(1),
        );
      });

      test('two tool calls in same run → both executed → continuation',
          () async {
        final executionOrder = <String>[];
        final toolRegistry = buildRegistry({
          'search': (_) async {
            executionOrder.add('search');
            return 'search result';
          },
          'fetch': (_) async {
            executionOrder.add('fetch');
            return 'fetch result';
          },
        });

        var runCallCount = 0;
        fakeAgUiClient.onRunAgent = (endpoint, input) {
          runCallCount++;
          if (runCallCount == 1) {
            return buildMockEventStream([
              const RunStartedEvent(
                threadId: 'thread-1',
                runId: 'run-1',
              ),
              const ToolCallStartEvent(
                toolCallId: 'tc-1',
                toolCallName: 'search',
              ),
              const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
              const ToolCallEndEvent(toolCallId: 'tc-1'),
              const ToolCallStartEvent(
                toolCallId: 'tc-2',
                toolCallName: 'fetch',
              ),
              const ToolCallArgsEvent(toolCallId: 'tc-2', delta: '{}'),
              const ToolCallEndEvent(toolCallId: 'tc-2'),
              const RunFinishedEvent(
                threadId: 'thread-1',
                runId: 'run-1',
              ),
            ]);
          }
          return buildMockEventStream(textResponseEvents());
        };

        stubCreateRun();

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Search and fetch',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Both tools executed (in parallel).
        expect(executionOrder, containsAll(['search', 'fetch']));

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        expect((state as CompletedState).result, isA<Success>());
        expect(fakeAgUiClient.runAgentCallCount, 2);
      });

      test(
        'multi-hop: Run 1 → tools → Run 2 → tools → Run 3 → text',
        () async {
          final toolRegistry = buildRegistry({
            'step1': (_) async => 'step1 result',
            'step2': (_) async => 'step2 result',
          });

          var runCallCount = 0;
          fakeAgUiClient.onRunAgent = (endpoint, input) {
            runCallCount++;
            if (runCallCount == 1) {
              return buildMockEventStream([
                const RunStartedEvent(
                  threadId: 'thread-1',
                  runId: 'run-1',
                ),
                const ToolCallStartEvent(
                  toolCallId: 'tc-1',
                  toolCallName: 'step1',
                ),
                const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
                const ToolCallEndEvent(toolCallId: 'tc-1'),
                const RunFinishedEvent(
                  threadId: 'thread-1',
                  runId: 'run-1',
                ),
              ]);
            }
            if (runCallCount == 2) {
              return buildMockEventStream([
                const RunStartedEvent(
                  threadId: 'thread-1',
                  runId: 'run-2',
                ),
                const ToolCallStartEvent(
                  toolCallId: 'tc-2',
                  toolCallName: 'step2',
                ),
                const ToolCallArgsEvent(toolCallId: 'tc-2', delta: '{}'),
                const ToolCallEndEvent(toolCallId: 'tc-2'),
                const RunFinishedEvent(
                  threadId: 'thread-1',
                  runId: 'run-2',
                ),
              ]);
            }
            return buildMockEventStream(
              textResponseEvents(messageId: 'msg-3'),
            );
          };

          stubCreateRun();

          final container = createContainer(toolRegistry: toolRegistry);
          addTearDown(container.dispose);

          await container.read(activeRunNotifierProvider.notifier).startRun(
            key: (roomId: 'room-1', threadId: 'thread-1'),
            userMessage: 'Multi-hop',
          );

          await Future<void>.delayed(const Duration(milliseconds: 200));

          final state = container.read(activeRunNotifierProvider);
          expect(state, isA<CompletedState>());
          expect((state as CompletedState).result, isA<Success>());

          // 3 runAgent calls: initial + 2 continuations.
          expect(fakeAgUiClient.runAgentCallCount, 3);

          // Should have 2 ToolCallMessage entries.
          expect(
            state.messages.whereType<ToolCallMessage>(),
            hasLength(2),
          );
        },
      );
    });

    group('failure paths', () {
      test('tool throws → failed status → continuation still starts', () async {
        final toolRegistry = buildRegistry({
          'bad_tool': (_) async => throw Exception('tool crashed'),
        });

        var runCallCount = 0;
        fakeAgUiClient.onRunAgent = (endpoint, input) {
          runCallCount++;
          if (runCallCount == 1) {
            return buildMockEventStream([
              const RunStartedEvent(
                threadId: 'thread-1',
                runId: 'run-1',
              ),
              const ToolCallStartEvent(
                toolCallId: 'tc-1',
                toolCallName: 'bad_tool',
              ),
              const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
              const ToolCallEndEvent(toolCallId: 'tc-1'),
              const RunFinishedEvent(
                threadId: 'thread-1',
                runId: 'run-1',
              ),
            ]);
          }
          return buildMockEventStream(textResponseEvents());
        };

        stubCreateRun();

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Try bad tool',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Continuation should still happen (with failed tool result).
        expect(fakeAgUiClient.runAgentCallCount, 2);

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        expect((state as CompletedState).result, isA<Success>());

        // Tool call message should have failed status.
        final toolCallMsg = state.messages.whereType<ToolCallMessage>().first;
        expect(toolCallMsg.toolCalls.first.status, ToolCallStatus.failed);
      });

      test('createRun fails → CompletedState(FailedResult)', () async {
        final toolRegistry = buildRegistry({
          'search': (_) async => 'result',
        });

        fakeAgUiClient.onRunAgent = (endpoint, input) {
          return buildMockEventStream([
            const RunStartedEvent(threadId: 'thread-1', runId: 'run-1'),
            const ToolCallStartEvent(
              toolCallId: 'tc-1',
              toolCallName: 'search',
            ),
            const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
            const ToolCallEndEvent(toolCallId: 'tc-1'),
            const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'),
          ]);
        };

        // First createRun succeeds, second fails.
        var apiCallCount = 0;
        when(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          apiCallCount++;
          if (apiCallCount == 1) {
            return RunInfo(
              id: 'run-1',
              threadId: 'thread-1',
              createdAt: DateTime.now(),
            );
          }
          throw const NetworkException(message: 'API unreachable');
        });

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Test api failure',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        expect((state as CompletedState).result, isA<FailedResult>());
      });

      test('abort clears pending toolCalls from conversation', () async {
        final toolRegistry = buildRegistry({
          'search': (_) async => 'result',
        });

        fakeAgUiClient.onRunAgent = (endpoint, input) {
          return buildMockEventStream([
            const RunStartedEvent(threadId: 'thread-1', runId: 'run-1'),
            const ToolCallStartEvent(
              toolCallId: 'tc-1',
              toolCallName: 'search',
            ),
            const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
            const ToolCallEndEvent(toolCallId: 'tc-1'),
            const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'),
          ]);
        };

        // createRun succeeds first, then fails to trigger abort.
        var apiCallCount = 0;
        when(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          apiCallCount++;
          if (apiCallCount == 1) {
            return RunInfo(
              id: 'run-1',
              threadId: 'thread-1',
              createdAt: DateTime.now(),
            );
          }
          throw Exception('API error');
        });

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Test abort clears tools',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        // Tool calls should be cleared (not stranded).
        expect(state.conversation.toolCalls, isEmpty);
      });
    });

    group('cancellation', () {
      test('cancel during tool execution → CompletedState(CancelledResult)',
          () async {
        final toolStarted = Completer<void>();
        final toolRegistry = buildRegistry({
          'slow_tool': (_) async {
            toolStarted.complete();
            // Wait long enough for cancel to arrive.
            await Future<void>.delayed(const Duration(seconds: 5));
            return 'should not reach';
          },
        });

        fakeAgUiClient.onRunAgent = (endpoint, input) {
          return buildMockEventStream([
            const RunStartedEvent(threadId: 'thread-1', runId: 'run-1'),
            const ToolCallStartEvent(
              toolCallId: 'tc-1',
              toolCallName: 'slow_tool',
            ),
            const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
            const ToolCallEndEvent(toolCallId: 'tc-1'),
            const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'),
          ]);
        };

        stubCreateRun();

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Start slow tool',
        );

        // Wait for the tool to start executing.
        await toolStarted.future;

        // Cancel the run.
        await container.read(activeRunNotifierProvider.notifier).cancelRun();

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        expect((state as CompletedState).result, isA<CancelledResult>());

        // Only 1 runAgent call (no continuation).
        expect(fakeAgUiClient.runAgentCallCount, 1);
      });
    });

    group('circuit breaker', () {
      test('max depth exceeded → CompletedState(FailedResult)', () async {
        final toolRegistry = buildRegistry({
          'loop': (_) async => 'looping',
        });

        // Every run returns a tool call — infinite loop attempt.
        fakeAgUiClient.onRunAgent = (endpoint, input) {
          return buildMockEventStream([
            const RunStartedEvent(threadId: 'thread-1', runId: 'run-x'),
            const ToolCallStartEvent(
              toolCallId: 'tc-1',
              toolCallName: 'loop',
            ),
            const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{}'),
            const ToolCallEndEvent(toolCallId: 'tc-1'),
            const RunFinishedEvent(threadId: 'thread-1', runId: 'run-x'),
          ]);
        };

        stubCreateRun();

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Infinite loop',
        );

        // Allow time for multiple hops to complete.
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        expect((state as CompletedState).result, isA<FailedResult>());
        expect(
          (state.result as FailedResult).errorMessage,
          contains('depth limit'),
        );

        // Should have made exactly 11 runAgent calls:
        // initial + 10 continuations (depth 0-9), then circuit breaker at 10.
        expect(fakeAgUiClient.runAgentCallCount, 11);
      });
    });

    group('state transitions', () {
      test('ExecutingToolsState.isRunning is true', () {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const state = ExecutingToolsState(
          conversation: conversation,
          pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
        );

        expect(state.isRunning, isTrue);
      });

      test('transitions through ExecutingToolsState during tool execution',
          () async {
        final toolStarted = Completer<void>();
        final toolCompleter = Completer<String>();
        final toolRegistry = buildRegistry({
          'search': (_) async {
            toolStarted.complete();
            return toolCompleter.future;
          },
        });

        fakeAgUiClient.onRunAgent = (endpoint, input) {
          return buildMockEventStream(toolCallEvents());
        };

        stubCreateRun();

        final container = createContainer(toolRegistry: toolRegistry);
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Check executing state',
        );

        // Wait for tool to start.
        await toolStarted.future;

        // Should be in ExecutingToolsState.
        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<ExecutingToolsState>());
        expect(state.isRunning, isTrue);

        final executingState = state as ExecutingToolsState;
        expect(executingState.pendingTools, hasLength(1));
        expect(executingState.pendingTools.first.name, 'search');

        // Complete the tool and let continuation finish.
        toolCompleter.complete('result');
      });

      test(
        'isStreamingProvider returns true during ExecutingToolsState',
        () async {
          final toolStarted = Completer<void>();
          final toolCompleter = Completer<String>();
          final toolRegistry = buildRegistry({
            'search': (_) async {
              toolStarted.complete();
              return toolCompleter.future;
            },
          });

          fakeAgUiClient.onRunAgent = (endpoint, input) {
            return buildMockEventStream(toolCallEvents());
          };

          stubCreateRun();

          final container = createContainer(toolRegistry: toolRegistry);
          addTearDown(container.dispose);

          await container.read(activeRunNotifierProvider.notifier).startRun(
            key: (roomId: 'room-1', threadId: 'thread-1'),
            userMessage: 'Check streaming provider',
          );

          await toolStarted.future;

          // isStreamingProvider uses isRunning, which includes
          // ExecutingToolsState.
          expect(container.read(isStreamingProvider), isTrue);

          toolCompleter.complete('done');
        },
      );

      test('no tools → completes normally without ExecutingToolsState',
          () async {
        fakeAgUiClient.onRunAgent = (endpoint, input) {
          return buildMockEventStream(textResponseEvents());
        };

        stubCreateRun();

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(activeRunNotifierProvider.notifier).startRun(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          userMessage: 'Just text',
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        expect((state as CompletedState).result, isA<Success>());

        // Only 1 runAgent call — no continuation.
        expect(fakeAgUiClient.runAgentCallCount, 1);
      });
    });
  });
}
