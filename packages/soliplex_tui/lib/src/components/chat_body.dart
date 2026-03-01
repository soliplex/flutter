import 'package:nocterm/nocterm.dart';
import 'package:nocterm_bloc/nocterm_bloc.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_tui/src/components/message_item.dart';
import 'package:soliplex_tui/src/state/tui_chat_cubit.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';

/// Scrollable chat message body with auto-scroll on new content.
class ChatBody extends StatelessComponent {
  const ChatBody({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  Component build(BuildContext context) {
    return BlocBuilder<TuiChatCubit, TuiChatState>(
      builder: (context, state) {
        final messages = state.messages;
        final streaming = state is TuiStreamingState ? state.streaming : null;
        final hasStreamingItem =
            streaming is TextStreaming && streaming.text.isNotEmpty ||
                streaming is AwaitingText && streaming.hasThinkingContent;

        final itemCount = messages.length + (hasStreamingItem ? 1 : 0);

        // Auto-scroll to bottom when streaming.
        if (state is TuiStreamingState && scrollController.atEnd) {
          scrollController.scrollToEnd();
        }

        return SelectionArea(
          child: Scrollbar(
            controller: scrollController,
            child: ListView.builder(
              controller: scrollController,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index < messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: MessageItem(message: messages[index]),
                  );
                }
                // Last item: in-flight streaming text.
                if (streaming != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: StreamingMessageItem(streaming: streaming),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );
  }
}
