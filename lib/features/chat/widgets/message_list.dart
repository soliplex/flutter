import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show
        AwaitingText,
        ChatMessage,
        ChatUser,
        FeedbackType,
        TextMessage,
        TextStreaming;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/source_references_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
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
/// - On send, scrolls the user's message to the top of the viewport
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

  /// Key for the trailing spacer widget, exposed for testing.
  @visibleForTesting
  static const trailingSpacerKey = ValueKey('message-list-trailing-spacer');

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollTargetKey = GlobalKey();
  bool _isAtBottom = true;
  bool _hasScrolledOnLoad = false;
  double _spacerHeight = 0;

  // --- Scroll-to-target state ---
  // Three fields coordinate scrolling to the user message on send:
  //
  // _lastScrolledMessageId: prevents re-triggering for the same message
  //   across rebuilds (set once per message, never cleared during the run).
  //
  // _scrollTargetMessageId: the message currently being scrolled to.
  //   Controls GlobalKey assignment in itemBuilder. Cleared when
  //   positioning completes (or retries exhaust).
  //
  // _scrollToTargetScheduled: guards the entire scroll sequence (initial
  //   schedule + retries) so build() can't start a second one mid-flight.
  //
  // On send: _lastScrolledMessageId and _scrollTargetMessageId are both
  // set, _scrollToTargetScheduled goes true. If messages haven't loaded
  // yet (_scrollTargetMessageId is set), the initial-load listener in
  // initState skips its own jump to avoid conflicting.

  /// Prevents re-triggering scroll for the same message across rebuilds.
  String? _lastScrolledMessageId;

  /// Message currently being scrolled to; controls GlobalKey assignment.
  String? _scrollTargetMessageId;

  /// Scroll offset that places the user message at the viewport top.
  /// Set by [_jumpToReveal]; used to compute a dynamic spacer that
  /// prevents scrolling past this position.
  double? _targetScrollOffset;

  /// Guards against scheduling multiple scroll-to-target callbacks.
  bool _scrollToTargetScheduled = false;

  // Scroll-to-bottom button timers
  Timer? _showButtonTimer;
  Timer? _hideButtonTimer;
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    // On first data load, scroll to the content bottom (latest messages
    // visible), accounting for the dynamic trailing spacer.
    ref.listenManual(allMessagesProvider, (previous, next) {
      if (!_hasScrolledOnLoad && next.hasValue && next.value!.isNotEmpty) {
        _hasScrolledOnLoad = true;
        if (_scrollTargetMessageId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final pos = _scrollController.position;
              final target = (pos.maxScrollExtent - _spacerHeight).clamp(
                0.0,
                pos.maxScrollExtent,
              );
              _scrollController.jumpTo(target);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelButtonTimers();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Tracks whether the user is at the bottom of the list.
  ///
  /// The trailing spacer may add extra scroll extent, so the "content bottom"
  /// (last real message at the viewport bottom) is at
  /// maxScrollExtent - _spacerHeight.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    const threshold = 50.0;
    final contentBottom = pos.maxScrollExtent - _spacerHeight;
    final isAtBottom = pos.pixels >= (contentBottom - threshold);

    _isAtBottom = isAtBottom;
  }

  /// Scrolls the target message to the top of the viewport.
  ///
  /// Computes the exact scroll offset from the target's RenderObject
  /// position. Falls back to a two-step jump when the widget is off-screen:
  /// first jumps to content bottom (forcing ListView to build the target),
  /// then positions precisely on the next frame.
  void _scrollToTarget() {
    if (!mounted || !_scrollController.hasClients) return;

    final ctx = _scrollTargetKey.currentContext;
    if (ctx != null) {
      _jumpToReveal(ctx);
      _finishScrollToTarget();
      return;
    }

    // Target not yet built — jump to content bottom so ListView builds it.
    // ListView.builder uses estimated extents for unbuilt items; a large
    // jump can cause maxScrollExtent to shift dramatically on the next
    // layout pass. Each retry re-jumps to the CURRENT content bottom so
    // the position converges as estimates stabilize.
    _jumpToContentBottom();
    _retryScrollToTarget(retriesLeft: 3);
  }

  void _jumpToContentBottom() {
    final pos = _scrollController.position;
    final target =
        (pos.maxScrollExtent - _spacerHeight).clamp(0.0, pos.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  void _retryScrollToTarget({required int retriesLeft}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final ctx = _scrollTargetKey.currentContext;
      if (ctx != null) {
        _jumpToReveal(ctx);
        _finishScrollToTarget();
      } else if (retriesLeft > 0) {
        // Re-jump to current content bottom — maxScrollExtent may have
        // changed due to ListView extent estimation shifts.
        _jumpToContentBottom();
        _retryScrollToTarget(retriesLeft: retriesLeft - 1);
      } else {
        _finishScrollToTarget();
      }
    });
  }

  void _finishScrollToTarget() {
    _scrollToTargetScheduled = false;
    if (mounted) setState(() => _scrollTargetMessageId = null);
  }

  /// Jumps to the scroll offset that places [ctx]'s widget at the viewport
  /// top (alignment 0.0) and records the offset for dynamic spacer sizing.
  void _jumpToReveal(BuildContext ctx) {
    final renderObject = ctx.findRenderObject();
    if (renderObject == null) return;
    final viewport = RenderAbstractViewport.of(renderObject);
    final offset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final pos = _scrollController.position;
    final clamped = offset.clamp(0.0, pos.maxScrollExtent);
    _scrollController.jumpTo(clamped);
    _targetScrollOffset = clamped;
  }

  /// Computes trailing spacer height for the message list.
  ///
  /// - When idle with last message from assistant: 0 (no scrolling past).
  /// - Before positioning: full [viewportHeight] (allows scroll-to-target).
  /// - After positioning ([_targetScrollOffset] set): dynamically shrinks
  ///   as content grows below the user message. Formula:
  ///     spacer = clamp(targetOffset + viewportDimension - realContent)
  ///   This keeps maxScrollExtent = targetOffset until content fills the
  ///   viewport, then spacer drops to 0 and normal scrolling resumes.
  double _computeSpacerHeight({
    required bool isStreaming,
    required ChatUser? lastMessageUser,
    required double viewportHeight,
  }) {
    final needsSpacer = isStreaming || lastMessageUser == ChatUser.user;
    if (!needsSpacer) {
      _targetScrollOffset = null;
      return 0;
    }
    if (_targetScrollOffset != null && _scrollController.hasClients) {
      final pos = _scrollController.position;
      final realContent =
          pos.maxScrollExtent + pos.viewportDimension - _spacerHeight;
      return (_targetScrollOffset! + pos.viewportDimension - realContent)
          .clamp(0.0, viewportHeight);
    }
    return viewportHeight;
  }

  void _scheduleButtonAppearance() {
    if (_isAtBottom) return;
    _cancelButtonTimers();
    _showButtonTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isAtBottom) {
        setState(() {
          _showScrollButton = true;
        });
        _hideButtonTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showScrollButton = false;
            });
          }
        });
      }
    });
  }

  void _cancelButtonTimers() {
    _showButtonTimer?.cancel();
    _hideButtonTimer?.cancel();
  }

  void _hideButton() {
    if (_showScrollButton) {
      setState(() {
        _showScrollButton = false;
      });
    }
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
        LayoutBuilder(
          builder: (context, constraints) => _buildMessageList(
            context,
            messagesNow,
            isStreaming,
            runState,
            constraints.maxHeight,
          ),
        ),
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
    double viewportHeight,
  ) {
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

    final lastMessage = messages.isNotEmpty ? messages.last : null;
    _spacerHeight = _computeSpacerHeight(
      isStreaming: isStreaming,
      lastMessageUser: lastMessage?.user,
      viewportHeight: viewportHeight,
    );

    // Detect new user message from an active run and schedule scroll.
    // Done here in build (not in a listener) so _spacerHeight is guaranteed
    // fresh and the message is guaranteed in the display list.
    if (runState is RunningState && !_scrollToTargetScheduled) {
      final lastUserMsg =
          runState.messages.where((m) => m.user == ChatUser.user).lastOrNull;
      if (lastUserMsg != null &&
          lastUserMsg.id != _lastScrolledMessageId &&
          messages.any((m) => m.id == lastUserMsg.id)) {
        _lastScrolledMessageId = lastUserMsg.id;
        _scrollTargetMessageId = lastUserMsg.id;
        _scrollToTargetScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToTarget();
        });
      }
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _cancelButtonTimers();
              _hideButton();
            } else if (notification is ScrollEndNotification) {
              _scheduleButtonAppearance();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s4),
            itemCount: messages.length + 1,
            itemBuilder: (context, index) {
              // Trailing spacer so the user's message can reach the top.
              if (index == messages.length) {
                return SizedBox(
                  key: MessageList.trailingSpacerKey,
                  height: _spacerHeight,
                );
              }

              final message = messages[index];
              final isLast = index == messages.length - 1;
              final isSyntheticMessage =
                  isLast && computation.hasSyntheticMessage;

              // Derive user message ID for citation lookup.
              // Citations are keyed by the user message that triggered the
              // run, so for an assistant message at index i, we look at
              // index i-1.
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

              void Function(FeedbackType, String?)? onFeedbackSubmit;
              if (userMessageId != null) {
                final roomId = ref.read(currentRoomIdProvider);
                final threadId = ref.read(currentThreadIdProvider);
                final runId = ref.read(
                  runIdForUserMessageProvider(userMessageId),
                );
                final api = ref.read(apiProvider);
                onFeedbackSubmit = (FeedbackType feedback, String? reason) {
                  if (runId == null || roomId == null || threadId == null) {
                    return;
                  }
                  unawaited(
                    api
                        .submitFeedback(
                      roomId,
                      threadId,
                      runId,
                      feedback,
                      reason: reason,
                    )
                        .catchError((Object e, StackTrace st) {
                      Loggers.chat.error(
                        'Feedback submission failed',
                        error: e,
                        stackTrace: st,
                      );
                    }),
                  );
                };
              }

              final key = (message.id == _scrollTargetMessageId)
                  ? _scrollTargetKey
                  : ValueKey(message.id);

              return ChatMessageWidget(
                key: key,
                message: message,
                isStreaming: isSyntheticMessage,
                isThinkingStreaming:
                    isSyntheticMessage && computation.isThinkingStreaming,
                sourceReferences: sourceRefs,
                onFeedbackSubmit: onFeedbackSubmit,
              );
            },
          ),
        ),

        // Scroll-to-bottom button (icon only, timer-based visibility).
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              opacity: _showScrollButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showScrollButton,
                child: Material(
                  elevation: 4,
                  shape: const CircleBorder(),
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _hideButton();
                      _cancelButtonTimers();
                      final pos = _scrollController.position;
                      final target = (pos.maxScrollExtent - _spacerHeight)
                          .clamp(0.0, pos.maxScrollExtent);
                      _scrollController.animateTo(
                        target,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 20,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
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
