import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';

/// Controls the scroll-to-bottom button visibility with timer-based logic.
///
/// Uses a [ValueNotifier] so only the button rebuilds on visibility changes,
/// not the entire message list.
class ScrollButtonController {
  final ValueNotifier<bool> _isVisible = ValueNotifier(false);
  bool _isAtBottom = true;
  Timer? _showTimer;
  Timer? _hideTimer;

  /// Whether the button should be visible. Read-only from outside the
  /// controller.
  ValueListenable<bool> get isVisible => _isVisible;

  /// Updates the scroll position state. Hides the button and cancels
  /// pending timers if the user has scrolled back to the bottom.
  void updateScrollPosition({required bool isAtBottom}) {
    if (_isAtBottom != isAtBottom) {
      Loggers.chat.debug(
        'BTN_AT_BOTTOM: $_isAtBottom -> $isAtBottom',
      );
    }
    _isAtBottom = isAtBottom;
    if (isAtBottom) hide();
  }

  /// Schedules the button to appear after a brief delay, then auto-hide.
  /// No-op if already at the bottom of the scroll view.
  void scheduleAppearance() {
    if (_isAtBottom) return;
    _cancel();
    Loggers.chat.debug(
      'BTN_SCHEDULE: _isAtBottom=$_isAtBottom (at call time)',
    );
    _showTimer = Timer(const Duration(milliseconds: 300), () {
      Loggers.chat.debug(
        'BTN_TIMER: _isAtBottom=$_isAtBottom (300ms later)',
      );
      if (!_isAtBottom) {
        Loggers.chat.debug('BTN_SHOW: button made visible');
        _isVisible.value = true;
        _hideTimer = Timer(const Duration(seconds: 3), () {
          _isVisible.value = false;
        });
      }
    });
  }

  /// Cancels pending show/hide timers.
  void _cancel() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
  }

  /// Hides the button immediately and cancels pending timers.
  void hide() {
    _cancel();
    if (_isVisible.value) {
      _isVisible.value = false;
    }
  }

  /// Releases resources. Must be called when the owning widget is disposed.
  void dispose() {
    _cancel();
    _isVisible.dispose();
  }
}
