import 'dart:collection';

import 'package:soliplex_logging/src/sinks/disk_queue.dart';

/// Web fallback for [DiskQueue] using an in-memory list.
///
/// Web has no filesystem access, so records are held in memory.
/// Records do not survive page refreshes.
class PlatformDiskQueue implements DiskQueue {
  /// Creates an in-memory queue. [directoryPath] is ignored on web.
  PlatformDiskQueue({required this.directoryPath});

  /// Stored for API compatibility; not used on web.
  final String directoryPath;

  final _queue = Queue<Map<String, Object?>>();

  @override
  Future<void> append(Map<String, Object?> json) async {
    _queue.add(Map.of(json));
  }

  @override
  void appendSync(Map<String, Object?> json) {
    _queue.add(Map.of(json));
  }

  @override
  Future<List<Map<String, Object?>>> drain(int count) async {
    final results = <Map<String, Object?>>[];
    final iterator = _queue.iterator;
    while (results.length < count && iterator.moveNext()) {
      results.add(iterator.current);
    }
    return results;
  }

  @override
  Future<void> confirm(int count) async {
    for (var i = 0; i < count && _queue.isNotEmpty; i++) {
      _queue.removeFirst();
    }
  }

  @override
  Future<int> get pendingCount async => _queue.length;

  @override
  Future<void> close() async {
    _queue.clear();
  }
}
