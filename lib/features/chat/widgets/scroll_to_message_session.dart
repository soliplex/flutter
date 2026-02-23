import 'package:flutter/material.dart';

import 'package:soliplex_client/soliplex_client.dart';

/// Coordinates scrolling to a target message after the user sends.
///
/// Tracks which message to scroll to, whether a scroll sequence is in-flight,
/// and the computed scroll offset for dynamic spacer sizing.
class ScrollToMessageSession {
  /// Prevents re-triggering scroll for the same message across rebuilds.
  String? lastScrolledId;

  /// Message currently being scrolled to; controls GlobalKey assignment.
  String? targetMessageId;

  /// Guards against scheduling multiple scroll-to-target callbacks.
  bool isScheduled = false;

  /// Scroll offset that places the user message at the viewport top.
  /// Set by jumpToReveal; used to compute a dynamic spacer that
  /// prevents scrolling past this position.
  double? targetScrollOffset;

  /// Whether [id] should trigger a new scroll sequence.
  bool shouldScrollTo(String id, List<ChatMessage> messages) =>
      id != lastScrolledId && !isScheduled && messages.any((m) => m.id == id);

  /// Starts a scroll sequence for [id].
  void scheduleFor(String id) {
    lastScrolledId = id;
    targetMessageId = id;
    isScheduled = true;
  }

  /// Ends the current scroll sequence.
  void finish() {
    isScheduled = false;
    targetMessageId = null;
  }

  /// Returns the appropriate key for a message in itemBuilder.
  Key keyFor(String messageId, GlobalKey scrollKey) =>
      messageId == targetMessageId ? scrollKey : ValueKey(messageId);
}
