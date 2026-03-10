import 'package:nocterm/nocterm.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'package:soliplex_tui/src/components/message_item.dart';
import 'package:soliplex_tui/src/signal_builder.dart';

/// Scrollable chat message body with auto-scroll on new content.
///
/// Subscribes to [messages] and [streaming] signals independently,
/// so it only rebuilds when conversation content changes.
class ChatBody extends StatelessComponent {
  const ChatBody({
    required this.scrollController,
    required this.messages,
    required this.streaming,
    super.key,
  });

  final ScrollController scrollController;
  final ReadonlySignal<List<ChatMessage>> messages;
  final ReadonlySignal<StreamingState?> streaming;

  @override
  Component build(BuildContext context) {
    // Combine both signals into a single builder — they change together
    // during streaming anyway.
    return SignalBuilder<List<ChatMessage>>(
      signal: messages,
      builder: (context, msgs) {
        final stream = streaming.value;
        final hasStreamingItem =
            stream is TextStreaming && stream.text.isNotEmpty ||
                stream is AwaitingText && stream.hasThinkingContent;

        final itemCount = msgs.length + (hasStreamingItem ? 1 : 0);

        // Auto-scroll to bottom when streaming.
        if (stream != null && scrollController.atEnd) {
          scrollController.scrollToEnd();
        }

        return SelectionArea(
          child: Scrollbar(
            controller: scrollController,
            child: ListView.builder(
              controller: scrollController,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index < msgs.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: MessageItem(message: msgs[index]),
                  );
                }
                if (stream != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: StreamingMessageItem(streaming: stream),
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
