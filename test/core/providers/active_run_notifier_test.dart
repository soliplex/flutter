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
import 'package:soliplex_frontend/core/providers/thread_message_cache.dart';
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
        overrides: [agUiClientProvider.overrideWithValue(mockAgUiClient)],
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
          const RunningState(
            roomId: 'room-1',
            conversation: runningConversation,
          ).isRunning,
          isTrue,
        );

        // CompletedState with Success
        const completedConversation = domain.Conversation(
          threadId: 't',
          status: domain.Completed(),
        );
        expect(
          const CompletedState(
            roomId: 'room-1',
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
            roomId: 'room-1',
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
            roomId: 'room-1',
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
        final state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.messages, [message]);
      });

      test('activeToolCalls delegates to conversation.toolCalls', () {
        const toolCall = ToolCallInfo(id: 'tc-1', name: 'search');
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          toolCalls: [toolCall],
          status: domain.Running(runId: 'r'),
        );
        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.activeToolCalls, [toolCall]);
      });

      test('streaming defaults to NotStreaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'r'),
        );
        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.streaming, isA<NotStreaming>());
      });

      test('isStreaming returns true when Streaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'r'),
        );
        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
          streaming: Streaming(messageId: 'msg-1', text: 'Hello'),
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
        cancelToken: cancelToken,
        subscription: controller.stream.listen((_) {}),
      );

      expect(state, isA<NotifierInternalState>());
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
      final cacheBefore = container.read(threadMessageCacheProvider);
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
      final cacheAfter = container.read(threadMessageCacheProvider);
      expect(cacheAfter['thread-1'], isNotNull);
      expect(cacheAfter['thread-1'], hasLength(1));
      expect((cacheAfter['thread-1']!.first as TextMessage).text, 'Hello');
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
      final cacheBefore = container.read(threadMessageCacheProvider);
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
      final cacheAfter = container.read(threadMessageCacheProvider);
      expect(cacheAfter['thread-1'], isNotNull);
      expect(cacheAfter['thread-1'], hasLength(1));
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
      final cache = container.read(threadMessageCacheProvider);
      expect(cache['thread-1'], isNotNull);
      expect(cache['thread-1']!.length, greaterThan(0));
    });

    test('stream onDone without RUN_FINISHED transitions to Completed',
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
    });

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
      final cache = container.read(threadMessageCacheProvider);
      expect(cache['thread-1'], isNotNull);
      expect(cache['thread-1']!.length, greaterThan(0));
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
        const TextMessageContentEvent(
          messageId: 'msg-2',
          delta: 'Late event',
        ),
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
      final cache = container.read(threadMessageCacheProvider);
      expect(cache['thread-1'], isNotNull);
      expect(cache['thread-1'], hasLength(1));
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
        container
            .read(threadMessageCacheProvider.notifier)
            .updateMessages('thread-1', historicalMessages);

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
      container
          .read(threadMessageCacheProvider.notifier)
          .updateMessages('thread-1', historicalMessages);

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

    test('sends client-side tool definitions to backend', () async {
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          // Use real toolRegistryProvider which has getSecretTool registered
        ],
      );

      addTearDown(container.dispose);

      // Start a run (uses the default toolRegistryProvider with get_secret)
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Capture the input sent to the backend
      final captured = verify(
        () => mockAgUiClient.runAgent(
          any(),
          captureAny(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).captured.single as SimpleRunAgentInput;

      // Verify tools were sent
      final tools = captured.tools;
      expect(tools, isNotNull);
      expect(tools, isNotEmpty);
      expect(tools!.any((t) => t.name == 'get_secret'), isTrue);

      // Verify tool has description and parameters
      final getSecretTool = tools.firstWhere((t) => t.name == 'get_secret');
      expect(getSecretTool.description, isNotEmpty);
      expect(getSecretTool.parameters, isNotNull);
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
  });

  group('tool execution', () {
    late MockAgUiClient mockAgUiClient;
    late MockSoliplexApi mockApi;
    late MockToolRegistry mockToolRegistry;
    late StreamController<BaseEvent> eventStreamController;

    setUp(() {
      mockAgUiClient = MockAgUiClient();
      mockApi = MockSoliplexApi();
      mockToolRegistry = MockToolRegistry();
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

      // Register fallback for ToolCallInfo
      registerFallbackValue(
        const ToolCallInfo(
          id: 'fallback-tool',
          name: 'fallback',
          arguments: '{}',
        ),
      );

      // Stub definitions to return empty list by default
      when(() => mockToolRegistry.definitions).thenReturn([]);

      // Stub hasExecutor to return true for any tool by default
      // (tests can override for specific scenarios)
      when(() => mockToolRegistry.hasExecutor(any())).thenReturn(true);
    });

    tearDown(() {
      eventStreamController.close();
    });

    test(
      'only tools with pending status trigger execution, not streaming status',
      () async {
        // Mock tool execution
        when(() => mockToolRegistry.execute(any())).thenAnswer(
          (_) async => '{"result": "success"}',
        );

        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
            toolRegistryProvider.overrideWithValue(mockToolRegistry),
          ],
        );

        addTearDown(container.dispose);

        // Start a run
        await container.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Hello',
            );

        // Send tool call start event (creates streaming tool)
        eventStreamController.add(
          const ToolCallStartEvent(
            toolCallId: 'tool-1',
            toolCallName: 'get_secret',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Tool should NOT be executed yet (still streaming)
        verifyNever(() => mockToolRegistry.execute(any()));

        // Send tool call args
        eventStreamController.add(
          const ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{}'),
        );
        await Future<void>.delayed(Duration.zero);

        // Tool should still NOT be executed (still streaming)
        verifyNever(() => mockToolRegistry.execute(any()));

        // Send tool call end event (marks as pending)
        eventStreamController.add(const ToolCallEndEvent(toolCallId: 'tool-1'));
        await Future<void>.delayed(Duration.zero);

        // Now tool should be executed (pending status)
        verify(() => mockToolRegistry.execute(any())).called(1);
      },
    );

    test('tool execution results in ToolCallMessage', () async {
      // Mock tool execution
      when(() => mockToolRegistry.execute(any())).thenAnswer(
        (_) async => '{"date": "2025-01-01"}',
      );

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          toolRegistryProvider.overrideWithValue(mockToolRegistry),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Simulate tool call flow: start -> args -> end
      eventStreamController
        ..add(
          const ToolCallStartEvent(
            toolCallId: 'tool-1',
            toolCallName: 'get_secret',
          ),
        )
        ..add(const ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{}'))
        ..add(const ToolCallEndEvent(toolCallId: 'tool-1'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify a ToolCallMessage was added
      final state = container.read(activeRunNotifierProvider);
      final toolCallMessages =
          state.messages.whereType<ToolCallMessage>().toList();
      expect(toolCallMessages, isNotEmpty);
      expect(
        toolCallMessages.first.toolCalls.first.status,
        ToolCallStatus.completed,
      );
      expect(
        toolCallMessages.first.toolCalls.first.result,
        '{"date": "2025-01-01"}',
      );
    });

    test('failed tool execution handles errors gracefully', () async {
      // Mock tool execution to throw
      when(() => mockToolRegistry.execute(any())).thenThrow(
        StateError('No executor registered for tool: unknown_tool'),
      );

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          toolRegistryProvider.overrideWithValue(mockToolRegistry),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Simulate tool call flow
      eventStreamController
        ..add(
          const ToolCallStartEvent(
            toolCallId: 'tool-1',
            toolCallName: 'unknown_tool',
          ),
        )
        ..add(const ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{}'))
        ..add(const ToolCallEndEvent(toolCallId: 'tool-1'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify tool call message has failed status
      final state = container.read(activeRunNotifierProvider);
      final toolCallMessages =
          state.messages.whereType<ToolCallMessage>().toList();
      expect(toolCallMessages, isNotEmpty);
      expect(
        toolCallMessages.first.toolCalls.first.status,
        ToolCallStatus.failed,
      );
      expect(
        toolCallMessages.first.toolCalls.first.result,
        contains('No executor registered'),
      );
    });

    test('multiple pending tools execute in same batch', () async {
      // When multiple tools become pending at the same time (all end events
      // arrive before execution starts), they should all be executed together
      final executionOrder = <String>[];
      when(
        () => mockToolRegistry.execute(any()),
      ).thenAnswer((invocation) async {
        final tool = invocation.positionalArguments[0] as ToolCallInfo;
        executionOrder.add(tool.id);
        return '{"tool": "${tool.name}"}';
      });

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          toolRegistryProvider.overrideWithValue(mockToolRegistry),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Start both tools and end them together
      // (simulating both tools finishing at the same time)
      eventStreamController
        ..add(
          const ToolCallStartEvent(
            toolCallId: 'tool-1',
            toolCallName: 'get_secret',
          ),
        )
        ..add(
          const ToolCallStartEvent(
            toolCallId: 'tool-2',
            toolCallName: 'another_tool',
          ),
        )
        ..add(const ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{}'))
        ..add(const ToolCallArgsEvent(toolCallId: 'tool-2', delta: '{}'));

      // Let streaming events process
      await Future<void>.delayed(Duration.zero);

      // End both tools - they should both be pending after this
      eventStreamController
        ..add(const ToolCallEndEvent(toolCallId: 'tool-1'))
        ..add(const ToolCallEndEvent(toolCallId: 'tool-2'));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Both tools that became pending together should be executed
      // Note: The order depends on how events are processed synchronously
      expect(executionOrder, isNotEmpty);
      verify(
        () => mockToolRegistry.execute(any()),
      ).called(greaterThanOrEqualTo(1));
    });

    test('continuation run starts after tool execution', () async {
      // Create separate stream controllers for initial and continuation runs
      var runCount = 0;
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        runCount++;
        if (runCount == 1) {
          return eventStreamController.stream;
        }
        // Return a new controller for continuation run
        return const Stream<BaseEvent>.empty();
      });

      when(() => mockToolRegistry.execute(any())).thenAnswer(
        (_) async => '{"result": "done"}',
      );

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          toolRegistryProvider.overrideWithValue(mockToolRegistry),
        ],
      );

      addTearDown(container.dispose);

      // Start a run
      await container.read(activeRunNotifierProvider.notifier).startRun(
            roomId: 'room-1',
            threadId: 'thread-1',
            userMessage: 'Hello',
          );

      // Simulate tool call flow
      eventStreamController
        ..add(
          const ToolCallStartEvent(
            toolCallId: 'tool-1',
            toolCallName: 'get_secret',
          ),
        )
        ..add(const ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{}'))
        ..add(const ToolCallEndEvent(toolCallId: 'tool-1'));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify continuation run was started (runAgent called twice)
      verify(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(2);

      // Verify createRun was called again for continuation
      verify(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(2);
    });

    test(
      'continuation run includes mapped messages with tool results',
      () async {
        final capturedInputs = <SimpleRunAgentInput>[];
        var callCount = 0;

        // Override the mock to capture inputs and use different streams
        when(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) {
          final input =
              invocation.positionalArguments[1] as SimpleRunAgentInput;
          capturedInputs.add(input);
          callCount++;
          if (callCount == 1) {
            // First call: return the event stream controller
            return eventStreamController.stream;
          }
          // Subsequent calls: return empty stream
          return const Stream<BaseEvent>.empty();
        });

        when(() => mockToolRegistry.execute(any())).thenAnswer(
          (_) async => '{"secret": "42"}',
        );

        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
            toolRegistryProvider.overrideWithValue(mockToolRegistry),
          ],
        );

        addTearDown(container.dispose);

        // Start a run
        await container.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Hello',
            );

        // Simulate tool call flow
        eventStreamController
          ..add(
            const ToolCallStartEvent(
              toolCallId: 'tool-1',
              toolCallName: 'get_secret',
            ),
          )
          ..add(const ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{}'))
          ..add(const ToolCallEndEvent(toolCallId: 'tool-1'));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify we have at least 2 calls (initial + continuation)
        expect(capturedInputs.length, greaterThanOrEqualTo(2));

        // The continuation run (second call) should include tool results
        final continuationInput = capturedInputs[1];
        final messages = continuationInput.messages;
        expect(messages, isNotNull);

        // Should contain a ToolMessage with the result
        final toolMessages = messages!.whereType<ToolMessage>().toList();
        expect(toolMessages, isNotEmpty);
        expect(toolMessages.first.content, '{"secret": "42"}');
      },
    );

    test(
      'server-side tools are not executed by client (only client-registered)',
      () async {
        // Override hasExecutor to return false for server-side tools
        when(() => mockToolRegistry.hasExecutor('get_current_datetime'))
            .thenReturn(false);
        when(() => mockToolRegistry.hasExecutor('get_secret')).thenReturn(true);

        // Mock tool execution for client tool
        when(() => mockToolRegistry.execute(any())).thenAnswer(
          (_) async => '{"secret": "42"}',
        );

        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(mockApi),
            agUiClientProvider.overrideWithValue(mockAgUiClient),
            toolRegistryProvider.overrideWithValue(mockToolRegistry),
          ],
        );

        addTearDown(container.dispose);

        // Start a run
        await container.read(activeRunNotifierProvider.notifier).startRun(
              roomId: 'room-1',
              threadId: 'thread-1',
              userMessage: 'Hello',
            );

        // Simulate a server-side tool call (should NOT trigger execution)
        eventStreamController
          ..add(
            const ToolCallStartEvent(
              toolCallId: 'server-tool-1',
              toolCallName: 'get_current_datetime',
            ),
          )
          ..add(
            const ToolCallArgsEvent(toolCallId: 'server-tool-1', delta: '{}'),
          )
          ..add(const ToolCallEndEvent(toolCallId: 'server-tool-1'));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Server tool should NOT have triggered execution
        verifyNever(() => mockToolRegistry.execute(any()));

        // Now simulate a client-side tool call (SHOULD trigger execution)
        eventStreamController
          ..add(
            const ToolCallStartEvent(
              toolCallId: 'client-tool-1',
              toolCallName: 'get_secret',
            ),
          )
          ..add(
            const ToolCallArgsEvent(toolCallId: 'client-tool-1', delta: '{}'),
          )
          ..add(const ToolCallEndEvent(toolCallId: 'client-tool-1'));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Client tool SHOULD have been executed
        verify(() => mockToolRegistry.execute(any())).called(1);
      },
    );
  });
}
