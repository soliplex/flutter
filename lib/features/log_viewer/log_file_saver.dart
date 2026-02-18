import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/features/log_viewer/log_file_saver_native.dart'
    if (dart.library.js_interop) 'package:soliplex_frontend/features/log_viewer/log_file_saver_web.dart'
    as impl;

/// Platform-agnostic interface for saving exported log files.
///
/// Native desktop: gzip-compresses and saves to Downloads.
/// Native mobile: gzip-compresses and opens the OS share sheet.
/// Web: triggers a browser download via Blob + anchor.
mixin LogFileSaver {
  /// Saves [bytes] as a file with the given [filename].
  ///
  /// Returns the saved file path on desktop, or `null` on mobile/web where
  /// the OS handles the destination (share sheet / browser download).
  ///
  /// On iPad, [shareOrigin] positions the share sheet popover.
  Future<String?> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  });
}

/// Creates a platform-appropriate [LogFileSaver] implementation.
LogFileSaver createLogFileSaver() => impl.createLogFileSaver();

/// Provider for [LogFileSaver], overridable in tests.
final logFileSaverProvider = Provider<LogFileSaver>(
  (ref) => createLogFileSaver(),
);
