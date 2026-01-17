import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show ChatMessage, Streaming;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/shared/widgets/empty_state.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

/// Widget that displays the list of messages in the current thread.
///
/// Features:
/// - Scrollable list of messages using ListView.builder
/// - Auto-scrolls to bottom when new messages arrive
/// - Shows activity indicator at bottom during streaming
/// - Empty state when no messages exist
///
/// The list uses [allMessagesProvider] which merges historical messages
/// (from API) with active run messages (streaming).
///
/// Example:
/// ```dart
/// MessageList()
/// ```
class MessageList extends ConsumerStatefulWidget {
  /// Creates a message list widget.
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    // 50 pixels margin to avoid accidentally triggering auto-scroll
    const threshold = 50.0;
    final atBottom = position.pixels >= position.maxScrollExtent - threshold;

    if (atBottom != _autoScrollEnabled && mounted) {
      setState(() {
        _autoScrollEnabled = atBottom;
      });
    }
  }

  /// Scrolls to the bottom of the list.
  /// Can be forced to scroll even if auto-scroll is disabled.
  void _scrollToBottom({bool force = false}) {
    if (!force && !_autoScrollEnabled) return;

    if (!_scrollController.hasClients) return;

    // If forced, re-enable auto-scroll state
    if (force && !_autoScrollEnabled) {
      if (mounted) {
        setState(() {
          _autoScrollEnabled = true;
        });
      }
    }

    // Use a post-frame callback to ensure the list has been built/updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(allMessagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final runState = ref.watch(activeRunNotifierProvider);

    // Scroll to bottom when messages change, if auto-scroll is enabled
    ref.listen<AsyncValue<List<ChatMessage>>>(allMessagesProvider, (
      previous,
      next,
    ) {
      final prevLength = switch (previous) {
        AsyncData(:final value) => value.length,
        _ => 0,
      };
      final nextLength = switch (next) {
        AsyncData(:final value) => value.length,
        _ => 0,
      };
      if (nextLength > prevLength) {
        _scrollToBottom();
      }
    });

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => ErrorDisplay(
        error: error,
        onRetry: () => ref.invalidate(allMessagesProvider),
      ),
      data: (messages) =>
          _buildMessageList(context, messages, isStreaming, runState),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    List<ChatMessage> messages,
    bool isStreaming,
    ActiveRunState runState,
  ) {
    final soliplexTheme = SoliplexTheme.of(context);

    // Empty state
    if (messages.isEmpty && !isStreaming) {
      return const EmptyState(
        message: 'No messages yet. Send one below!',
        icon: Icons.chat_bubble_outline,
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s4),
          itemCount: messages.length + (isStreaming ? 1 : 0),
          itemBuilder: (context, index) {
            // Show streaming indicator at the bottom
            if (index == messages.length) {
              return Semantics(
                label: 'Assistant is thinking',
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Assistant is thinking...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final message = messages[index];
            // Check if this message is currently being streamed
            final isCurrentlyStreaming = switch (runState) {
              RunningState(streaming: Streaming(:final messageId)) =>
                messageId == message.id,
              _ => false,
            };

            return ChatMessageWidget(
              key: ValueKey(message.id),
              message: message,
              isStreaming: isCurrentlyStreaming,
            );
          },
        ),

        // "Scroll to Bottom" button
        if (!_autoScrollEnabled)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(soliplexTheme.radii.xl),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    soliplexTheme.radii.xl,
                  ),
                  onTap: () => _scrollToBottom(force: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(
                        soliplexTheme.radii.xl,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scroll to bottom',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
