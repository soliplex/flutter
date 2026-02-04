import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';

/// Singleton manager for log sinks and configuration.
class LogManager {
  LogManager._();

  /// The singleton instance.
  static final LogManager instance = LogManager._();

  final List<LogSink> _sinks = [];

  /// Minimum log level. Logs below this level are filtered out.
  LogLevel minimumLevel = LogLevel.info;

  /// Adds a sink to receive log records.
  void addSink(LogSink sink) {
    if (!_sinks.contains(sink)) {
      _sinks.add(sink);
    }
  }

  /// Removes a sink.
  void removeSink(LogSink sink) {
    _sinks.remove(sink);
  }

  /// Returns all registered sinks.
  List<LogSink> get sinks => List.unmodifiable(_sinks);

  /// Emits a log record to all sinks.
  void emit(LogRecord record) {
    for (final sink in _sinks) {
      sink.write(record);
    }
  }

  /// Flushes all sinks.
  Future<void> flush() async {
    await Future.wait(_sinks.map((s) => s.flush()));
  }

  /// Closes all sinks.
  Future<void> close() async {
    await Future.wait(_sinks.map((s) => s.close()));
    _sinks.clear();
  }

  /// Resets the manager for testing.
  void reset() {
    _sinks.clear();
    minimumLevel = LogLevel.info;
  }
}
