import 'package:flutter/material.dart';

import 'package:soliplex_client/soliplex_client.dart';

/// Coordinates scrolling to a target message after the user sends.
///
/// Tracks which message to scroll to, whether a scroll sequence is in-flight,
/// and the computed scroll offset that anchors the target position.
class ScrollToMessageSession {
  String? _lastScrolledId;
  String? _targetMessageId;
  bool _isScheduled = false;

  /// Message currently being scrolled to; controls GlobalKey assignment.
  String? get targetMessageId => _targetMessageId;

  /// Scroll offset that places the user message at the viewport top.
  /// Set after positioning completes; used to compute a dynamic spacer
  /// that prevents scrolling past this position.
  double? targetScrollOffset;

  /// Whether [id] should trigger a new scroll sequence.
  bool shouldScrollTo(String id, List<ChatMessage> messages) =>
      id != _lastScrolledId && !_isScheduled && messages.any((m) => m.id == id);

  /// Starts a scroll sequence for [id].
  void scheduleFor(String id) {
    _lastScrolledId = id;
    _targetMessageId = id;
    _isScheduled = true;
  }

  /// Ends the current scroll sequence.
  void finish() {
    _isScheduled = false;
    _targetMessageId = null;
  }

  /// Returns the appropriate key for a message in itemBuilder.
  Key keyFor(String messageId, GlobalKey scrollKey) =>
      messageId == _targetMessageId ? scrollKey : ValueKey(messageId);
}
