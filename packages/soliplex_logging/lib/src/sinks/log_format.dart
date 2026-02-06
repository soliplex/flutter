import 'package:soliplex_logging/src/log_record.dart';

/// Formats a [DateTime] as `HH:mm:ss.mmm` for compact log output.
String formatTimestamp(DateTime timestamp) {
  final h = timestamp.hour.toString().padLeft(2, '0');
  final m = timestamp.minute.toString().padLeft(2, '0');
  final s = timestamp.second.toString().padLeft(2, '0');
  final ms = timestamp.millisecond.toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}

/// Formats the basic log message (level, logger, message, spans).
///
/// When [showTimestamp] is true, prepends the record's timestamp in
/// `HH:mm:ss.mmm` format.
///
/// Error and stackTrace are handled separately by each platform implementation
/// since they have different capabilities:
/// - Native: `dart:developer` accepts them as separate parameters
/// - Web: Browser console can display them as expandable objects
String formatLogMessage(LogRecord record, {bool showTimestamp = false}) {
  final buffer = StringBuffer();

  if (showTimestamp) {
    buffer.write('${formatTimestamp(record.timestamp)} ');
  }

  buffer
      .write('[${record.level.label}] ${record.loggerName}: ${record.message}');

  if (record.spanId != null || record.traceId != null) {
    buffer.write(' (');
    if (record.traceId != null) buffer.write('trace=${record.traceId}');
    if (record.spanId != null && record.traceId != null) buffer.write(', ');
    if (record.spanId != null) buffer.write('span=${record.spanId}');
    buffer.write(')');
  }

  return buffer.toString();
}
