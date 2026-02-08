import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AwaitingText, ChatMessage, ChatUser, TextMessage, TextStreaming;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/source_references_provider.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/shared/widgets/empty_state.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

/// Result of computing display messages from history and streaming state.
@immutable
class DisplayMessagesResult {
  /// Creates a result with the computed messages and streaming flags.
  const DisplayMessagesResult(
    this.messages, {
    required this.hasSyntheticMessage,
    this.isThinkingStreaming = false,
  });

  /// The messages to display.
  final List<ChatMessage> messages;

  /// Whether a synthetic streaming message was appended.
  final bool hasSyntheticMessage;

  /// Whether thinking is currently streaming (only relevant for synthetic
  /// message).
  final bool isThinkingStreaming;
}

/// Computes the list of messages to display by merging historical messages
/// with the active streaming state.
///
/// Returns a [DisplayMessagesResult] containing:
/// - The merged message list
/// - Whether a synthetic message was created from streaming state
///
/// This is a pure function for testability.
/// Temporary ID for synthetic message during pre-text thinking phase.
const _kPendingThinkingId = '__pending_thinking__';

@visibleForTesting
DisplayMessagesResult computeDisplayMessages(
  List<ChatMessage> historicalMessages,
  ActiveRunState runState,
) {
  // Only RunningState can have active streaming
  if (runState is! RunningState) {
    return DisplayMessagesResult(
      historicalMessages,
      hasSyntheticMessage: false,
    );
  }

  final streaming = runState.streaming;

  // Actively streaming text - create synthetic message with text and thinking
  if (streaming is TextStreaming) {
    final syntheticMessage = TextMessage.create(
      id: streaming.messageId,
      user: streaming.user,
      text: streaming.text,
      thinkingText: streaming.thinkingText,
    );

    return DisplayMessagesResult(
      [...historicalMessages, syntheticMessage],
      hasSyntheticMessage: true,
      isThinkingStreaming: streaming.isThinkingStreaming,
    );
  }

  // Pre-text thinking: thinking events arrived but text hasn't started yet
  if (streaming is AwaitingText && streaming.hasThinkingContent) {
    final syntheticMessage = TextMessage.create(
      id: _kPendingThinkingId,
      user: ChatUser.assistant,
      text: '',
      thinkingText: streaming.bufferedThinkingText,
    );

    return DisplayMessagesResult(
      [...historicalMessages, syntheticMessage],
      hasSyntheticMessage: true,
      isThinkingStreaming: streaming.isThinkingStreaming,
    );
  }

  // Not streaming and no thinking - return history unchanged
  return DisplayMessagesResult(
    historicalMessages,
    hasSyntheticMessage: false,
  );
}

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

    _scrollController.addListener(_onScroll);

    ref.listenManual(activeRunNotifierProvider, (previous, next) {
      if (previous == null ||
          (previous is! RunningState && next is RunningState) ||
          (previous is RunningState && next is! RunningState)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Scroll listener to manage auto-scroll state.
  /// Disables auto-scroll if user scrolls up.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 50.0; // Pixels from bottom to consider "at bottom"

    final isAtBottom = (maxScroll - currentScroll) <= threshold;

    if (isAtBottom && !_autoScrollEnabled) {
      setState(() {
        _autoScrollEnabled = true;
      });
    } else if (!isAtBottom && _autoScrollEnabled) {
      setState(() {
        _autoScrollEnabled = false;
      });
    }
  }

  /// Scrolls to the bottom of the list.
  /// Can be forced to scroll even if auto-scroll is disabled.
  void _scrollToBottom({bool force = false, bool animate = false}) {
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
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(allMessagesProvider);
    final messagesNow =
        messagesAsync.hasValue ? messagesAsync.value! : <ChatMessage>[];
    final isStreaming = ref.watch(isStreamingProvider);
    final runState = ref.watch(activeRunNotifierProvider);

    // Show loading overlay, not different widget tree
    return Stack(
      children: [
        _buildMessageList(context, messagesNow, isStreaming, runState),
        if (messagesAsync.isLoading && messagesNow.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (messagesAsync.hasError && messagesNow.isEmpty)
          Center(
            child: ErrorDisplay(
              error: messagesAsync.error!,
              stackTrace: messagesAsync.stackTrace ?? StackTrace.empty,
            ),
          ),
      ],
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    List<ChatMessage> historicalMessages,
    bool isStreaming,
    ActiveRunState runState,
  ) {
    final soliplexTheme = SoliplexTheme.of(context);

    // Merge historical messages with streaming state
    final computation = computeDisplayMessages(historicalMessages, runState);
    final messages = computation.messages;

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
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isLast = index == messages.length - 1;
            final isSyntheticMessage =
                isLast && computation.hasSyntheticMessage;

            // Derive user message ID for citation lookup.
            // Citations are keyed by the user message that triggered the run,
            // so for an assistant message at index i, we look at index i-1.
            String? userMessageId;
            if (message.user == ChatUser.assistant && index > 0) {
              final preceding = messages[index - 1];
              if (preceding.user == ChatUser.user) {
                userMessageId = preceding.id;
              }
            }

            final sourceRefs = ref.watch(
              sourceReferencesForUserMessageProvider(userMessageId),
            );

            return ChatMessageWidget(
              key: ValueKey(message.id),
              message: message,
              isStreaming: isSyntheticMessage,
              isThinkingStreaming:
                  isSyntheticMessage && computation.isThinkingStreaming,
              sourceReferences: sourceRefs,
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
                  borderRadius: BorderRadius.circular(soliplexTheme.radii.xl),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scroll to bottom',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
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
