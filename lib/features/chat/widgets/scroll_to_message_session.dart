import 'package:flutter/material.dart';

import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/features/chat/widgets/anchored_scroll_controller.dart';

/// Coordinates scrolling to a target message after the user sends.
///
/// Tracks which message to scroll to, whether a scroll sequence is in-flight,
/// and the computed scroll offset that anchors the target position.
///
/// Owns the relationship between [targetScrollOffset] and the controller's
/// [AnchoredScrollController.anchorOffset] — setting [targetScrollOffset]
/// automatically syncs the anchor.
class ScrollToMessageSession {
  /// Creates a session that syncs [targetScrollOffset] to [controller]'s
  /// anchor.
  ScrollToMessageSession({required AnchoredScrollController controller})
      : _controller = controller;

  final AnchoredScrollController _controller;
  String? _lastScrolledId;
  String? _targetMessageId;
  bool _isScheduled = false;
  bool _contentFilledViewport = false;
  double? _targetScrollOffset;

  /// Whether a scroll sequence is currently in-flight.
  bool get isScheduled => _isScheduled;

  /// Debug-only accessor for the last scrolled message ID.
  String? get lastScrolledIdDebug => _lastScrolledId;

  /// Message currently being scrolled to; controls GlobalKey assignment.
  String? get targetMessageId => _targetMessageId;

  /// Scroll offset that places the user message at the viewport top.
  /// Set after positioning completes; used to compute a dynamic spacer
  /// that prevents scrolling past this position.
  ///
  /// Setting this also updates [AnchoredScrollController.anchorOffset].
  double? get targetScrollOffset => _targetScrollOffset;
  set targetScrollOffset(double? value) {
    _targetScrollOffset = value;
    _controller.anchorOffset = value;
  }

  /// Whether [id] should trigger a new scroll sequence.
  bool shouldScrollTo(String id, List<ChatMessage> messages) =>
      id != _lastScrolledId && !_isScheduled && messages.any((m) => m.id == id);

  /// Starts a scroll sequence for [id].
  void scheduleFor(String id) {
    _lastScrolledId = id;
    _targetMessageId = id;
    _isScheduled = true;
    targetScrollOffset = null;
    _contentFilledViewport = false;
  }

  /// Ends the current scroll sequence.
  void finish() {
    _isScheduled = false;
    _targetMessageId = null;
  }

  /// Records that streaming content grew past the viewport.
  void markContentFilled() {
    _contentFilledViewport = true;
  }

  /// Releases [targetScrollOffset] when content filled the viewport during
  /// streaming. Returns true if released (caller must clear controller
  /// anchor).
  bool tryReleaseContentFilled() {
    if (!_contentFilledViewport) return false;
    targetScrollOffset = null;
    _contentFilledViewport = false;
    return true;
  }

  /// Returns the appropriate key for a message in itemBuilder.
  Key keyFor(String messageId, GlobalKey scrollKey) =>
      messageId == _targetMessageId ? scrollKey : ValueKey(messageId);
}
