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
import 'package:soliplex_frontend/features/chat/widgets/anchored_scroll_controller.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/features/chat/widgets/scroll_button_controller.dart';
import 'package:soliplex_frontend/features/chat/widgets/scroll_to_message_session.dart';
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

/// Computes trailing spacer height for the message list.
///
/// - No scroll session and not streaming and last message not from user: 0.
/// - Before positioning: full [viewportHeight] (allows scroll-to-target).
/// - After positioning ([targetScrollOffset] set): dynamically shrinks
///   as content grows below the user message. Formula:
///     spacer = clamp(targetOffset + viewportHeight - realContent)
///   Uses [viewportHeight] (fresh, from LayoutBuilder) rather than
///   [viewportDimension] (stale, from scroll metrics) so the spacer
///   accounts for viewport size changes (e.g. status indicator removal).
///   The spacer persists after streaming ends when content < viewport.
@visibleForTesting
double computeSpacerHeight({
  required bool isStreaming,
  required ChatUser? lastMessageUser,
  required double viewportHeight,
  required double? targetScrollOffset,
  required double? maxScrollExtent,
  required double? viewportDimension,
  required double currentSpacerHeight,
}) {
  if (targetScrollOffset == null &&
      !isStreaming &&
      lastMessageUser != ChatUser.user) {
    return 0;
  }
  if (targetScrollOffset != null &&
      maxScrollExtent != null &&
      viewportDimension != null) {
    final realContent =
        maxScrollExtent + viewportDimension - currentSpacerHeight;
    return (targetScrollOffset + viewportHeight - realContent)
        .clamp(0.0, viewportHeight);
  }
  return viewportHeight;
}

/// Widget that displays the list of messages in the current thread.
///
/// Features:
/// - Scrollable list of messages using ListView.builder
/// - On send, scrolls the user's message to the top of the viewport
/// - Scroll-to-bottom floating button when scrolled away from latest content
/// - Empty state when no messages exist
///
/// The list uses [allMessagesProvider] which merges historical messages
/// (from API) with active run messages (streaming).
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
  final _scrollController = AnchoredScrollController();
  final GlobalKey _scrollTargetKey = GlobalKey();
  late final _scrollSession =
      ScrollToMessageSession(controller: _scrollController);
  final _scrollButton = ScrollButtonController();
  bool _hasScrolledOnLoad = false;
  double _spacerHeight = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    // On first data load, scroll to the content bottom (latest messages
    // visible), accounting for the dynamic trailing spacer.
    ref.listenManual(allMessagesProvider, (previous, next) {
      if (!_hasScrolledOnLoad && next.hasValue && next.value!.isNotEmpty) {
        _hasScrolledOnLoad = true;
        if (_scrollSession.targetMessageId == null) {
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
    _scrollButton.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    const threshold = 50.0;
    _scrollButton.updateScrollPosition(
      isAtBottom: pos.pixels >= (pos.maxScrollExtent - threshold),
    );
  }

  /// Scrolls the target message to the top of the viewport.
  ///
  /// Computes the exact scroll offset from the target's RenderObject
  /// position. Falls back to a retry loop when the widget is off-screen:
  /// jumps to content bottom (forcing ListView to build the target),
  /// then positions precisely on the next frame.
  void _scrollToTarget() {
    if (_jumpToReveal()) {
      return _finishScrollToTarget();
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
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target =
        (pos.maxScrollExtent - _spacerHeight).clamp(0.0, pos.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  void _retryScrollToTarget({required int retriesLeft}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollSession.isScheduled) return;
      if (_jumpToReveal()) {
        _finishScrollToTarget();
      } else if (retriesLeft > 0) {
        // Re-jump to current content bottom — maxScrollExtent may have
        // changed due to ListView extent estimation shifts.
        _jumpToContentBottom();
        _retryScrollToTarget(retriesLeft: retriesLeft - 1);
      } else {
        Loggers.chat.warning(
          'Scroll-to-target retries exhausted '
          'target=${_scrollSession.targetMessageId}',
        );
        _finishScrollToTarget();
      }
    });
  }

  void _finishScrollToTarget() {
    _scrollSession.finish();
    if (mounted) setState(() {});
  }

  /// Jumps to the scroll offset that places ctx's widget at the viewport
  /// top (alignment 0.0) and records the offset for dynamic spacer sizing.
  ///
  /// Returns true if positioning succeeded, false otherwise.
  bool _jumpToReveal() {
    if (!mounted || !_scrollController.hasClients) return false;

    final ctx = _scrollTargetKey.currentContext;
    if (ctx == null) return false;

    final renderObject = ctx.findRenderObject();
    if (renderObject == null) {
      Loggers.chat.warning(
        'Scroll target has no render object '
        'target=${_scrollSession.targetMessageId}',
      );
      return false;
    }

    if (!renderObject.attached) return false;

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      Loggers.chat.warning(
        'Scroll target is not inside a viewport '
        'target=${_scrollSession.targetMessageId}',
      );
      return false;
    }

    final offset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final pos = _scrollController.position;
    final clamped = offset.clamp(0.0, pos.maxScrollExtent);

    _scrollController.jumpTo(clamped);
    _scrollSession.targetScrollOffset = clamped;

    return true;
  }

  /// Detects a new user message from an active run and schedules scrolling.
  ///
  /// Done in build (not a listener) so the message is guaranteed in the
  /// display list. Must run before [_recomputeSpacerAndAnchor] so that
  /// [ScrollToMessageSession.scheduleFor] clears the stale
  /// targetScrollOffset, allowing the spacer to start at full viewport.
  void _detectNewMessageAndScheduleScroll(
    ActiveRunState runState,
    List<ChatMessage> messages,
    bool isStreaming,
  ) {
    Loggers.chat.debug(
      'DETECT: runState=${runState.runtimeType} '
      'isStreaming=$isStreaming '
      'msgCount=${messages.length} '
      'lastScrolledId=${_scrollSession.lastScrolledIdDebug} '
      'sessionScheduled=${_scrollSession.isScheduled}',
    );
    if (runState is! RunningState) return;

    final lastUserMsg =
        runState.messages.where((m) => m.user == ChatUser.user).lastOrNull;
    final inDisplayList =
        lastUserMsg != null && messages.any((m) => m.id == lastUserMsg.id);
    final shouldScroll = lastUserMsg != null &&
        _scrollSession.shouldScrollTo(lastUserMsg.id, messages);
    Loggers.chat.debug(
      'DETECT_RUN: lastUserMsg=${lastUserMsg?.id} '
      'inDisplayList=$inDisplayList '
      'shouldScroll=$shouldScroll',
    );
    if (lastUserMsg != null &&
        _scrollSession.shouldScrollTo(lastUserMsg.id, messages)) {
      _scrollSession.scheduleFor(lastUserMsg.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    }
  }

  /// Recomputes [_spacerHeight] and the controller's anchor offset.
  ///
  /// Tracks whether streaming content filled the viewport and releases
  /// the anchor when streaming ends in that case.
  void _recomputeSpacerAndAnchor({
    required bool isStreaming,
    required ChatUser? lastMessageUser,
    required double viewportHeight,
  }) {
    final hasClients = _scrollController.hasClients;
    final pos = hasClients ? _scrollController.position : null;

    final oldSpacerHeight = _spacerHeight;
    _spacerHeight = computeSpacerHeight(
      isStreaming: isStreaming,
      lastMessageUser: lastMessageUser,
      viewportHeight: viewportHeight,
      targetScrollOffset: _scrollSession.targetScrollOffset,
      maxScrollExtent: _scrollController.realMaxScrollExtent,
      viewportDimension: pos?.viewportDimension,
      currentSpacerHeight: _spacerHeight,
    );

    if (isStreaming &&
        _spacerHeight == 0 &&
        _scrollSession.targetScrollOffset != null) {
      _scrollSession.markContentFilled();
    }

    if (!isStreaming && _scrollSession.tryReleaseContentFilled()) {
      _spacerHeight = 0;
    }

    if (_spacerHeight != oldSpacerHeight) {
      final realMaxExt = _scrollController.realMaxScrollExtent;
      final realContent = (realMaxExt != null && pos?.viewportDimension != null)
          ? realMaxExt + pos!.viewportDimension - oldSpacerHeight
          : null;
      Loggers.chat.debug(
        'SPACER: $oldSpacerHeight -> $_spacerHeight | '
        'streaming=$isStreaming '
        'lastUser=$lastMessageUser '
        'targetOff=${_scrollSession.targetScrollOffset} '
        'realMaxExt=${realMaxExt?.toStringAsFixed(1)} '
        'inflatedMaxExt='
        '${pos?.maxScrollExtent.toStringAsFixed(1)} '
        'vpDim='
        '${pos?.viewportDimension.toStringAsFixed(1)} '
        'vpHeight=${viewportHeight.toStringAsFixed(1)} '
        'realContent='
        '${realContent?.toStringAsFixed(1)} '
        'pixels=${pos?.pixels.toStringAsFixed(1)}',
      );
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

    _detectNewMessageAndScheduleScroll(runState, messages, isStreaming);
    _recomputeSpacerAndAnchor(
      isStreaming: isStreaming,
      lastMessageUser: messages.lastOrNull?.user,
      viewportHeight: viewportHeight,
    );

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (notification.dragDetails != null &&
                  _scrollSession.isScheduled) {
                // finish() is safe mid-frame; setState must be deferred
                // since notification callbacks run during layout.
                _scrollSession.finish();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              }
              _scrollButton.hide();
            } else if (notification is ScrollEndNotification) {
              final pos = _scrollController.position;
              Loggers.chat.debug(
                'SCROLL_END: '
                'pixels=${pos.pixels.toStringAsFixed(1)} '
                'maxExt='
                '${pos.maxScrollExtent.toStringAsFixed(1)} '
                'realMaxExt='
                '${_scrollController.realMaxScrollExtent?.toStringAsFixed(1)} '
                'isAtBottom='
                '${pos.pixels >= pos.maxScrollExtent - 50} '
                'spacer='
                '${_spacerHeight.toStringAsFixed(1)} '
                'sessionScheduled='
                '${_scrollSession.isScheduled} '
                'targetOff='
                '${_scrollSession.targetScrollOffset}',
              );
              if (!_scrollSession.isScheduled) {
                _scrollButton.scheduleAppearance();
              }
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

              final key = _scrollSession.keyFor(message.id, _scrollTargetKey);

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
            child: ValueListenableBuilder<bool>(
              valueListenable: _scrollButton.isVisible,
              builder: (context, visible, child) => AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !visible,
                  child: child,
                ),
              ),
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _scrollButton.hide();
                    if (!_scrollController.hasClients) return;
                    _scrollSession.targetScrollOffset = null;
                    setState(() {});
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !_scrollController.hasClients) return;
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.arrow_downward,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
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
