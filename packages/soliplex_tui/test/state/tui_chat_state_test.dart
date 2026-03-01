import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';
import 'package:test/test.dart';

void main() {
  group('TuiChatState', () {
    test('TuiIdleState has empty messages by default', () {
      const state = TuiIdleState();
      expect(state.messages, isEmpty);
    });

    test('TuiIdleState preserves provided messages', () {
      final messages = [
        TextMessage.create(
          id: 'm1',
          user: ChatUser.user,
          text: 'hello',
        ),
      ];
      final state = TuiIdleState(messages: messages);
      expect(state.messages, hasLength(1));
      expect((state.messages.first as TextMessage).text, 'hello');
    });

    test('TuiStreamingState holds conversation and streaming', () {
      final conversation = Conversation.empty(threadId: 't1');
      const streaming = AwaitingText();

      final state = TuiStreamingState(
        messages: const [],
        conversation: conversation,
        streaming: streaming,
      );

      expect(state.conversation.threadId, 't1');
      expect(state.streaming, isA<AwaitingText>());
      expect(state.reasoningText, isNull);
      expect(state.showReasoning, isTrue);
    });

    test('TuiStreamingState holds reasoning text', () {
      final conversation = Conversation.empty(threadId: 't1');
      const streaming = AwaitingText(bufferedThinkingText: 'thinking...');

      final state = TuiStreamingState(
        messages: const [],
        conversation: conversation,
        streaming: streaming,
        reasoningText: 'thinking...',
      );

      expect(state.reasoningText, 'thinking...');
    });

    test('TuiExecutingToolsState holds pending tools', () {
      final conversation = Conversation.empty(threadId: 't1');
      final tools = [
        const ToolCallInfo(id: 'tc1', name: 'get_time'),
      ];

      final state = TuiExecutingToolsState(
        messages: const [],
        conversation: conversation,
        pendingTools: tools,
      );

      expect(state.pendingTools, hasLength(1));
      expect(state.pendingTools.first.name, 'get_time');
    });

    test('TuiErrorState holds error message', () {
      const state = TuiErrorState(
        messages: [],
        errorMessage: 'Something went wrong',
      );

      expect(state.errorMessage, 'Something went wrong');
    });

    test('sealed class exhaustive pattern matching', () {
      const TuiChatState state = TuiIdleState();
      final result = switch (state) {
        TuiIdleState() => 'idle',
        TuiStreamingState() => 'streaming',
        TuiExecutingToolsState() => 'executing',
        TuiErrorState() => 'error',
      };
      expect(result, 'idle');
    });
  });
}
