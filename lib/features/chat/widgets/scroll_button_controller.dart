import 'dart:async';

import 'package:flutter/material.dart';

/// Controls the scroll-to-bottom button visibility with timer-based logic.
///
/// Uses a [ValueNotifier] so only the button rebuilds on visibility changes,
/// not the entire message list.
class ScrollButtonController {
  final ValueNotifier<bool> isVisible = ValueNotifier(false);
  bool isAtBottom = true;
  Timer? _showTimer;
  Timer? _hideTimer;

  void scheduleAppearance() {
    if (isAtBottom) return;
    cancel();
    _showTimer = Timer(const Duration(milliseconds: 300), () {
      if (!isAtBottom) {
        isVisible.value = true;
        _hideTimer = Timer(const Duration(seconds: 3), () {
          isVisible.value = false;
        });
      }
    });
  }

  void cancel() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
  }

  void hide() {
    if (isVisible.value) {
      isVisible.value = false;
    }
  }

  void dispose() {
    cancel();
    isVisible.dispose();
  }
}
