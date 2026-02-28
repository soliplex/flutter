import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Failed, Idle, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/services/run_completion_handler.dart';

void main() {
  late RunCompletionHandler handler;

  setUp(() {
    handler = RunCompletionHandler();
  });

  RunHandle createHandle({
    String roomId = 'room-1',
    String threadId = 'thread-1',
    String runId = 'run-1',
    String userMessageId = 'user_1',
    Map<String, dynamic> previousAguiState = const {},
    ActiveRunState? initialState,
  }) {
    final controller = StreamController<BaseEvent>();
    final cancelToken = CancelToken();
    final subscription = controller.stream.listen((_) {});

    addTearDown(subscription.cancel);
    addTearDown(controller.close);

    return RunHandle(
      key: (roomId: roomId, threadId: threadId),
      runId: runId,
      cancelToken: cancelToken,
      subscription: subscription,
      userMessageId: userMessageId,
      previousAguiState: previousAguiState,
      initialState: initialState,
    );
  }

  Conversation makeConversation({
    ConversationStatus status = const domain.Running(runId: 'run-1'),
    List<ChatMessage> messages = const [],
    Map<String, dynamic> aguiState = const {},
    List<ToolCallInfo> toolCalls = const [],
    Map<String, MessageState> messageStates = const {},
  }) {
    return Conversation(
      threadId: 'thread-1',
      messages: messages,
      status: status,
      aguiState: aguiState,
      toolCalls: toolCalls,
      messageStates: messageStates,
    );
  }

  EventProcessingResult makeResult({
    Conversation? conversation,
    StreamingState streaming = const AwaitingText(),
  }) {
    return EventProcessingResult(
      conversation: conversation ?? makeConversation(),
      streaming: streaming,
    );
  }

  group('correlateMessages', () {
    test('returns conversation unchanged when Running', () {
      final handle = createHandle();
      final conversation = makeConversation();
      final result = makeResult(conversation: conversation);

      final correlated = handler.correlateMessages(
        handle: handle,
        result: result,
      );

      // Should be the exact same object
      expect(identical(correlated, conversation), isTrue);
    });

    test('adds MessageState on Completed status', () {
      final handle = createHandle(userMessageId: 'user_42');
      final conversation = makeConversation(
        status: const domain.Completed(),
      );
      final result = makeResult(conversation: conversation);

      final correlated = handler.correlateMessages(
        handle: handle,
        result: result,
      );

      expect(correlated.messageStates, contains('user_42'));
      final ms = correlated.messageStates['user_42']!;
      expect(ms.userMessageId, 'user_42');
      expect(ms.runId, 'run-1');
    });

    test('adds MessageState on Failed status', () {
      final handle = createHandle(userMessageId: 'user_99');
      final conversation = makeConversation(
        status: const domain.Failed(error: 'oops'),
      );
      final result = makeResult(conversation: conversation);

      final correlated = handler.correlateMessages(
        handle: handle,
        result: result,
      );

      expect(correlated.messageStates, contains('user_99'));
    });

    test('adds MessageState on Cancelled status', () {
      final handle = createHandle(userMessageId: 'user_77');
      final conversation = makeConversation(
        status: const domain.Cancelled(reason: 'user cancelled'),
      );
      final result = makeResult(conversation: conversation);

      final correlated = handler.correlateMessages(
        handle: handle,
        result: result,
      );

      expect(correlated.messageStates, contains('user_77'));
    });
  });

  group('buildUpdatedHistory', () {
    test('merges existing and new messageStates', () {
      final existingMs = MessageState(
        userMessageId: 'user_1',
        sourceReferences: const [],
        runId: 'old-run',
      );
      final existingHistory = ThreadHistory(
        messages: const [],
        messageStates: {'user_1': existingMs},
      );

      final newMs = MessageState(
        userMessageId: 'user_2',
        sourceReferences: const [],
        runId: 'new-run',
      );
      final completed = CompletedState(
        conversation: makeConversation(
          status: const domain.Completed(),
          messageStates: {'user_2': newMs},
        ),
        result: const Success(),
      );

      final history = handler.buildUpdatedHistory(
        completedState: completed,
        existingHistory: existingHistory,
      );

      expect(history.messageStates, hasLength(2));
      expect(history.messageStates, contains('user_1'));
      expect(history.messageStates, contains('user_2'));
    });

    test('handles null existing history', () {
      final newMs = MessageState(
        userMessageId: 'user_1',
        sourceReferences: const [],
        runId: 'run-1',
      );
      final completed = CompletedState(
        conversation: makeConversation(
          status: const domain.Completed(),
          messageStates: {'user_1': newMs},
        ),
        result: const Success(),
      );

      final history = handler.buildUpdatedHistory(
        completedState: completed,
        existingHistory: null,
      );

      expect(history.messageStates, hasLength(1));
      expect(history.messageStates, contains('user_1'));
    });

    test('preserves messages and aguiState from completed run', () {
      final msg = TextMessage.create(
        id: 'msg-1',
        user: ChatUser.assistant,
        text: 'Hello',
      );
      final completed = CompletedState(
        conversation: makeConversation(
          status: const domain.Completed(),
          messages: [msg],
          aguiState: const {'key': 'value'},
        ),
        result: const Success(),
      );

      final history = handler.buildUpdatedHistory(
        completedState: completed,
        existingHistory: null,
      );

      expect(history.messages, hasLength(1));
      expect(history.messages.first.id, 'msg-1');
      expect(history.aguiState, {'key': 'value'});
    });
  });

  group('mapEventResult', () {
    test('returns CompletedState on Completed status', () {
      final handle = createHandle();
      final conversation = makeConversation(
        status: const domain.Completed(),
      );
      final previousState = RunningState(
        conversation: makeConversation(),
      );

      final newState = handler.mapEventResult(
        handle: handle,
        previousState: previousState,
        result: makeResult(conversation: conversation),
      );

      expect(newState, isA<CompletedState>());
      expect((newState as CompletedState).result, isA<Success>());
    });

    test('keeps RunningState when Completed but tools are pending', () {
      final handle = createHandle();
      final conversation = makeConversation(
        status: const domain.Completed(),
        toolCalls: const [
          ToolCallInfo(
            id: 'tc-1',
            name: 'search',
          ),
        ],
      );
      final previousState = RunningState(
        conversation: makeConversation(),
      );

      final newState = handler.mapEventResult(
        handle: handle,
        previousState: previousState,
        result: makeResult(conversation: conversation),
      );

      expect(newState, isA<RunningState>());
      // Status should be reverted to Running
      expect(newState.conversation.status, isA<domain.Running>());
    });

    test('returns CompletedState with FailedResult on Failed status', () {
      final handle = createHandle();
      final conversation = makeConversation(
        status: const domain.Failed(error: 'something broke'),
      );
      final previousState = RunningState(
        conversation: makeConversation(),
      );

      final newState = handler.mapEventResult(
        handle: handle,
        previousState: previousState,
        result: makeResult(conversation: conversation),
      );

      expect(newState, isA<CompletedState>());
      final completed = newState as CompletedState;
      expect(completed.result, isA<FailedResult>());
      expect(
        (completed.result as FailedResult).errorMessage,
        'something broke',
      );
    });

    test('returns CompletedState with CancelledResult on Cancelled', () {
      final handle = createHandle();
      final conversation = makeConversation(
        status: const domain.Cancelled(reason: 'user cancelled'),
      );
      final previousState = RunningState(
        conversation: makeConversation(),
      );

      final newState = handler.mapEventResult(
        handle: handle,
        previousState: previousState,
        result: makeResult(conversation: conversation),
      );

      expect(newState, isA<CompletedState>());
      final completed = newState as CompletedState;
      expect(completed.result, isA<CancelledResult>());
      expect(
        (completed.result as CancelledResult).reason,
        'user cancelled',
      );
    });

    test('returns RunningState on Running status', () {
      final handle = createHandle();
      final conversation = makeConversation();
      final previousState = RunningState(
        conversation: makeConversation(),
      );

      final newState = handler.mapEventResult(
        handle: handle,
        previousState: previousState,
        result: makeResult(conversation: conversation),
      );

      expect(newState, isA<RunningState>());
    });

    test('throws StateError on Idle status', () {
      final handle = createHandle();
      final conversation = makeConversation(
        status: const domain.Idle(),
      );
      final previousState = RunningState(
        conversation: makeConversation(),
      );

      expect(
        () => handler.mapEventResult(
          handle: handle,
          previousState: previousState,
          result: makeResult(conversation: conversation),
        ),
        throwsStateError,
      );
    });

    test('preserves streaming state in result', () {
      final handle = createHandle();
      final conversation = makeConversation();
      final previousState = RunningState(
        conversation: makeConversation(),
      );
      const streaming = TextStreaming(
        messageId: 'msg-1',
        user: ChatUser.assistant,
        text: 'partial',
      );

      final newState = handler.mapEventResult(
        handle: handle,
        previousState: previousState,
        result: makeResult(
          conversation: conversation,
          streaming: streaming,
        ),
      );

      expect(newState, isA<RunningState>());
      expect((newState as RunningState).streaming, isA<TextStreaming>());
    });
  });
}
