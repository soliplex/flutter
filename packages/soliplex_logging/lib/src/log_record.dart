import 'package:meta/meta.dart';
import 'package:soliplex_logging/src/log_level.dart';

/// Immutable log record containing all information about a log event.
@immutable
class LogRecord {
  /// Creates a new log record.
  const LogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    required this.loggerName,
    this.error,
    this.stackTrace,
    this.spanId,
    this.traceId,
  });

  /// Severity level of this log.
  final LogLevel level;

  /// Log message.
  final String message;

  /// When this log was created.
  final DateTime timestamp;

  /// Name of the logger that created this record.
  final String loggerName;

  /// Associated error object, if any.
  final Object? error;

  /// Stack trace for error logs.
  final StackTrace? stackTrace;

  /// Span ID for telemetry correlation.
  final String? spanId;

  /// Trace ID for telemetry correlation.
  final String? traceId;

  /// Whether this record has error or stack trace details.
  bool get hasDetails => error != null || stackTrace != null;

  /// Formats the timestamp as `HH:mm:ss.mmm`.
  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('[${level.label}] $loggerName: $message');

    if (spanId != null || traceId != null) {
      buffer.write(' (');
      if (traceId != null) buffer.write('trace=$traceId');
      if (spanId != null && traceId != null) buffer.write(', ');
      if (spanId != null) buffer.write('span=$spanId');
      buffer.write(')');
    }

    if (error != null) {
      buffer
        ..writeln()
        ..write('Error: $error');
    }

    if (stackTrace != null) {
      buffer
        ..writeln()
        ..write(stackTrace);
    }

    return buffer.toString();
  }
}
