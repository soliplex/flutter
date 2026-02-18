import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:soliplex_frontend/features/log_viewer/log_file_saver.dart';
import 'package:web/web.dart' as web;

/// Web implementation of [LogFileSaver].
///
/// Creates a Blob from the bytes, generates an object URL, and triggers a
/// browser download via a hidden anchor element. No compression — web export
/// is capped at ~400 KB / 2000 records.
class WebLogFileSaver with LogFileSaver {
  @override
  Future<String?> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/x-ndjson'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
    return null;
  }
}

/// Factory for platform conditional import.
LogFileSaver createLogFileSaver() => WebLogFileSaver();
