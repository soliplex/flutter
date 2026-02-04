import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Conversation, Failed, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_notifier.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockAgUiClient mockAgUiClient;
  late MockSoliplexApi mockApi;

  setUpAll(() {
    registerFallbackValue(const SimpleRunAgentInput(messages: []));
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    mockAgUiClient = MockAgUiClient();
    mockApi = MockSoliplexApi();
  });

  group('ActiveRunNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('starts in IdleState', () {
        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<IdleState>());
      });

      test('isRunning is false initially', () {
        final state = container.read(activeRunNotifierProvider);
        expect(state.isRunning, isFalse);
      });

      test('IdleState has empty sentinel conversation', () {
        final state = container.read(activeRunNotifierProvider);
        expect(state.messages, isEmpty);
        expect(state.conversation.threadId, isEmpty);
      });
    });

    group('reset', () {
      test('returns to IdleState', () async {
        await container.read(activeRunNotifierProvider.notifier).reset();

        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<IdleState>());
      });

      test('clears messages', () async {
        await container.read(activeRunNotifierProvider.notifier).reset();

        final state = container.read(activeRunNotifierProvider);
        expect(state.messages, isEmpty);
      });

      test('clears state immediately and awaits disposal', () async {
        final eventStreamController = StreamController<BaseEvent>();
        var disposeCalled = false;
        final disposeCompleter = Completer<void>();

        when(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => RunInfo(
            id: 'run-1',
            threadId: 'thread-1',
            createdAt: DateTime.now(),
          ),
        );

        when(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) => eventStreamController.stream);

        final testContainer = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
          ],
        );

        addTearDown(() {
          eventStreamController.close();
          testContainer.dispose();
        });

        // Start a run
        await testContainer.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Hello',
            );

        // Verify running
        expect(
          testContainer.read(activeRunNotifierProvider),
          isA<RunningState>(),
        );

        // Capture the cancel token to track disposal
        final capturedToken = verify(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: captureAny(named: 'cancelToken'),
          ),
        ).captured.single as CancelToken;

        // Override the stream subscription's cancel to track disposal
        eventStreamController.onCancel = () {
          disposeCalled = true;
          disposeCompleter.complete();
        };

        // Call reset
        final resetFuture =
            testContainer.read(activeRunNotifierProvider.notifier).reset();

        // State should be IdleState immediately
        expect(testContainer.read(activeRunNotifierProvider), isA<IdleState>());

        // Token should be cancelled
        expect(capturedToken.isCancelled, isTrue);

        // Wait for reset to complete
        await resetFuture;

        // Disposal should have completed
        expect(disposeCalled, isTrue);
      });

      test('calling reset multiple times is idempotent', () async {
        final eventStreamController = StreamController<BaseEvent>.broadcast();

        when(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => RunInfo(
            id: 'run-1',
            threadId: 'thread-1',
            createdAt: DateTime.now(),
          ),
        );

        when(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) => eventStreamController.stream);

        final testContainer = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
          ],
        );

        addTearDown(() {
          eventStreamController.close();
          testContainer.dispose();
        });

        // Start a run
        await testContainer.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Hello',
            );

        // Call reset multiple times in quick succession
        final futures = <Future<void>>[];
        for (var i = 0; i < 5; i++) {
          futures.add(
            testContainer.read(activeRunNotifierProvider.notifier).reset(),
          );
        }

        // All futures should complete without exception
        await Future.wait(futures);

        // Final state should be idle
        expect(testContainer.read(activeRunNotifierProvider), isA<IdleState>());
      });
    });

    group('state type checks', () {
      test('isRunning returns correct value for each state type', () {
        // IdleState
        expect(const IdleState().isRunning, isFalse);

        // RunningState
        const runningConversation = domain.Conversation(
          threadId: 't',
          status: domain.Running(runId: 'r'),
        );
        expect(
          const RunningState(conversation: runningConversation).isRunning,
          isTrue,
        );

        // CompletedState with Success
        const completedConversation = domain.Conversation(
          threadId: 't',
          status: domain.Completed(),
        );
        expect(
          const CompletedState(
            conversation: completedConversation,
            result: Success(),
          ).isRunning,
          isFalse,
        );

        // CompletedState with Failed
        const failedConversation = domain.Conversation(
          threadId: 't',
          status: domain.Failed(error: 'Error'),
        );
        expect(
          const CompletedState(
            conversation: failedConversation,
            result: FailedResult(errorMessage: 'Error'),
          ).isRunning,
          isFalse,
        );

        // CompletedState with Cancelled
        const cancelledConversation = domain.Conversation(
          threadId: 't',
          status: domain.Cancelled(reason: 'User cancelled'),
        );
        expect(
          const CompletedState(
            conversation: cancelledConversation,
            result: CancelledResult(reason: 'User cancelled'),
          ).isRunning,
          isFalse,
        );
      });
    });

    group('convenience getters', () {
      test('messages delegates to conversation.messages', () {
        final message = TextMessage.create(
          id: 'msg-1',
          user: ChatUser.user,
          text: 'Hello',
        );
        final conversation = domain.Conversation(
          threadId: 'thread-1',
          messages: [message],
          status: const domain.Running(runId: 'r'),
        );
        final state = RunningState(conversation: conversation);

        expect(state.messages, [message]);
      });

      test('activeToolCalls delegates to conversation.toolCalls', () {
        const toolCall = ToolCallInfo(id: 'tc-1', name: 'search');
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          toolCalls: [toolCall],
          status: domain.Running(runId: 'r'),
        );
        const state = RunningState(conversation: conversation);

        expect(state.activeToolCalls, [toolCall]);
      });

      test('streaming defaults to AwaitingText', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'r'),
        );
        const state = RunningState(conversation: conversation);

        expect(state.streaming, isA<AwaitingText>());
      });

      test('isStreaming returns true when TextStreaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'r'),
        );
        const state = RunningState(
          conversation: conversation,
          streaming: TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: 'Hello',
          ),
        );

        expect(state.isStreaming, isTrue);
      });
    });
  });

  group('NotifierInternalState', () {
    test('IdleInternalState can be created', () {
      const state = IdleInternalState();
      expect(state, isA<NotifierInternalState>());
    });

    test('RunningInternalState holds resources', () {
      final cancelToken = CancelToken();
      final controller = StreamController<BaseEvent>();

      final state = RunningInternalState(
        runId: 'test-run-id',
        cancelToken: cancelToken,
        subscription: controller.stream.listen((_) {}),
        userMessageId: 'user_123',
        previousAguiState: const <String, dynamic>{},
      );

      expect(state, isA<NotifierInternalState>());
      expect(state.runId, equals('test-run-id'));
      expect(state.cancelToken, equals(cancelToken));

      // Cleanup
      controller.close();
      state.dispose();
    });
  });

  group('startRun', () {
    late ProviderContainer container;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      eventStreamController = StreamController<BaseEvent>();

      // Mock createRun to return a run with backend-generated ID
      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'backend-run-id-123',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      // Mock runAgent to return our controlled stream
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);

      container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );
    });

    tearDown(() {
      eventStreamController.close();
      container.dispose();
    });

    test('displays user message immediately when starting run', () async {
      const userMessage = 'Hello, world!';
      const roomId = 'room-1';
      const threadId = 'thread-1';

      // Start the run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: roomId,
            threadId: threadId,
            userMessage: userMessage,
          );

      // Get the current state
      final state = container.read(activeRunNotifierProvider);

      // Verify state is running
      expect(state, isA<RunningState>());
      expect(state.isRunning, isTrue);

      // Verify user message is in the messages list
      expect(state.messages.length, 1);
      final message = state.messages.first;
      expect(message, isA<TextMessage>());
      expect(message.user, ChatUser.user);
      expect((message as TextMessage).text, userMessage);
    });

    test(
      'transitions to RunningState with correct thread and run IDs',
      () async {
        const roomId = 'room-1';
        const threadId = 'thread-1';

        await container
            .read(activeRunNotifierProvider.notifier)
            .startRun(roomId: roomId, threadId: threadId, userMessage: 'Test');

        final state = container.read(activeRunNotifierProvider);

        expect(state, isA<RunningState>());
        final runningState = state as RunningState;
        expect(runningState.threadId, threadId);
        expect(runningState.runId, 'backend-run-id-123');
      },
    );

    test('uses existingRunId when provided instead of creating new', () async {
      const roomId = 'room-1';
      const threadId = 'thread-1';
      const existingRunId = 'existing-run-456';

      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: roomId,
            threadId: threadId,
            userMessage: 'Test',
            existingRunId: existingRunId,
          );

      final state = container.read(activeRunNotifierProvider);

      expect(state, isA<RunningState>());
      final runningState = state as RunningState;
      expect(runningState.runId, existingRunId);

      // Verify createRun was NOT called
      verifyNever(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('treats empty existingRunId same as null', () async {
      const roomId = 'room-1';
      const threadId = 'thread-1';

      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: roomId,
            threadId: threadId,
            userMessage: 'Test',
            existingRunId: '',
          );

      final state = container.read(activeRunNotifierProvider);

      expect(state, isA<RunningState>());
      final runningState = state as RunningState;
      expect(runningState.runId, 'backend-run-id-123');

      // Verify createRun WAS called (empty string treated as null)
      verify(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('throws StateError if run already active', () async {
      const roomId = 'room-1';
      const threadId = 'thread-1';

      // Start first run
      await container
          .read(activeRunNotifierProvider.notifier)
          .startRun(roomId: roomId, threadId: threadId, userMessage: 'First');

      // Attempt to start second run
      expect(
        () => container.read(activeRunNotifierProvider.notifier).startRun(
              roomId: roomId,
              threadId: threadId,
              userMessage: 'Second',
            ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('cancelRun', () {
    late ProviderContainer container;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      eventStreamController = StreamController<BaseEvent>();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);

      container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );
    });

    tearDown(() {
      eventStreamController.close();
      container.dispose();
    });

    test('transitions to CompletedState with Cancelled result', () async {
      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Cancel the run
      await container.read(activeRunNotifierProvider.notifier).cancelRun();

      final state = container.read(activeRunNotifierProvider);
      expect(state, isA<CompletedState>());
      final completedState = state as CompletedState;
      expect(completedState.result, isA<CancelledResult>());
    });

    test('preserves messages after cancellation', () async {
      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Cancel the run
      await container.read(activeRunNotifierProvider.notifier).cancelRun();

      final state = container.read(activeRunNotifierProvider);
      expect(state.messages.length, 1);
      expect((state.messages.first as TextMessage).text, 'Hello');
    });
  });

  group('thread change behavior', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      eventStreamController = StreamController<BaseEvent>.broadcast();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test('resets state when switching from one thread to another', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          threadSelectionProvider.overrideWith(ThreadSelectionNotifier.new),
        ],
      );

      addTearDown(container.dispose);

      // Select thread A
      container
          .read(threadSelectionProvider.notifier)
          .set(const ThreadSelected('thread-a'));

      // Start a run on thread A
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-a',
            userMessage: 'Hello from thread A',
          );

      // Verify running with messages
      expect(container.read(activeRunNotifierProvider), isA<RunningState>());
      expect(container.read(activeRunNotifierProvider).messages, isNotEmpty);

      // Switch to thread B
      container
          .read(threadSelectionProvider.notifier)
          .set(const ThreadSelected('thread-b'));

      // Allow listener to fire
      await Future<void>.delayed(Duration.zero);

      // State should be reset to IdleState
      expect(container.read(activeRunNotifierProvider), isA<IdleState>());
      expect(container.read(activeRunNotifierProvider).messages, isEmpty);
    });

    test('does not reset when selecting the same thread again', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          threadSelectionProvider.overrideWith(ThreadSelectionNotifier.new),
        ],
      );

      addTearDown(container.dispose);

      // Select thread A
      container
          .read(threadSelectionProvider.notifier)
          .set(const ThreadSelected('thread-a'));

      // Start a run on thread A
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-a',
            userMessage: 'Hello from thread A',
          );

      // Verify running with messages
      expect(container.read(activeRunNotifierProvider), isA<RunningState>());

      // Select thread A again (same thread)
      container
          .read(threadSelectionProvider.notifier)
          .set(const ThreadSelected('thread-a'));

      // Allow any listener to fire
      await Future<void>.delayed(Duration.zero);

      // State should still be RunningState (not reset)
      expect(container.read(activeRunNotifierProvider), isA<RunningState>());
      expect(container.read(activeRunNotifierProvider).messages, isNotEmpty);
    });

    test('does not reset when initially selecting a thread', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          threadSelectionProvider.overrideWith(ThreadSelectionNotifier.new),
        ],
      );

      addTearDown(container.dispose);

      // Verify initial state is NoThreadSelected
      expect(container.read(threadSelectionProvider), isA<NoThreadSelected>());

      // Read the notifier to initialize it
      container.read(activeRunNotifierProvider);

      // Initial state should be IdleState
      expect(container.read(activeRunNotifierProvider), isA<IdleState>());

      // Select a thread for the first time (null -> threadId)
      container
          .read(threadSelectionProvider.notifier)
          .set(const ThreadSelected('thread-a'));

      // Allow listener to fire
      await Future<void>.delayed(Duration.zero);

      // State should still be IdleState (no reset triggered)
      // The key is that reset() was NOT called unnecessarily
      expect(container.read(activeRunNotifierProvider), isA<IdleState>());
    });
  });

  group('cache update on completion', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      eventStreamController = StreamController<BaseEvent>();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test('updates cache when RUN_FINISHED event is received', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Verify running
      expect(container.read(activeRunNotifierProvider), isA<RunningState>());

      // Cache should be empty initially
      final cacheBefore = container.read(threadHistoryCacheProvider);
      expect(cacheBefore['thread-1'], isNull);

      // Send RUN_FINISHED event
      eventStreamController.add(
        const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'),
      );

      // Allow event to be processed
      await Future<void>.delayed(Duration.zero);

      // Verify state is CompletedState
      expect(container.read(activeRunNotifierProvider), isA<CompletedState>());

      // Cache should now contain the messages
      final cacheAfter = container.read(threadHistoryCacheProvider);
      expect(cacheAfter['thread-1'], isNotNull);
      expect(cacheAfter['thread-1']!.messages, hasLength(1));
      expect(
        (cacheAfter['thread-1']!.messages.first as TextMessage).text,
        'Hello',
      );
    });

    test('updates cache when RUN_ERROR event is received', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Cache should be empty initially
      final cacheBefore = container.read(threadHistoryCacheProvider);
      expect(cacheBefore['thread-1'], isNull);

      // Send RUN_ERROR event
      eventStreamController.add(const RunErrorEvent(message: 'Test error'));

      // Allow event to be processed
      await Future<void>.delayed(Duration.zero);

      // Verify state is CompletedState with failure
      final state = container.read(activeRunNotifierProvider);
      expect(state, isA<CompletedState>());
      expect((state as CompletedState).result, isA<FailedResult>());

      // Cache should still contain the messages (even on error)
      final cacheAfter = container.read(threadHistoryCacheProvider);
      expect(cacheAfter['thread-1'], isNotNull);
      expect(cacheAfter['thread-1']!.messages, hasLength(1));
    });
  });

  group('stream error handling', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      eventStreamController = StreamController<BaseEvent>();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test('stream onError transitions to Failed state', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Verify running
      expect(container.read(activeRunNotifierProvider), isA<RunningState>());

      // Emit an error on the stream
      eventStreamController.addError(Exception('Network connection lost'));

      // Allow error to be processed
      await Future<void>.delayed(Duration.zero);

      // Verify state is CompletedState with FailedResult
      final state = container.read(activeRunNotifierProvider);
      expect(state, isA<CompletedState>());
      final completedState = state as CompletedState;
      expect(completedState.result, isA<FailedResult>());
      expect(
        (completedState.result as FailedResult).errorMessage,
        contains('Network connection lost'),
      );
    });

    test('stream onError updates cache with messages', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Add some events before error
      eventStreamController
        ..add(const TextMessageStartEvent(messageId: 'msg-1'))
        ..add(
          const TextMessageContentEvent(
            messageId: 'msg-1',
            delta: 'Response text',
          ),
        );
      await Future<void>.delayed(Duration.zero);

      // Emit error
      eventStreamController.addError(Exception('Stream error'));
      await Future<void>.delayed(Duration.zero);

      // Verify cache was updated despite error
      final cache = container.read(threadHistoryCacheProvider);
      expect(cache['thread-1'], isNotNull);
      expect(cache['thread-1']!.messages.length, greaterThan(0));
    });

    test(
      'stream onDone without RUN_FINISHED transitions to Completed',
      () async {
        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
          ],
        );

        addTearDown(container.dispose);

        // Start a run
        await container.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Hello',
            );

        // Verify running
        expect(container.read(activeRunNotifierProvider), isA<RunningState>());

        // Close stream without sending RUN_FINISHED
        await eventStreamController.close();

        // Allow onDone to be processed
        await Future<void>.delayed(Duration.zero);

        // Verify state is CompletedState with Success
        final state = container.read(activeRunNotifierProvider);
        expect(state, isA<CompletedState>());
        final completedState = state as CompletedState;
        expect(completedState.result, isA<Success>());
      },
    );

    test('stream onDone updates cache with messages', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Add some events
      eventStreamController
        ..add(const TextMessageStartEvent(messageId: 'msg-1'))
        ..add(
          const TextMessageContentEvent(
            messageId: 'msg-1',
            delta: 'Response text',
          ),
        );
      await Future<void>.delayed(Duration.zero);

      // Close stream
      await eventStreamController.close();
      await Future<void>.delayed(Duration.zero);

      // Verify cache was updated
      final cache = container.read(threadHistoryCacheProvider);
      expect(cache['thread-1'], isNotNull);
      expect(cache['thread-1']!.messages.length, greaterThan(0));
    });
  });

  group('event processing race conditions', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      eventStreamController = StreamController<BaseEvent>.broadcast();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test('ignores events when not in RunningState', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Verify running
      expect(container.read(activeRunNotifierProvider), isA<RunningState>());

      // Reset to IdleState
      await container.read(activeRunNotifierProvider.notifier).reset();
      expect(container.read(activeRunNotifierProvider), isA<IdleState>());

      // Add events after reset (simulating race condition)
      eventStreamController.add(
        const TextMessageContentEvent(
          messageId: 'msg-1',
          delta: 'Should be ignored',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // State should still be IdleState
      final state = container.read(activeRunNotifierProvider);
      expect(state, isA<IdleState>());
      expect(state.messages, isEmpty);
    });

    test('ignores events after RUN_FINISHED completes', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Send RUN_FINISHED
      eventStreamController.add(
        const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'),
      );
      await Future<void>.delayed(Duration.zero);

      // State should be CompletedState
      expect(container.read(activeRunNotifierProvider), isA<CompletedState>());
      final messageCountAfterCompletion =
          container.read(activeRunNotifierProvider).messages.length;

      // Send more events (race condition)
      eventStreamController.add(
        const TextMessageContentEvent(messageId: 'msg-2', delta: 'Late event'),
      );
      await Future<void>.delayed(Duration.zero);

      // Message count should not change
      expect(
        container.read(activeRunNotifierProvider).messages.length,
        equals(messageCountAfterCompletion),
      );
    });
  });

  group('CancellationError handling', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );
    });

    test('CancellationError transitions to CancelledResult', () async {
      // Setup stream that throws CancellationError
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(const CancellationError('Cancelled'));

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run (will immediately throw CancellationError)
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // State should be CompletedState with CancelledResult
      final state = container.read(activeRunNotifierProvider);
      expect(state, isA<CompletedState>());
      final completedState = state as CompletedState;
      expect(completedState.result, isA<CancelledResult>());
      expect(
        (completedState.result as CancelledResult).reason,
        equals('Cancelled'),
      );
    });

    test('CancellationError preserves user message', () async {
      // Setup stream that throws CancellationError
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(const CancellationError('Cancelled'));

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Test message',
          );

      // Messages should still contain the user message
      final state = container.read(activeRunNotifierProvider);
      expect(state.messages, hasLength(1));
      expect((state.messages.first as TextMessage).text, 'Test message');
    });

    test('CancellationError updates cache', () async {
      // Setup stream that throws CancellationError
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(const CancellationError('Cancelled'));

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Test message',
          );

      // Cache should be updated
      final cache = container.read(threadHistoryCacheProvider);
      expect(cache['thread-1'], isNotNull);
      expect(cache['thread-1']!.messages, hasLength(1));
    });
  });

  group('concurrent startRun protection', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      eventStreamController = StreamController<BaseEvent>();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test('concurrent startRun calls are rejected', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Start two runs concurrently without awaiting
      final notifier = container.read(activeRunNotifierProvider.notifier);
      final future1 = notifier.startRun(
        roomId: 'room-1',
        threadId: 'thread-1',
        userMessage: 'First',
      );
      final future2 = notifier.startRun(
        roomId: 'room-1',
        threadId: 'thread-2',
        userMessage: 'Second',
      );

      // Second call should throw StateError
      await expectLater(future2, throwsA(isA<StateError>()));

      // First call should complete successfully
      await future1;

      // State should reflect first call
      final state = container.read(activeRunNotifierProvider);
      expect(state, isA<RunningState>());
      expect(state.conversation.threadId, equals('thread-1'));
    });
  });

  group('history preservation', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      eventStreamController = StreamController<BaseEvent>();

      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.now(),
        ),
      );

      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test(
      'includes cached messages in Conversation when starting run',
      () async {
        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
          ],
        );

        addTearDown(container.dispose);

        // Pre-populate cache with historical messages
        final historicalMessages = [
          TextMessage.create(
            id: 'hist-1',
            user: ChatUser.user,
            text: 'First question',
          ),
          TextMessage.create(
            id: 'hist-2',
            user: ChatUser.assistant,
            text: 'First answer',
          ),
        ];
        container.read(threadHistoryCacheProvider.notifier).updateHistory(
              'thread-1',
              ThreadHistory(messages: historicalMessages),
            );

        // Start a new run
        await container.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Second question',
            );

        // Verify state includes all messages (history + new)
        final state = container.read(activeRunNotifierProvider);
        expect(state.messages, hasLength(3));
        expect((state.messages[0] as TextMessage).text, 'First question');
        expect((state.messages[1] as TextMessage).text, 'First answer');
        expect((state.messages[2] as TextMessage).text, 'Second question');
      },
    );

    test('sends complete history to backend in AG-UI format', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Pre-populate cache with historical messages
      final historicalMessages = [
        TextMessage.create(
          id: 'hist-1',
          user: ChatUser.user,
          text: 'First question',
        ),
        TextMessage.create(
          id: 'hist-2',
          user: ChatUser.assistant,
          text: 'First answer',
        ),
      ];
      container.read(threadHistoryCacheProvider.notifier).updateHistory(
            'thread-1',
            ThreadHistory(messages: historicalMessages),
          );

      // Start a new run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Second question',
          );

      // Capture the input sent to the backend
      final captured = verify(
        () => mockAgUiClient.runAgent(
          any(),
          captureAny(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).captured.single as SimpleRunAgentInput;

      // Verify all messages were sent (history + new)
      final messages = captured.messages!;
      expect(messages, hasLength(3));
      expect(messages[0], isA<UserMessage>());
      expect((messages[0] as UserMessage).content, 'First question');
      expect(messages[1], isA<AssistantMessage>());
      expect((messages[1] as AssistantMessage).content, 'First answer');
      expect(messages[2], isA<UserMessage>());
      expect((messages[2] as UserMessage).content, 'Second question');
    });

    test('preserves messages from multiple runs in sequence', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // First run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'First message',
          );

      // Simulate assistant response
      eventStreamController
        ..add(const TextMessageStartEvent(messageId: 'resp-1'))
        ..add(
          const TextMessageContentEvent(
            messageId: 'resp-1',
            delta: 'First response',
          ),
        )
        ..add(const TextMessageEndEvent(messageId: 'resp-1'))
        ..add(const RunFinishedEvent(threadId: 'thread-1', runId: 'run-1'));
      await Future<void>.delayed(Duration.zero);

      // Verify first run completed with 2 messages
      expect(container.read(activeRunNotifierProvider), isA<CompletedState>());
      expect(container.read(activeRunNotifierProvider).messages, hasLength(2));

      // Reset and create new stream for second run
      await container.read(activeRunNotifierProvider.notifier).reset();
      eventStreamController = StreamController<BaseEvent>();
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);

      // Second run should include messages from first run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Second message',
          );

      // Verify all messages are present (2 from first run + 1 new)
      final state = container.read(activeRunNotifierProvider);
      expect(state.messages, hasLength(3));
      expect((state.messages[0] as TextMessage).text, 'First message');
      expect((state.messages[1] as TextMessage).text, 'First response');
      expect((state.messages[2] as TextMessage).text, 'Second message');
    });

    test('sends accumulated AG-UI state merged with initial state', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
        ],
      );

      addTearDown(container.dispose);

      // Pre-populate cache with AG-UI state from previous runs
      final cachedAguiState = <String, dynamic>{
        'ask_history': {
          'questions': [
            {
              'question': 'Previous question',
              'response': 'Previous answer',
              'citations': <Map<String, dynamic>>[],
            },
          ],
        },
        'haiku.rag.chat': {
          'qa_history': [
            {'question': 'Q1', 'answer': 'A1'},
          ],
        },
      };

      container.read(threadHistoryCacheProvider.notifier).updateHistory(
            'thread-1',
            ThreadHistory(messages: const [], aguiState: cachedAguiState),
          );

      // Start a run with initial state (filter_documents)
      final initialState = <String, dynamic>{
        'filter_documents': {
          'document_ids': ['doc-1', 'doc-2'],
        },
      };

      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'New question',
            initialState: initialState,
          );

      // Capture the input sent to the backend
      final captured = verify(
        () => mockAgUiClient.runAgent(
          any(),
          captureAny(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).captured.single as SimpleRunAgentInput;

      // Verify state contains BOTH cached AG-UI state AND initial state
      final sentState = captured.state as Map<String, dynamic>;

      // Cached state should be preserved
      expect(sentState['ask_history'], isNotNull);
      expect(
        (sentState['ask_history'] as Map)['questions'],
        hasLength(1),
      );
      expect(sentState['haiku.rag.chat'], isNotNull);

      // Initial state (filter_documents) should be included
      expect(sentState['filter_documents'], isNotNull);
      expect(
        (sentState['filter_documents'] as Map)['document_ids'],
        ['doc-1', 'doc-2'],
      );
    });
  });
}
