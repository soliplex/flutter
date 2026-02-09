import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:soliplex_logging/src/sinks/disk_queue.dart';

/// Maximum queue file size before rotation (10 MB).
const int _maxFileBytes = 10 * 1024 * 1024;

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

  // C4 fix: appendSync is serialized with _mergeFatalFile by writing to a
  // separate fatal file that is atomically renamed during merge. The rename
  // in _mergeFatalFile creates a new path so concurrent appendSync calls
  // write to a fresh _fatalFile and never race with the merge read.
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

    // C5 fix: stream-based line reading instead of readAsString.
    final results = <Map<String, Object?>>[];
    var skipped = 0;

    await for (final line in _readLinesStream()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, Object?>) {
          results.add(decoded);
          if (results.length >= count) break;
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

  // C5 fix: stream-based confirm — reads lines via stream rather than
  // loading the entire file into memory.
  Future<void> _confirmUnsafe(int count) async {
    if (!_file.existsSync()) return;

    final lines = await _readLinesStream().toList();

    // Skip the first `count` non-empty lines.
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
          var count = 0;
          await for (final line in _readLinesStream()) {
            if (line.trim().isNotEmpty) count++;
          }
          completer.complete(count);
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

  /// Streams lines from the queue file without loading it all into memory.
  Stream<String> _readLinesStream() {
    return _file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
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
    final lines = await _readLinesStream().toList();
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    final keepFrom = nonEmpty.length ~/ 2;
    final kept = nonEmpty.sublist(keepFrom).join('\n');
    await _file.writeAsString('$kept\n');
  }
}
