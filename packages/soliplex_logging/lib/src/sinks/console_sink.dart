import 'dart:developer' as developer;

import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';

/// Log sink that outputs to the console via dart:developer.
class ConsoleSink implements LogSink {
  /// Creates a console sink.
  ConsoleSink({this.enabled = true});

  /// Whether this sink is enabled.
  bool enabled;

  @override
  void write(LogRecord record) {
    if (!enabled) return;

    final output = _format(record);

    developer.log(
      output,
      name: record.loggerName,
      level: _mapLevel(record.level),
      time: record.timestamp,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  @override
  Future<void> flush() async {
    // Console output is unbuffered.
  }

  @override
  Future<void> close() async {
    enabled = false;
  }

  String _format(LogRecord record) {
    final buffer = StringBuffer()
      ..write('[${record.level.label}] ${record.message}');

    if (record.spanId != null || record.traceId != null) {
      buffer.write(' (');
      if (record.traceId != null) buffer.write('trace=${record.traceId}');
      if (record.spanId != null && record.traceId != null) buffer.write(', ');
      if (record.spanId != null) buffer.write('span=${record.spanId}');
      buffer.write(')');
    }

    return buffer.toString();
  }

  int _mapLevel(LogLevel level) {
    // dart:developer log levels: 0-2000
    // Map our levels to reasonable values
    return switch (level) {
      LogLevel.trace => 300,
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
      LogLevel.fatal => 1200,
    };
  }
}
