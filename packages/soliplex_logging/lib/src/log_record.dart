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
    this.attributes = const {},
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

  /// Structured key-value attributes for contextual metadata.
  final Map<String, Object> attributes;

  /// Returns a copy of this record with the given fields replaced.
  LogRecord copyWith({
    LogLevel? level,
    String? message,
    DateTime? timestamp,
    String? loggerName,
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
    Map<String, Object>? attributes,
  }) {
    return LogRecord(
      level: level ?? this.level,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      loggerName: loggerName ?? this.loggerName,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      spanId: spanId ?? this.spanId,
      traceId: traceId ?? this.traceId,
      attributes: attributes ?? this.attributes,
    );
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

    if (attributes.isNotEmpty) {
      buffer.write(' $attributes');
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
