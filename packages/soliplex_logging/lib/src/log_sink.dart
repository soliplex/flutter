import 'package:soliplex_logging/src/log_record.dart';

/// Interface for log output destinations.
abstract interface class LogSink {
  /// Writes a log record to this sink.
  void write(LogRecord record);

  /// Flushes any buffered output.
  Future<void> flush();

  /// Closes this sink and releases resources.
  Future<void> close();
}
