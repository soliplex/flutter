import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:soliplex_client/src/domain/thread_history.dart';
import 'package:test/test.dart';

void main() {
  group('ThreadHistory', () {
    test('constructs with messages and aguiState', () {
      final messages = [
        TextMessage.create(
          id: 'm1',
          user: ChatUser.user,
          text: 'Hello',
        ),
      ];
      final aguiState = <String, dynamic>{
        'haiku.rag.chat': <String, dynamic>{'citations': <dynamic>[]},
      };

      final history = ThreadHistory(
        messages: messages,
        aguiState: aguiState,
      );

      expect(history.messages, equals(messages));
      expect(history.aguiState, equals(aguiState));
    });

    test('aguiState defaults to empty map', () {
      final history = ThreadHistory(messages: const []);

      expect(history.aguiState, isEmpty);
    });

    test('is immutable - messages list cannot be modified externally', () {
      final messages = <ChatMessage>[
        TextMessage.create(id: 'm1', user: ChatUser.user, text: 'Hello'),
      ];
      final history = ThreadHistory(messages: messages);

      // Modifying the original list should not affect the history
      messages.add(
        TextMessage.create(id: 'm2', user: ChatUser.user, text: 'World'),
      );

      expect(history.messages, hasLength(1));
    });

    test('is immutable - aguiState cannot be modified externally', () {
      final aguiState = <String, dynamic>{'key': 'value'};
      final history = ThreadHistory(messages: const [], aguiState: aguiState);

      // Modifying the original map should not affect the history
      aguiState['newKey'] = 'newValue';

      expect(history.aguiState.containsKey('newKey'), isFalse);
    });
  });
}
