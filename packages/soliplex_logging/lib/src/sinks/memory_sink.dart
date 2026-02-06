import 'dart:async';
import 'dart:collection';

import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';

/// In-memory ring buffer sink for log records.
///
/// Retains the most recent [maxRecords] entries in chronological order.
/// When the buffer is full, the oldest record is evicted to make room.
///
/// Exposes [records] for snapshot retrieval (e.g., error handlers) and
/// [onRecord] stream for live UI updates (e.g., log viewer).
///
/// Uses `List` rather than `Queue` for O(1) random access, which is
/// required by `ListView.builder` in the log viewer UI.
class MemorySink implements LogSink {
  /// Creates a memory sink that retains at most [maxRecords] entries.
  MemorySink({this.maxRecords = 2000});

  /// Maximum number of records retained in the buffer.
  final int maxRecords;

  final List<LogRecord> _records = [];
  final StreamController<LogRecord> _controller =
      StreamController<LogRecord>.broadcast();

  /// Unmodifiable view of current records (oldest first).
  ///
  /// Returns a lightweight wrapper — no copy is made. Safe to index
  /// from `ListView.builder` without O(N) allocation per row.
  List<LogRecord> get records => UnmodifiableListView(_records);

  /// Stream of new records for live listeners.
  Stream<LogRecord> get onRecord => _controller.stream;

  /// Number of records currently retained.
  int get length => _records.length;

  @override
  void write(LogRecord record) {
    if (_records.length >= maxRecords) {
      _records.removeAt(0);
    }
    _records.add(record);
    if (!_controller.isClosed) {
      _controller.add(record);
    }
  }

  /// Clears all retained records.
  void clear() => _records.clear();

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async => _controller.close();
}
