import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soliplex_frontend/features/log_viewer/log_file_saver.dart';

/// Native implementation of [LogFileSaver].
///
/// Desktop (macOS/Linux/Windows): gzip-compresses and saves directly to the
/// Downloads folder — returns the path. Mobile (iOS/Android): gzip-compresses
/// and opens the OS share sheet with `shareOrigin` for iPad popover.
class NativeLogFileSaver with LogFileSaver {
  @override
  Future<String?> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async {
    final compressed = gzip.encode(bytes);
    final gzFilename = '$filename.gz';

    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return _saveToDownloads(gzFilename, compressed);
    }
    await _shareFile(gzFilename, compressed, shareOrigin);
    return null;
  }

  Future<String> _saveToDownloads(
    String filename,
    List<int> compressed,
  ) async {
    final dir = await getDownloadsDirectory();
    final path = '${dir!.path}/$filename';
    await File(path).writeAsBytes(compressed);
    return path;
  }

  Future<void> _shareFile(
    String filename,
    List<int> compressed,
    Rect? shareOrigin,
  ) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    await File(path).writeAsBytes(compressed);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        sharePositionOrigin: shareOrigin,
      ),
    );
  }
}

/// Factory for platform conditional import.
LogFileSaver createLogFileSaver() => NativeLogFileSaver();
