import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/send_message_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_input.dart';
import 'package:soliplex_frontend/features/chat/widgets/message_list.dart';
import 'package:soliplex_frontend/features/chat/widgets/status_indicator.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

/// Main chat panel that combines message list and input.
///
/// This panel:
/// - Displays messages from the current thread
/// - Provides input for sending new messages
/// - Handles thread creation for new conversations
/// - Handles errors with ErrorDisplay
/// - Supports document selection for narrowing RAG searches
///
/// The panel integrates with:
/// - [currentThreadProvider] for the active thread
/// - [activeRunNotifierProvider] for streaming state
/// - [threadSelectionProvider] for thread selection state
///
/// Example:
/// ```dart
/// ChatPanel()
/// ```
class ChatPanel extends ConsumerStatefulWidget {
  /// Creates a chat panel.
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  /// Pending document selection for when no thread exists yet.
  ///
  /// This holds the selection temporarily until a thread is created,
  /// at which point it's transferred to the provider.
  Set<RagDocument> _pendingDocuments = {};

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(activeRunNotifierProvider);
    final room = ref.watch(currentRoomProvider);
    final messagesAsync = ref.watch(allMessagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final currentThreadId = ref.watch(currentThreadIdProvider);

    // Clear pending documents when room changes to prevent carrying
    // selections across rooms
    ref.listen(currentRoomIdProvider, (previous, next) {
      if (previous != next && _pendingDocuments.isNotEmpty) {
        setState(() {
          _pendingDocuments = {};
        });
      }
    });

    // Show suggestions only when thread is empty and not streaming
    final messages =
        messagesAsync.hasValue ? messagesAsync.value! : <ChatMessage>[];
    final showSuggestions = messages.isEmpty && !isStreaming;

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
                          onRetry: () => _handleRetry(ref),
                        ),
                      _ => const MessageList(),
                    },
                  ),

                  // Status indicator (above input, shown only when streaming)
                  if (isStreaming)
                    StatusIndicator(streaming: runState.streaming),

                  // Input
                  ChatInput(
                    onSend: (text) => _handleSend(context, ref, text),
                    roomId: room?.id,
                    selectedDocuments:
                        _getSelectedDocuments(room?.id, currentThreadId),
                    onDocumentsChanged: (docs) => _updateSelectedDocuments(
                      room?.id,
                      currentThreadId,
                      docs,
                    ),
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

  /// Gets the selected documents for display.
  ///
  /// If a thread exists, reads from the provider. Otherwise, uses pending
  /// documents stored locally until a thread is created.
  Set<RagDocument> _getSelectedDocuments(String? roomId, String? threadId) {
    if (roomId != null && threadId != null) {
      return ref.watch(currentSelectedDocumentsProvider);
    }
    return _pendingDocuments;
  }

  /// Updates document selection.
  ///
  /// If a thread exists, updates the provider. Otherwise, stores in local
  /// pending state until a thread is created.
  void _updateSelectedDocuments(
    String? roomId,
    String? threadId,
    Set<RagDocument> documents,
  ) {
    if (roomId != null && threadId != null) {
      ref
          .read(selectedDocumentsNotifierProvider.notifier)
          .setForThread(roomId, threadId, documents);
    } else {
      setState(() {
        _pendingDocuments = documents;
      });
    }
  }

  /// Handles sending a message.
  Future<void> _handleSend(
    BuildContext context,
    WidgetRef ref,
    String text,
  ) async {
    final room = ref.read(currentRoomProvider);
    if (room == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No room selected')));
      }
      return;
    }

    final thread = ref.read(currentThreadProvider);
    final selection = ref.read(threadSelectionProvider);

    try {
      final result = await ref.read(sendMessageProvider).call(
            roomId: room.id,
            text: text,
            pendingDocuments: _pendingDocuments,
            currentThread: thread,
            isNewThreadIntent: selection is NewThreadIntent,
          );

      if (result.isNewThread) {
        // Update selection to the new thread
        ref
            .read(threadSelectionProvider.notifier)
            .set(ThreadSelected(result.threadId));

        // Clear pending documents now that they've been transferred
        if (_pendingDocuments.isNotEmpty) {
          setState(() {
            _pendingDocuments = {};
          });
        }

        // Persist last viewed and update URL
        await setLastViewedThread(
          roomId: room.id,
          threadId: result.threadId,
          invalidate: invalidateLastViewed(ref),
        );
        if (context.mounted) {
          context.go('/rooms/${room.id}?thread=${result.threadId}');
        }

        // Refresh threads list
        ref.invalidate(threadsProvider(room.id));
      }
    } on NetworkException catch (e, stackTrace) {
      Loggers.chat.error(
        'Failed to send message: Network error',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('Network error: ${e.message}')),
        );
      }
    } on AuthException catch (e, stackTrace) {
      Loggers.chat.error(
        'Failed to send message: Auth error',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error: ${e.message}')),
        );
      }
    } catch (e, stackTrace) {
      Loggers.chat.error(
        'Failed to send message',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  /// Handles retrying after an error.
  Future<void> _handleRetry(WidgetRef ref) async {
    await ref.read(activeRunNotifierProvider.notifier).reset();
  }
}
