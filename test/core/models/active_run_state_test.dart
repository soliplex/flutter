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
        expect(state.streaming, isA<AwaitingText>());
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
      test('creates with conversation and streaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(conversation: conversation);

        expect(state.conversation, equals(conversation));
        expect(state.streaming, isA<AwaitingText>());
      });

      test('threadId delegates to conversation', () {
        const conversation = domain.Conversation(
          threadId: 'thread-123',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(conversation: conversation);

        expect(state.threadId, 'thread-123');
      });

      test('runId extracts from conversation.status', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-456'),
        );

        const state = RunningState(conversation: conversation);

        expect(state.runId, 'run-456');
      });

      test('isRunning is true', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(conversation: conversation);

        expect(state.isRunning, isTrue);
      });

      test('isStreaming returns false when AwaitingText', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(conversation: conversation);

        expect(state.isStreaming, isFalse);
      });

      test('isStreaming returns true when TextStreaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
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

        final state = RunningState(conversation: conversation);

        expect(state.messages, [message]);
      });

      test('activeToolCalls delegates to conversation', () {
        const toolCall = ToolCallInfo(id: 'tc-1', name: 'search');
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          toolCalls: [toolCall],
          status: domain.Running(runId: 'run-1'),
        );

        const state = RunningState(conversation: conversation);

        expect(state.activeToolCalls, [toolCall]);
      });

      test('copyWith creates new instance with updated fields', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const original = RunningState(conversation: conversation);

        final updated = original.copyWith(
          streaming: const TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: 'Hi',
          ),
        );

        expect(updated.streaming, isA<TextStreaming>());
        expect(original.streaming, isA<AwaitingText>());
        expect(updated.conversation, equals(conversation));
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
        const original = RunningState(conversation: conversation1);

        final updated = original.copyWith(conversation: conversation2);

        expect(updated.conversation.messages.length, 1);
        expect(original.conversation.messages, isEmpty);
      });

      test('equality based on conversation and streaming', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        const state1 = RunningState(conversation: conversation);
        const state2 = RunningState(conversation: conversation);
        const state3 = RunningState(
          conversation: conversation,
          streaming: TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: 'Hi',
          ),
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('CompletedState', () {
      test('creates with conversation and result', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );

        const state = CompletedState(
          conversation: conversation,
          result: Success(),
        );

        expect(state.conversation, equals(conversation));
        expect(state.result, isA<Success>());
        expect(state.streaming, isA<AwaitingText>());
      });

      test('threadId delegates to conversation', () {
        const conversation = domain.Conversation(
          threadId: 'thread-123',
          status: domain.Completed(),
        );

        const state = CompletedState(
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
          conversation: conversation,
          result: CancelledResult(reason: 'User cancelled'),
        );

        expect(state.result, isA<CancelledResult>());
        expect((state.result as CancelledResult).reason, 'User cancelled');
      });

      test('equality based on conversation and result', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );

        const state1 = CompletedState(
          conversation: conversation,
          result: Success(),
        );
        const state2 = CompletedState(
          conversation: conversation,
          result: Success(),
        );
        const state3 = CompletedState(
          conversation: conversation,
          result: FailedResult(errorMessage: 'Error'),
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('ExecutingToolsState', () {
      test('creates with conversation and pending tools', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          toolCalls: [ToolCallInfo(id: 'tc-1', name: 'search')],
          status: domain.Running(runId: 'run-1'),
        );
        const pendingTools = [ToolCallInfo(id: 'tc-1', name: 'search')];

        const state = ExecutingToolsState(
          conversation: conversation,
          pendingTools: pendingTools,
        );

        expect(state.conversation, equals(conversation));
        expect(state.pendingTools, hasLength(1));
        expect(state.pendingTools.first.name, 'search');
      });

      test('streaming returns AwaitingText (SSE stream is dead)', () {
        const state = ExecutingToolsState(
          conversation: domain.Conversation(
            threadId: 'thread-1',
            status: domain.Running(runId: 'run-1'),
          ),
          pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
        );

        expect(state.streaming, isA<AwaitingText>());
      });

      test('isRunning returns true', () {
        const state = ExecutingToolsState(
          conversation: domain.Conversation(
            threadId: 'thread-1',
            status: domain.Running(runId: 'run-1'),
          ),
          pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
        );

        expect(state.isRunning, isTrue);
      });

      test('threadId delegates to conversation', () {
        const state = ExecutingToolsState(
          conversation: domain.Conversation(
            threadId: 'thread-99',
            status: domain.Running(runId: 'run-1'),
          ),
          pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
        );

        expect(state.threadId, 'thread-99');
      });

      test('equality based on conversation and pendingTools', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const tools = [ToolCallInfo(id: 'tc-1', name: 'search')];

        const state1 = ExecutingToolsState(
          conversation: conversation,
          pendingTools: tools,
        );
        const state2 = ExecutingToolsState(
          conversation: conversation,
          pendingTools: tools,
        );
        const state3 = ExecutingToolsState(
          conversation: conversation,
          pendingTools: [ToolCallInfo(id: 'tc-2', name: 'fetch')],
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });

      test('hashCode is consistent with equality', () {
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const tools = [ToolCallInfo(id: 'tc-1', name: 'search')];

        const state1 = ExecutingToolsState(
          conversation: conversation,
          pendingTools: tools,
        );
        const state2 = ExecutingToolsState(
          conversation: conversation,
          pendingTools: tools,
        );

        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('toString shows threadId and tool names', () {
        const state = ExecutingToolsState(
          conversation: domain.Conversation(
            threadId: 'thread-1',
            status: domain.Running(runId: 'run-1'),
          ),
          pendingTools: [
            ToolCallInfo(id: 'tc-1', name: 'search'),
            ToolCallInfo(id: 'tc-2', name: 'fetch'),
          ],
        );

        final str = state.toString();
        expect(str, contains('threadId: thread-1'));
        expect(str, contains('search'));
        expect(str, contains('fetch'));
      });

      test('pattern matching with destructuring', () {
        const ActiveRunState state = ExecutingToolsState(
          conversation: domain.Conversation(
            threadId: 'thread-1',
            status: domain.Running(runId: 'run-1'),
          ),
          pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
        );

        final toolNames = switch (state) {
          ExecutingToolsState(:final pendingTools) =>
            pendingTools.map((t) => t.name).toList(),
          _ => <String>[],
        };

        expect(toolNames, ['search']);
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
          const RunningState(conversation: conversation),
          const ExecutingToolsState(
            conversation: conversation,
            pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
          ),
          const CompletedState(
            conversation: completedConversation,
            result: Success(),
          ),
        ];

        for (final state in states) {
          final description = switch (state) {
            IdleState() => 'idle',
            RunningState() => 'running',
            ExecutingToolsState() => 'executing_tools',
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
    });

    group('different state types are not equal', () {
      test('IdleState is not equal to RunningState', () {
        const idle = IdleState();
        const running = RunningState(
          conversation: domain.Conversation(
            threadId: 't',
            status: domain.Running(runId: 'r'),
          ),
        );

        expect(idle, isNot(equals(running)));
      });

      test('RunningState is not equal to CompletedState', () {
        const running = RunningState(
          conversation: domain.Conversation(
            threadId: 't',
            status: domain.Running(runId: 'r'),
          ),
        );
        const completed = CompletedState(
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

    test('RunningState.toString shows threadId and message count', () {
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
        conversation: conversation,
        streaming: const TextStreaming(
          messageId: 'msg-1',
          user: ChatUser.assistant,
          text: 'Hi',
        ),
      );

      final str = state.toString();

      expect(str, contains('threadId: thread-123'));
      expect(str, contains('messages: 1'));
      expect(str, contains('streaming:'));
    });

    test('CompletedState.toString shows result and message count', () {
      const conversation = domain.Conversation(
        threadId: 'thread-456',
        status: domain.Completed(),
      );
      const state = CompletedState(
        conversation: conversation,
        result: Success(),
      );

      final str = state.toString();

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
      const state1 = RunningState(conversation: conversation);
      const state2 = RunningState(conversation: conversation);

      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('CompletedState.hashCode is consistent with equality', () {
      const conversation = domain.Conversation(
        threadId: 'thread-1',
        status: domain.Completed(),
      );
      const state1 = CompletedState(
        conversation: conversation,
        result: Success(),
      );
      const state2 = CompletedState(
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
      const state = RunningState(conversation: conversation);

      expect(() => state.runId, throwsStateError);
    });
  });
}
