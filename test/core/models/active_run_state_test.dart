import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Conversation, Failed, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';

void main() {
  group('ActiveRunState', () {
    group('IdleState', () {
      test('is a sentinel state with empty conversation', () {
        const state = IdleState();

        expect(state.conversation.threadId, isEmpty);
        expect(state.conversation.messages, isEmpty);
        expect(state.streaming, isA<NotStreaming>());
      });

      test('messages returns empty list', () {
        const state = IdleState();

        expect(state.messages, isEmpty);
      });

      test('isRunning is false', () {
        const state = IdleState();

        expect(state.isRunning, isFalse);
      });

      test('activeToolCalls returns empty list', () {
        const state = IdleState();

        expect(state.activeToolCalls, isEmpty);
      });

      test('equality - all IdleState instances are equal', () {
        const state1 = IdleState();
        const state2 = IdleState();

        expect(state1, equals(state2));
      });
    });

    group('RunningState', () {
      test('requires roomId', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-123',
          conversation: conversation,
        );

        expect(state.roomId, 'room-123');
      });

      test('creates with roomId, conversation and streaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.roomId, 'room-1');
        expect(state.conversation, equals(conversation));
        expect(state.streaming, isA<NotStreaming>());
      });

      test('threadId delegates to conversation', () {
        const conversation = domain.Conversation(
          threadId: 'thread-123',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.threadId, 'thread-123');
      });

      test('runId extracts from conversation.status', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-456'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.runId, 'run-456');
      });

      test('isRunning is true', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.isRunning, isTrue);
      });

      test('isStreaming returns false when NotStreaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.isStreaming, isFalse);
      });

      test('isStreaming returns true when Streaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
          streaming: Streaming(messageId: 'msg-1', text: 'Hello'),
        );

        expect(state.isStreaming, isTrue);
      });

      test('messages delegates to conversation', () {
        final message = TextMessage.create(
          id: 'msg-1',
          user: ChatUser.user,
          text: 'Hello',
        );
        final conversation = domain.Conversation(
          threadId: 'thread-1',
          messages: [message],
          status: const domain.Running(runId: 'run-1'),
        );

        final state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.messages, [message]);
      });

      test('activeToolCalls delegates to conversation', () {
        const toolCall = ToolCallInfo(id: 'tc-1', name: 'search');
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          toolCalls: [toolCall],
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        expect(state.activeToolCalls, [toolCall]);
      });

      test('copyWith creates new instance with updated fields', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const original = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        final updated = original.copyWith(
          streaming: const Streaming(messageId: 'msg-1', text: 'Hi'),
        );

        expect(updated.streaming, isA<Streaming>());
        expect(original.streaming, isA<NotStreaming>());
        expect(updated.conversation, equals(conversation));
        expect(updated.roomId, 'room-1'); // roomId preserved
      });

      test('copyWith can update roomId', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const original = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );

        final updated = original.copyWith(roomId: 'room-2');

        expect(updated.roomId, 'room-2');
        expect(original.roomId, 'room-1');
      });

      test('copyWith can update conversation', () {
        const conversation1 = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        final conversation2 = domain.Conversation(
          threadId: 'thread-1',
          messages: [
            TextMessage.create(id: 'msg-1', user: ChatUser.user, text: 'Hi'),
          ],
          status: const domain.Running(runId: 'run-1'),
        );
        const original = RunningState(
          roomId: 'room-1',
          conversation: conversation1,
        );

        final updated = original.copyWith(conversation: conversation2);

        expect(updated.conversation.messages.length, 1);
        expect(original.conversation.messages, isEmpty);
      });

      test('equality based on roomId, conversation and streaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state1 = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );
        const state2 = RunningState(
          roomId: 'room-1',
          conversation: conversation,
        );
        const state3 = RunningState(
          roomId: 'room-1',
          conversation: conversation,
          streaming: Streaming(messageId: 'msg-1', text: 'Hi'),
        );
        const state4 = RunningState(
          roomId: 'room-2',
          conversation: conversation,
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state1, isNot(equals(state4))); // different roomId
      });
    });

    group('CompletedState', () {
      test('requires roomId', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );

        const state = CompletedState(
          roomId: 'room-123',
          conversation: conversation,
          result: Success(),
        );

        expect(state.roomId, 'room-123');
      });

      test('creates with roomId, conversation and result', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );

        const state = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: Success(),
        );

        expect(state.roomId, 'room-1');
        expect(state.conversation, equals(conversation));
        expect(state.result, isA<Success>());
        expect(state.streaming, isA<NotStreaming>());
      });

      test('threadId delegates to conversation', () {
        const conversation = domain.Conversation(
          threadId: 'thread-123',
          status: domain.Completed(),
        );

        const state = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: Success(),
        );

        expect(state.threadId, 'thread-123');
      });

      test('isRunning is false', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );

        const state = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: Success(),
        );

        expect(state.isRunning, isFalse);
      });

      test('creates with Failed result', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Failed(error: 'Something went wrong'),
        );

        const state = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: FailedResult(errorMessage: 'Something went wrong'),
        );

        expect(state.result, isA<FailedResult>());
        expect(
          (state.result as FailedResult).errorMessage,
          'Something went wrong',
        );
      });

      test('creates with Cancelled result', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Cancelled(reason: 'User cancelled'),
        );

        const state = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: CancelledResult(reason: 'User cancelled'),
        );

        expect(state.result, isA<CancelledResult>());
        expect((state.result as CancelledResult).reason, 'User cancelled');
      });

      test('equality based on roomId, conversation and result', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );

        const state1 = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: Success(),
        );
        const state2 = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: Success(),
        );
        const state3 = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: FailedResult(errorMessage: 'Error'),
        );
        const state4 = CompletedState(
          roomId: 'room-2',
          conversation: conversation,
          result: Success(),
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state1, isNot(equals(state4))); // different roomId
      });
    });

    group('pattern matching', () {
      test('exhaustive switch on ActiveRunState', () {
        const conversation = domain.Conversation(
          threadId: 't',
          status: domain.Running(runId: 'r'),
        );
        const completedConversation = domain.Conversation(
          threadId: 't',
          status: domain.Completed(),
        );

        final states = <ActiveRunState>[
          const IdleState(),
          const RunningState(roomId: 'room-1', conversation: conversation),
          const CompletedState(
            roomId: 'room-1',
            conversation: completedConversation,
            result: Success(),
          ),
        ];

        for (final state in states) {
          final description = switch (state) {
            IdleState() => 'idle',
            RunningState() => 'running',
            CompletedState() => 'completed',
          };
          expect(description, isNotEmpty);
        }
      });

      test('pattern matching on CompletedState result', () {
        const results = <CompletionResult>[
          Success(),
          FailedResult(errorMessage: 'Error'),
          CancelledResult(reason: 'Cancelled'),
        ];

        for (final result in results) {
          final description = switch (result) {
            Success() => 'success',
            FailedResult(:final errorMessage) => 'failed: $errorMessage',
            CancelledResult(:final reason) => 'cancelled: $reason',
          };
          expect(description, isNotEmpty);
        }
      });

      test('nested pattern matching for error handling', () {
        const conversation = domain.Conversation(
          threadId: 't',
          status: domain.Failed(error: 'Network error'),
        );
        const state = CompletedState(
          roomId: 'room-1',
          conversation: conversation,
          result: FailedResult(errorMessage: 'Network error'),
        );

        final errorMessage = switch (state) {
          CompletedState(result: FailedResult(:final errorMessage)) =>
            errorMessage,
          _ => null,
        };

        expect(errorMessage, 'Network error');
      });

      test('roomId is preserved through state transitions', () {
        const runningConversation = domain.Conversation(
          threadId: 't',
          status: domain.Running(runId: 'r'),
        );
        const completedConversation = domain.Conversation(
          threadId: 't',
          status: domain.Completed(),
        );

        const running = RunningState(
          roomId: 'room-123',
          conversation: runningConversation,
        );

        // Simulate a state transition (e.g., run completed)
        final completed = CompletedState(
          roomId: running.roomId,
          conversation: completedConversation,
          result: const Success(),
        );

        expect(completed.roomId, running.roomId);
        expect(completed.roomId, 'room-123');
      });
    });

    group('different state types are not equal', () {
      test('IdleState is not equal to RunningState', () {
        const idle = IdleState();
        const running = RunningState(
          roomId: 'room-1',
          conversation: domain.Conversation(
            threadId: 't',
            status: domain.Running(runId: 'r'),
          ),
        );

        expect(idle, isNot(equals(running)));
      });

      test('RunningState is not equal to CompletedState', () {
        const running = RunningState(
          roomId: 'room-1',
          conversation: domain.Conversation(
            threadId: 't',
            status: domain.Running(runId: 'r'),
          ),
        );
        const completed = CompletedState(
          roomId: 'room-1',
          conversation: domain.Conversation(
            threadId: 't',
            status: domain.Completed(),
          ),
          result: Success(),
        );

        expect(running, isNot(equals(completed)));
      });
    });
  });

  group('CompletionResult', () {
    test('Success instances are equal', () {
      const success1 = Success();
      const success2 = Success();

      expect(success1, equals(success2));
    });

    test('Failed equality based on errorMessage', () {
      const failed1 = FailedResult(errorMessage: 'Error A');
      const failed2 = FailedResult(errorMessage: 'Error A');
      const failed3 = FailedResult(errorMessage: 'Error B');

      expect(failed1, equals(failed2));
      expect(failed1, isNot(equals(failed3)));
    });

    test('Cancelled equality based on reason', () {
      const cancelled1 = CancelledResult(reason: 'Reason A');
      const cancelled2 = CancelledResult(reason: 'Reason A');
      const cancelled3 = CancelledResult(reason: 'Reason B');

      expect(cancelled1, equals(cancelled2));
      expect(cancelled1, isNot(equals(cancelled3)));
    });

    test('different result types are not equal', () {
      const success = Success();
      const failed = FailedResult(errorMessage: 'Error');
      const cancelled = CancelledResult(reason: 'Reason');

      expect(success, isNot(equals(failed)));
      expect(success, isNot(equals(cancelled)));
      expect(failed, isNot(equals(cancelled)));
    });

    test('Success.toString returns Success()', () {
      const success = Success();

      expect(success.toString(), 'Success()');
    });

    test('FailedResult.toString shows error message', () {
      const failed = FailedResult(errorMessage: 'Network error');

      expect(failed.toString(), 'FailedResult(errorMessage: Network error)');
    });

    test('CancelledResult.toString shows reason', () {
      const cancelled = CancelledResult(reason: 'User cancelled');

      expect(cancelled.toString(), 'CancelledResult(reason: User cancelled)');
    });
  });

  group('toString methods', () {
    test('IdleState.toString returns IdleState()', () {
      const state = IdleState();

      expect(state.toString(), 'IdleState()');
    });

    test('RunningState.toString shows roomId, threadId and message count', () {
      final message = TextMessage.create(
        id: 'msg-1',
        user: ChatUser.user,
        text: 'Hello',
      );
      final conversation = domain.Conversation(
        threadId: 'thread-123',
        messages: [message],
        status: const domain.Running(runId: 'run-1'),
      );
      final state = RunningState(
        roomId: 'room-789',
        conversation: conversation,
        streaming: const Streaming(messageId: 'msg-1', text: 'Hi'),
      );

      final str = state.toString();

      expect(str, contains('roomId: room-789'));
      expect(str, contains('threadId: thread-123'));
      expect(str, contains('messages: 1'));
      expect(str, contains('streaming:'));
    });

    test('CompletedState.toString shows roomId, result and message count', () {
      const conversation = domain.Conversation(
        threadId: 'thread-456',
        status: domain.Completed(),
      );
      const state = CompletedState(
        roomId: 'room-789',
        conversation: conversation,
        result: Success(),
      );

      final str = state.toString();

      expect(str, contains('roomId: room-789'));
      expect(str, contains('threadId: thread-456'));
      expect(str, contains('result: Success()'));
      expect(str, contains('messages: 0'));
    });
  });

  group('hashCode methods', () {
    test('IdleState.hashCode is consistent', () {
      const state1 = IdleState();
      const state2 = IdleState();

      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('RunningState.hashCode is consistent with equality', () {
      const conversation = domain.Conversation(
        threadId: 'thread-1',
        status: domain.Running(runId: 'run-1'),
      );
      const state1 = RunningState(
        roomId: 'room-1',
        conversation: conversation,
      );
      const state2 = RunningState(
        roomId: 'room-1',
        conversation: conversation,
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('CompletedState.hashCode is consistent with equality', () {
      const conversation = domain.Conversation(
        threadId: 'thread-1',
        status: domain.Completed(),
      );
      const state1 = CompletedState(
        roomId: 'room-1',
        conversation: conversation,
        result: Success(),
      );
      const state2 = CompletedState(
        roomId: 'room-1',
        conversation: conversation,
        result: Success(),
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });
  });

  group('RunningState.runId edge case', () {
    test('throws StateError when conversation status is not Running', () {
      // This is an invalid state that shouldn't occur in practice,
      // but the code has a safety check for it.
      const conversation = domain.Conversation(
        threadId: 'thread-1',
        status: domain.Completed(),
      );
      const state = RunningState(
        roomId: 'room-1',
        conversation: conversation,
      );

      expect(() => state.runId, throwsStateError);
    });
  });
}
