import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/chat_controller.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_input.dart';
import 'package:soliplex_frontend/features/chat/widgets/message_list.dart';
import 'package:soliplex_frontend/features/chat/widgets/status_indicator.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

/// Main chat panel that combines message list and input.
///
/// Delegates actions to [ChatController] and handles UI side-effects
/// (navigation, error display) based on [SendResult]. Display state
/// (messages, streaming, run state) is still watched directly —
/// consolidation into a `ChatViewState` is tracked in issue #207.
class ChatPanel extends ConsumerStatefulWidget {
  /// Creates a chat panel.
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  Future<void> _handleSend(String text) async {
    final result = await ref.read(chatControllerProvider.notifier).send(text);
    if (!mounted) return;
    switch (result) {
      case MessageSent():
        break;
      case ThreadCreated(:final roomId, :final threadId):
        context.go('/rooms/$roomId?thread=$threadId');
      case SendFailed(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(activeRunNotifierProvider);
    final room = ref.watch(currentRoomProvider);
    final messagesAsync = ref.watch(allMessagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final currentThreadId = ref.watch(currentThreadIdProvider);
    final pendingDocs = ref.watch(chatControllerProvider);
    final controller = ref.watch(chatControllerProvider.notifier);

    final messages =
        messagesAsync.hasValue ? messagesAsync.value! : <ChatMessage>[];
    final showSuggestions = messages.isEmpty && !isStreaming;

    final selectedDocs = (currentThreadId != null)
        ? ref.watch(currentSelectedDocumentsProvider)
        : pendingDocs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        final maxContentWidth =
            width >= SoliplexBreakpoints.desktop ? width * 2 / 3 : width;

        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                children: [
                  Expanded(
                    child: switch (runState) {
                      CompletedState(
                        result: FailedResult(
                          :final errorMessage,
                          :final stackTrace,
                        ),
                      ) =>
                        ErrorDisplay(
                          error: errorMessage,
                          stackTrace: stackTrace ?? StackTrace.empty,
                          onRetry: controller.retry,
                        ),
                      _ => const MessageList(),
                    },
                  ),

                  // Status indicator (above input, shown only when streaming)
                  if (isStreaming)
                    StatusIndicator(streaming: runState.streaming),

                  // Input
                  ChatInput(
                    onSend: _handleSend,
                    roomId: room?.id,
                    selectedDocuments: selectedDocs,
                    onDocumentsChanged: controller.updateDocuments,
                    suggestions: room?.suggestions ?? const [],
                    showSuggestions: showSuggestions,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
