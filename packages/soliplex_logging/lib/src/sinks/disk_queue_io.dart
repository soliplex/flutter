import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:soliplex_logging/src/sinks/disk_queue.dart';

/// Maximum queue file size before rotation (10 MB).
const _maxFileBytes = 10 * 1024 * 1024;

/// Native (io) implementation of [DiskQueue] using JSONL files.
class PlatformDiskQueue implements DiskQueue {
  /// Creates a disk queue that stores records in [directoryPath].
  PlatformDiskQueue({required String directoryPath})
      : _directory = Directory(directoryPath) {
    _directory.createSync(recursive: true);
    _file = File('${_directory.path}/log_queue.jsonl');
    _fatalFile = File('${_directory.path}/log_queue_fatal.jsonl');
  }

  final Directory _directory;
  late final File _file;
  late final File _fatalFile;

  /// Serializes async writes to prevent file corruption.
  Future<void> _writeLock = Future.value();

  @override
  Future<void> append(Map<String, Object?> json) {
    final completer = Completer<void>();
    _writeLock = _writeLock.then((_) async {
      try {
        await _rotateIfNeeded();
        final line = '${jsonEncode(json)}\n';
        await _file.writeAsString(line, mode: FileMode.append, flush: true);
        completer.complete();
      } on Object catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  @override
  void appendSync(Map<String, Object?> json) {
    final line = '${jsonEncode(json)}\n';
    _fatalFile.writeAsStringSync(line, mode: FileMode.append, flush: true);
  }

  @override
  Future<List<Map<String, Object?>>> drain(int count) {
    final completer = Completer<List<Map<String, Object?>>>();
    _writeLock = _writeLock.then((_) async {
      try {
        completer.complete(await _drainUnsafe(count));
      } on Object catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<List<Map<String, Object?>>> _drainUnsafe(int count) async {
    await _mergeFatalFile();
    if (!_file.existsSync()) return const [];

    final lines = await _readLines();
    final results = <Map<String, Object?>>[];
    var skipped = 0;

    for (var i = 0; i < lines.length && results.length < count; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, Object?>) {
          results.add(decoded);
        } else {
          skipped++;
        }
      } on FormatException {
        skipped++;
      }
    }

    if (skipped > 0) {
      developer.log(
        'Skipped $skipped corrupted lines during drain',
        name: 'DiskQueue',
      );
    }

    return results;
  }

  @override
  Future<void> confirm(int count) {
    final completer = Completer<void>();
    _writeLock = _writeLock.then((_) async {
      try {
        await _confirmUnsafe(count);
        completer.complete();
      } on Object catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<void> _confirmUnsafe(int count) async {
    if (!_file.existsSync()) return;

    final lines = await _readLines();
    // Skip the first `count` non-empty lines
    var removed = 0;
    var lineIndex = 0;
    while (lineIndex < lines.length && removed < count) {
      if (lines[lineIndex].trim().isNotEmpty) {
        removed++;
      }
      lineIndex++;
    }

    final remaining = lines.sublist(lineIndex).join('\n');
    if (remaining.trim().isEmpty) {
      // File is now empty, delete to avoid stale file.
      await _file.writeAsString('');
    } else {
      await _file.writeAsString('$remaining\n');
    }
  }

  @override
  Future<int> get pendingCount {
    final completer = Completer<int>();
    _writeLock = _writeLock.then((_) async {
      try {
        if (!_file.existsSync()) {
          completer.complete(0);
        } else {
          final lines = await _readLines();
          completer.complete(
            lines.where((l) => l.trim().isNotEmpty).length,
          );
        }
      } on Object catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  @override
  Future<void> close() async {
    // No resources to release for file-based queue.
  }

  /// Merges fatal file contents into the main queue file (under lock).
  ///
  /// Uses atomic rename so that concurrent [appendSync] calls write to a
  /// fresh file and never race with the merge read/truncate.
  Future<void> _mergeFatalFile() async {
    final mergePath = '${_directory.path}/.fatal_merge.jsonl';
    final mergeFile = File(mergePath);

    // Recover leftover merge file from a previous crash.
    await _appendAndDelete(mergeFile);

    if (!_fatalFile.existsSync()) return;

    // Atomic rename: after this, appendSync creates a new _fatalFile.
    try {
      _fatalFile.renameSync(mergePath);
    } on FileSystemException {
      return;
    }

    await _appendAndDelete(mergeFile);
  }

  /// Appends [source] contents to the main queue file, then deletes it.
  Future<void> _appendAndDelete(File source) async {
    if (!source.existsSync()) return;
    final content = source.readAsStringSync();
    if (content.trim().isNotEmpty) {
      await _file.writeAsString(content, mode: FileMode.append, flush: true);
    }
    source.deleteSync();
  }

  Future<List<String>> _readLines() async {
    final content = await _file.readAsString();
    return content.split('\n');
  }

  Future<void> _rotateIfNeeded() async {
    if (!_file.existsSync()) return;
    final stat = _file.statSync();
    if (stat.size > _maxFileBytes) {
      await _dropOldest();
    }
  }

  /// Drops the oldest half of records when file exceeds size limit.
  Future<void> _dropOldest() async {
    final lines = await _readLines();
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    final keepFrom = nonEmpty.length ~/ 2;
    final kept = nonEmpty.sublist(keepFrom).join('\n');
    await _file.writeAsString('$kept\n');
  }
}
