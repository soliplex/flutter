// Native is the default, web overrides when js_interop is available.
import 'package:soliplex_logging/src/sinks/disk_queue_io.dart'
    if (dart.library.js_interop) 'package:soliplex_logging/src/sinks/disk_queue_web.dart'
    as platform;

/// Persistent write-ahead log for log records.
///
/// On native platforms, records are stored as JSONL (one JSON object per
/// line) in a file. On web, an in-memory list is used as a fallback.
///
/// Records survive crashes: a new [DiskQueue] instance pointed at the
/// same directory will pick up where the previous one left off.
abstract class DiskQueue {
  /// Creates a platform-appropriate queue.
  ///
  /// On native: [directoryPath] is used for JSONL file storage.
  /// On web: [directoryPath] is ignored; records are held in memory.
  factory DiskQueue({required String directoryPath}) =
      platform.PlatformDiskQueue;

  /// Appends a JSON record asynchronously.
  Future<void> append(Map<String, Object?> json);

  /// Appends a JSON record synchronously (blocks until written).
  ///
  /// Used for fatal logs to guarantee the record hits disk before
  /// the process dies.
  void appendSync(Map<String, Object?> json);

  /// Reads up to [count] records from the head of the queue.
  ///
  /// Corrupted lines (from mid-crash writes) are silently skipped.
  Future<List<Map<String, Object?>>> drain(int count);

  /// Removes [count] confirmed records from the head of the queue.
  Future<void> confirm(int count);

  /// Number of pending (unsent) records.
  Future<int> get pendingCount;

  /// Closes the queue and releases resources.
  Future<void> close();
}
