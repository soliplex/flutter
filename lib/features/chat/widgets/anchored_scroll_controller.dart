import 'package:flutter/widgets.dart';

/// A [ScrollController] that prevents the scroll position from being clamped
/// below [anchorOffset] when content dimensions change.
///
/// When the viewport re-layouts due to content size changes (e.g. thinking
/// block collapse, status indicator removal), Flutter clamps the scroll
/// position to the new `maxScrollExtent`. If this drops below the anchor,
/// the user's message jumps away from the viewport top. This controller
/// intercepts that clamping via a custom [ScrollPosition] and holds the
/// position steady.
class AnchoredScrollController extends ScrollController {
  /// The scroll offset to anchor at. When set, the scroll position will not
  /// be clamped below this value by content dimension changes.
  double? anchorOffset;

  /// The real `maxScrollExtent` before any anchor inflation.
  ///
  /// When [anchorOffset] inflates the max, [ScrollPosition.maxScrollExtent]
  /// returns the inflated value. Use this for calculations that need the
  /// actual content extent (e.g. scroll-to-bottom target).
  double? get realMaxScrollExtent {
    if (!hasClients) return null;
    final pos = position;
    if (pos is _AnchoredScrollPosition) {
      return pos._realMaxScrollExtent ?? pos.maxScrollExtent;
    }
    return pos.maxScrollExtent;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _AnchoredScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }
}

class _AnchoredScrollPosition extends ScrollPositionWithSingleContext {
  _AnchoredScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final AnchoredScrollController controller;
  double? _realMaxScrollExtent;

  @override
  bool applyContentDimensions(
    double minScrollExtent,
    double maxScrollExtent,
  ) {
    _realMaxScrollExtent = maxScrollExtent;
    final anchor = controller.anchorOffset;
    if (anchor != null && hasPixels && anchor > maxScrollExtent) {
      // Content shrank and maxScrollExtent dropped below anchor.
      // Inflate maxScrollExtent so super doesn't clamp pixels below anchor.
      // The spacer will catch up in the next build, restoring the real
      // maxScrollExtent to >= anchor.
      return super.applyContentDimensions(minScrollExtent, anchor);
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
