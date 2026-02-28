import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain show Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/services/run_preparator.dart';

void main() {
  group('prepareRun', () {
    const threadId = 'thread-1';
    const runId = 'run-1';
    const userMessage = 'Hello, world!';

    RunPreparationInput makeInput({
      ThreadHistory? cachedHistory,
      Map<String, dynamic>? initialState,
    }) {
      return RunPreparationInput(
        threadId: threadId,
        runId: runId,
        userMessage: userMessage,
        cachedHistory: cachedHistory,
        initialState: initialState,
      );
    }

    group('user message creation', () {
      test('creates message with timestamp-based ID', () {
        final result = prepareRun(makeInput());

        expect(result.userMessageId, startsWith('user_'));
        // ID should be parseable as a number after the prefix
        final timestamp = result.userMessageId.substring(5);
        expect(int.tryParse(timestamp), isNotNull);
      });

      test('includes user message text in conversation', () {
        final result = prepareRun(makeInput());

        final lastMessage = result.runningState.conversation.messages.last;
        expect(lastMessage, isA<TextMessage>());
        expect((lastMessage as TextMessage).text, userMessage);
      });

      test('sets ChatUser.user on the message', () {
        final result = prepareRun(makeInput());

        final lastMessage = result.runningState.conversation.messages.last;
        expect(lastMessage.user, ChatUser.user);
      });
    });

    group('message combining', () {
      test('contains only user message when no cached history', () {
        final result = prepareRun(makeInput());

        expect(result.runningState.conversation.messages, hasLength(1));
      });

      test('prepends cached messages before user message', () {
        final existing = TextMessage.create(
          id: 'msg-1',
          user: ChatUser.assistant,
          text: 'Previous reply',
        );
        final history = ThreadHistory(messages: [existing]);

        final result = prepareRun(makeInput(cachedHistory: history));

        final messages = result.runningState.conversation.messages;
        expect(messages, hasLength(2));
        expect(messages.first.id, 'msg-1');
        expect(messages.last.id, startsWith('user_'));
      });
    });

    group('conversation construction', () {
      test('sets threadId on conversation', () {
        final result = prepareRun(makeInput());

        expect(result.runningState.conversation.threadId, threadId);
      });

      test('sets Running status with runId', () {
        final result = prepareRun(makeInput());

        final status = result.runningState.conversation.status;
        expect(status, isA<domain.Running>());
        expect((status as domain.Running).runId, runId);
      });

      test('preserves cached aguiState on conversation', () {
        final history = ThreadHistory(
          messages: const [],
          aguiState: const {'key': 'value'},
        );

        final result = prepareRun(makeInput(cachedHistory: history));

        expect(
          result.runningState.conversation.aguiState,
          {'key': 'value'},
        );
      });
    });

    group('AG-UI state deep merge', () {
      test('uses cached state when no initialState provided', () {
        final history = ThreadHistory(
          messages: const [],
          aguiState: const {'cached': 'data'},
        );

        final result = prepareRun(makeInput(cachedHistory: history));

        expect(result.agentInput.state, {'cached': 'data'});
      });

      test('adds initialState keys to cached state', () {
        final history = ThreadHistory(
          messages: const [],
          aguiState: const {'cached': 'data'},
        );

        final result = prepareRun(
          makeInput(
            cachedHistory: history,
            initialState: {'new_key': 'new_value'},
          ),
        );

        expect(result.agentInput.state, {
          'cached': 'data',
          'new_key': 'new_value',
        });
      });

      test('deep merges nested maps', () {
        final history = ThreadHistory(
          messages: const [],
          aguiState: const {
            'config': {'a': 1, 'b': 2},
          },
        );

        final result = prepareRun(
          makeInput(
            cachedHistory: history,
            initialState: {
              'config': {'b': 99, 'c': 3},
            },
          ),
        );

        expect(result.agentInput.state, {
          'config': {'a': 1, 'b': 99, 'c': 3},
        });
      });

      test('replaces non-map values', () {
        final history = ThreadHistory(
          messages: const [],
          aguiState: const {'flag': true},
        );

        final result = prepareRun(
          makeInput(
            cachedHistory: history,
            initialState: {'flag': false},
          ),
        );

        expect(result.agentInput.state, {'flag': false});
      });

      test('returns empty state when no cache and no initialState', () {
        final result = prepareRun(makeInput());

        expect(result.agentInput.state, isEmpty);
      });
    });

    group('agent input', () {
      test('sets threadId and runId', () {
        final result = prepareRun(makeInput());

        expect(result.agentInput.threadId, threadId);
        expect(result.agentInput.runId, runId);
      });

      test('converts messages to AG-UI format', () {
        final result = prepareRun(makeInput());

        // At least one message (the user message)
        expect(result.agentInput.messages, isNotNull);
        expect(result.agentInput.messages, isNotEmpty);
      });
    });

    group('output structure', () {
      test('returns RunningState', () {
        final result = prepareRun(makeInput());

        expect(result.runningState, isA<RunningState>());
      });

      test('previousAguiState captures cached state', () {
        final history = ThreadHistory(
          messages: const [],
          aguiState: const {'before': 'run'},
        );

        final result = prepareRun(makeInput(cachedHistory: history));

        expect(result.previousAguiState, {'before': 'run'});
      });

      test('previousAguiState is empty when no cache', () {
        final result = prepareRun(makeInput());

        expect(result.previousAguiState, isEmpty);
      });
    });
  });
}
