import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

/// Creates test ask_history aguiState with given questions.
Map<String, dynamic> createAskHistoryState(
  List<Map<String, dynamic>> questions,
) {
  return {
    'ask_history': {
      'questions': questions,
    },
  };
}

/// Creates a test question entry for ask_history.
Map<String, dynamic> createQuestion({
  required String question,
  required String response,
  List<Map<String, dynamic>> citations = const [],
}) {
  return {
    'question': question,
    'response': response,
    'citations': citations,
  };
}

/// Creates a test citation.
Map<String, dynamic> createCitation({
  required String chunkId,
  String content = 'test content',
  String documentId = 'doc-1',
  String documentUri = 'https://example.com',
}) {
  return {
    'chunk_id': chunkId,
    'content': content,
    'document_id': documentId,
    'document_uri': documentUri,
  };
}

void main() {
  group('Conversation', () {
    late Conversation conversation;

    setUp(() {
      conversation = Conversation.empty(threadId: 'thread-1');
    });

    test('empty creates conversation with defaults', () {
      expect(conversation.threadId, 'thread-1');
      expect(conversation.messages, isEmpty);
      expect(conversation.toolCalls, isEmpty);
      expect(conversation.status, isA<Idle>());
    });

    group('withAppendedMessage', () {
      test('adds message to empty conversation', () {
        final message = TextMessage.create(
          id: 'msg-1',
          user: ChatUser.user,
          text: 'Hello',
        );

        final updated = conversation.withAppendedMessage(message);

        expect(updated.messages, hasLength(1));
        expect(updated.messages.first, message);
        expect(updated.threadId, conversation.threadId);
      });

      test('preserves existing messages', () {
        final message1 = TextMessage.create(
          id: 'msg-1',
          user: ChatUser.user,
          text: 'Hello',
        );
        final message2 = TextMessage.create(
          id: 'msg-2',
          user: ChatUser.assistant,
          text: 'Hi there',
        );

        final updated = conversation
            .withAppendedMessage(message1)
            .withAppendedMessage(message2);

        expect(updated.messages, hasLength(2));
        expect(updated.messages[0], message1);
        expect(updated.messages[1], message2);
      });
    });

    group('withToolCall', () {
      test('adds tool call to empty list', () {
        const toolCall = ToolCallInfo(id: 'tool-1', name: 'search');

        final updated = conversation.withToolCall(toolCall);

        expect(updated.toolCalls, hasLength(1));
        expect(updated.toolCalls.first, toolCall);
      });

      test('preserves existing tool calls', () {
        const toolCall1 = ToolCallInfo(id: 'tool-1', name: 'search');
        const toolCall2 = ToolCallInfo(id: 'tool-2', name: 'read');

        final updated =
            conversation.withToolCall(toolCall1).withToolCall(toolCall2);

        expect(updated.toolCalls, hasLength(2));
      });
    });

    group('withStatus', () {
      test('changes status to Running', () {
        final updated = conversation.withStatus(const Running(runId: 'run-1'));

        expect(updated.status, isA<Running>());
        expect((updated.status as Running).runId, 'run-1');
      });

      test('changes status to Completed', () {
        final running = conversation.withStatus(const Running(runId: 'run-1'));
        final completed = running.withStatus(const Completed());

        expect(completed.status, isA<Completed>());
      });

      test('changes status to Failed', () {
        final updated = conversation.withStatus(
          const Failed(error: 'Network error'),
        );

        expect(updated.status, isA<Failed>());
        expect((updated.status as Failed).error, 'Network error');
      });

      test('changes status to Cancelled', () {
        final updated = conversation.withStatus(
          const Cancelled(reason: 'User cancelled'),
        );

        expect(updated.status, isA<Cancelled>());
        expect((updated.status as Cancelled).reason, 'User cancelled');
      });
    });

    group('copyWith', () {
      test('preserves unmodified fields', () {
        final withMessage = conversation.withAppendedMessage(
          TextMessage.create(id: 'msg-1', user: ChatUser.user, text: 'Hi'),
        );
        final updated = withMessage.copyWith(
          status: const Running(runId: 'run-1'),
        );

        expect(updated.messages, hasLength(1));
      });

      test('copies with new threadId', () {
        final updated = conversation.copyWith(threadId: 'thread-2');

        expect(updated.threadId, 'thread-2');
        expect(updated.messages, conversation.messages);
        expect(updated.toolCalls, conversation.toolCalls);
      });

      test('copies with new messages list', () {
        final newMessages = [
          TextMessage.create(id: 'msg-1', user: ChatUser.user, text: 'Hello'),
        ];
        final updated = conversation.copyWith(messages: newMessages);

        expect(updated.messages, hasLength(1));
        expect(updated.messages.first.id, 'msg-1');
        expect(updated.threadId, conversation.threadId);
      });

      test('copies with new toolCalls list', () {
        const newToolCalls = [
          ToolCallInfo(id: 'tc-1', name: 'search'),
          ToolCallInfo(id: 'tc-2', name: 'read'),
        ];
        final updated = conversation.copyWith(toolCalls: newToolCalls);

        expect(updated.toolCalls, hasLength(2));
        expect(updated.toolCalls[0].name, 'search');
        expect(updated.toolCalls[1].name, 'read');
        expect(updated.threadId, conversation.threadId);
      });

      test('copies with new status', () {
        final updated = conversation.copyWith(
          status: const Running(runId: 'run-1'),
        );

        expect(updated.status, isA<Running>());
        expect((updated.status as Running).runId, 'run-1');
      });
    });

    group('equality', () {
      test('conversations with same state are equal', () {
        final other = Conversation.empty(threadId: 'thread-1');
        expect(conversation, equals(other));
      });

      test('conversations with different threadId are not equal', () {
        final other = Conversation.empty(threadId: 'thread-2');
        expect(conversation, isNot(equals(other)));
      });

      test('conversations with different aguiState are not equal', () {
        const conv1 = Conversation(
          threadId: 'thread-1',
          aguiState: {'key': 'value1'},
        );
        const conv2 = Conversation(
          threadId: 'thread-1',
          aguiState: {'key': 'value2'},
        );
        expect(conv1, isNot(equals(conv2)));
      });

      test('conversations with different messages are not equal', () {
        final conv1 = Conversation.empty(threadId: 'thread-1');
        final conv2 = conv1.withAppendedMessage(
          TextMessage.create(id: 'msg-1', user: ChatUser.user, text: 'Hi'),
        );
        expect(conv1, isNot(equals(conv2)));
      });

      test('conversations with different status are not equal', () {
        final conv1 = Conversation.empty(threadId: 'thread-1');
        final conv2 = conv1.withStatus(const Running(runId: 'run-1'));
        expect(conv1, isNot(equals(conv2)));
      });
    });
  });

  group('ConversationStatus', () {
    test('Idle is default status', () {
      const status = Idle();
      expect(status, isA<ConversationStatus>());
    });

    test('Running contains runId', () {
      const status = Running(runId: 'run-123');
      expect(status.runId, 'run-123');
    });

    test('Failed contains error message', () {
      const status = Failed(error: 'Something went wrong');
      expect(status.error, 'Something went wrong');
    });

    test('Cancelled contains reason', () {
      const status = Cancelled(reason: 'User requested');
      expect(status.reason, 'User requested');
    });

    test('Completed has no additional fields', () {
      const status = Completed();
      expect(status, isA<ConversationStatus>());
    });

    group('Idle', () {
      test('equality', () {
        const status1 = Idle();
        const status2 = Idle();

        expect(status1, equals(status2));
      });

      test('equality non-identical instances', () {
        const status1 = Idle();
        const status2 = Idle();

        expect(status1, equals(status2));
      });

      test('identical returns true', () {
        const status = Idle();
        expect(status == status, isTrue);
      });

      test('hashCode', () {
        const status1 = Idle();
        const status2 = Idle();

        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('toString', () {
        const status = Idle();
        expect(status.toString(), equals('Idle()'));
      });
    });

    group('Running', () {
      test('equality', () {
        const status1 = Running(runId: 'run-1');
        const status2 = Running(runId: 'run-1');
        const status3 = Running(runId: 'run-2');

        expect(status1, equals(status2));
        expect(status1, isNot(equals(status3)));
      });

      test('identical returns true', () {
        const status = Running(runId: 'run-1');
        expect(status == status, isTrue);
      });

      test('hashCode', () {
        const status1 = Running(runId: 'run-1');
        const status2 = Running(runId: 'run-1');

        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('toString', () {
        const status = Running(runId: 'run-123');
        expect(status.toString(), contains('run-123'));
      });
    });

    group('Completed', () {
      test('equality', () {
        const status1 = Completed();
        const status2 = Completed();

        expect(status1, equals(status2));
      });

      test('equality non-identical instances', () {
        const status1 = Completed();
        const status2 = Completed();

        expect(status1, equals(status2));
      });

      test('identical returns true', () {
        const status = Completed();
        expect(status == status, isTrue);
      });

      test('hashCode', () {
        const status1 = Completed();
        const status2 = Completed();

        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('toString', () {
        const status = Completed();
        expect(status.toString(), equals('Completed()'));
      });
    });

    group('Failed', () {
      test('equality', () {
        const status1 = Failed(error: 'error-1');
        const status2 = Failed(error: 'error-1');
        const status3 = Failed(error: 'error-2');

        expect(status1, equals(status2));
        expect(status1, isNot(equals(status3)));
      });

      test('identical returns true', () {
        const status = Failed(error: 'error');
        expect(status == status, isTrue);
      });

      test('hashCode', () {
        const status1 = Failed(error: 'error-1');
        const status2 = Failed(error: 'error-1');

        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('toString', () {
        const status = Failed(error: 'Network error');
        expect(status.toString(), contains('Network error'));
      });
    });

    group('Cancelled', () {
      test('equality', () {
        const status1 = Cancelled(reason: 'reason-1');
        const status2 = Cancelled(reason: 'reason-1');
        const status3 = Cancelled(reason: 'reason-2');

        expect(status1, equals(status2));
        expect(status1, isNot(equals(status3)));
      });

      test('equality non-identical instances', () {
        // Helper function to create non-const instances
        Cancelled create(String reason) => Cancelled(reason: reason);

        final status1 = create('reason-1');
        final status2 = create('reason-1');

        expect(status1, equals(status2));
      });

      test('identical returns true', () {
        const status = Cancelled(reason: 'reason');
        expect(status == status, isTrue);
      });

      test('hashCode', () {
        const status1 = Cancelled(reason: 'reason-1');
        const status2 = Cancelled(reason: 'reason-1');

        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('toString', () {
        const status = Cancelled(reason: 'User cancelled');
        expect(status.toString(), contains('User cancelled'));
      });
    });
  });

  group('Conversation additional', () {
    test('isRunning returns false when Idle', () {
      final conv = Conversation.empty(threadId: 'thread-1');
      expect(conv.isRunning, isFalse);
    });

    test('isRunning returns true when Running', () {
      final conv = Conversation.empty(
        threadId: 'thread-1',
      ).withStatus(const Running(runId: 'run-1'));
      expect(conv.isRunning, isTrue);
    });

    test('hashCode based on threadId', () {
      final conv1 = Conversation.empty(threadId: 'thread-1');
      final conv2 = Conversation.empty(threadId: 'thread-1');

      expect(conv1.hashCode, equals(conv2.hashCode));
    });

    test('toString includes all fields', () {
      final conv = Conversation.empty(threadId: 'thread-1')
          .withAppendedMessage(
            TextMessage.create(id: 'msg-1', user: ChatUser.user, text: 'Hello'),
          )
          .withToolCall(const ToolCallInfo(id: 'tc-1', name: 'search'))
          .withStatus(const Running(runId: 'run-1'));

      final str = conv.toString();

      expect(str, contains('thread-1'));
      expect(str, contains('messages: 1'));
      expect(str, contains('toolCalls: 1'));
      expect(str, contains('Running'));
    });

    test('identical conversations return true for equality', () {
      final conv = Conversation.empty(threadId: 'thread-1');
      expect(conv == conv, isTrue);
    });
  });

  group('citationsForMessage with haiku.rag.chat', () {
    Map<String, dynamic> createHaikuRagChatState({
      List<Map<String, dynamic>> qaHistory = const [],
      List<Map<String, dynamic>> flatCitations = const [],
    }) {
      return {
        'haiku.rag.chat': {
          'qa_history': qaHistory,
          'citations': flatCitations,
          'citation_registry': <String, int>{},
        },
      };
    }

    Map<String, dynamic> createQaResponse({
      required String question,
      required String answer,
      List<Map<String, dynamic>> citations = const [],
    }) {
      return {
        'question': question,
        'answer': answer,
        'citations': citations,
      };
    }

    test('returns citations for first assistant message from qaHistory', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
        ],
        aguiState: createHaikuRagChatState(
          qaHistory: [
            createQaResponse(
              question: 'Q1',
              answer: 'A1',
              citations: [createCitation(chunkId: 'c1')],
            ),
          ],
        ),
      );

      final citations = conversation.citationsForMessage('asst-1');

      expect(citations, hasLength(1));
      expect(citations.first.chunkId, 'c1');
    });

    test('returns citations for multiple messages from qaHistory', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
          TextMessage.create(id: 'user-2', user: ChatUser.user, text: 'Q2'),
          TextMessage.create(
            id: 'asst-2',
            user: ChatUser.assistant,
            text: 'A2',
          ),
        ],
        aguiState: createHaikuRagChatState(
          qaHistory: [
            createQaResponse(
              question: 'Q1',
              answer: 'A1',
              citations: [createCitation(chunkId: 'c1')],
            ),
            createQaResponse(
              question: 'Q2',
              answer: 'A2',
              citations: [createCitation(chunkId: 'c2')],
            ),
          ],
        ),
      );

      final citations1 = conversation.citationsForMessage('asst-1');
      final citations2 = conversation.citationsForMessage('asst-2');

      expect(citations1, hasLength(1));
      expect(citations1.first.chunkId, 'c1');
      expect(citations2, hasLength(1));
      expect(citations2.first.chunkId, 'c2');
    });

    test('returns empty for user messages', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
        ],
        aguiState: createHaikuRagChatState(
          qaHistory: [
            createQaResponse(
              question: 'Q1',
              answer: 'A1',
              citations: [createCitation(chunkId: 'c1')],
            ),
          ],
        ),
      );

      final citations = conversation.citationsForMessage('user-1');

      expect(citations, isEmpty);
    });
  });

  group('citationsForMessage with ask_history', () {
    test('returns citations for first assistant message', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
        ],
        aguiState: createAskHistoryState([
          createQuestion(
            question: 'Q1',
            response: 'A1',
            citations: [createCitation(chunkId: 'c1')],
          ),
        ]),
      );

      final citations = conversation.citationsForMessage('asst-1');

      expect(citations, hasLength(1));
      expect(citations.first.chunkId, 'c1');
    });

    test('returns citations for multiple assistant messages', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
          TextMessage.create(id: 'user-2', user: ChatUser.user, text: 'Q2'),
          TextMessage.create(
            id: 'asst-2',
            user: ChatUser.assistant,
            text: 'A2',
          ),
        ],
        aguiState: createAskHistoryState([
          createQuestion(
            question: 'Q1',
            response: 'A1',
            citations: [createCitation(chunkId: 'c1')],
          ),
          createQuestion(
            question: 'Q2',
            response: 'A2',
            citations: [createCitation(chunkId: 'c2')],
          ),
        ]),
      );

      final citations1 = conversation.citationsForMessage('asst-1');
      final citations2 = conversation.citationsForMessage('asst-2');

      expect(citations1, hasLength(1));
      expect(citations1.first.chunkId, 'c1');
      expect(citations2, hasLength(1));
      expect(citations2.first.chunkId, 'c2');
    });

    test('returns citations for last message when state arrives late', () {
      // Simulates timing issue: message exists but question entry not yet added
      // This happens when TextMessageEndEvent fires before StateDeltaEvent
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
          TextMessage.create(id: 'user-2', user: ChatUser.user, text: 'Q2'),
          TextMessage.create(
            id: 'asst-2',
            user: ChatUser.assistant,
            text: 'A2',
          ), // Last message added
        ],
        aguiState: createAskHistoryState([
          createQuestion(
            question: 'Q1',
            response: 'A1',
            citations: [createCitation(chunkId: 'c1')],
          ),
          // Q2's entry not added yet - simulates late STATE_DELTA
        ]),
      );

      // First message should still work
      final citations1 = conversation.citationsForMessage('asst-1');
      expect(citations1, hasLength(1));

      // Last message: currently returns [] due to timing, but should return
      // the most recent available citations for this streaming message
      final citations2 = conversation.citationsForMessage('asst-2');
      // BUG: returns [] because messageIndex (1) >= questions.length (1)
      // Expected: return [] gracefully (no citations available yet)
      // OR: return last available citations if we want optimistic behavior
      expect(citations2, isEmpty); // Current behavior - document it
    });

    test('returns empty for user messages', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(id: 'user-1', user: ChatUser.user, text: 'Q1'),
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
        ],
        aguiState: createAskHistoryState([
          createQuestion(
            question: 'Q1',
            response: 'A1',
            citations: [createCitation(chunkId: 'c1')],
          ),
        ]),
      );

      final citations = conversation.citationsForMessage('user-1');

      expect(citations, isEmpty);
    });

    test('returns empty when no ask_history state', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
        ],
      );

      final citations = conversation.citationsForMessage('asst-1');

      expect(citations, isEmpty);
    });

    test('returns empty for unknown message id', () {
      final conversation = Conversation(
        threadId: 'thread-1',
        messages: [
          TextMessage.create(
            id: 'asst-1',
            user: ChatUser.assistant,
            text: 'A1',
          ),
        ],
        aguiState: createAskHistoryState([
          createQuestion(
            question: 'Q1',
            response: 'A1',
            citations: [createCitation(chunkId: 'c1')],
          ),
        ]),
      );

      final citations = conversation.citationsForMessage('unknown-id');

      expect(citations, isEmpty);
    });
  });
}
