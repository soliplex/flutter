import 'dart:async';

import 'package:visibility_detector/visibility_detector.dart';

/// Global test configuration that runs before all test files.
///
/// Disables [VisibilityDetector] debounce timers so they don't leak
/// pending timers after widget tree disposal. Required because
/// `markdown_widget` uses VisibilityDetector internally.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await testMain();
}
