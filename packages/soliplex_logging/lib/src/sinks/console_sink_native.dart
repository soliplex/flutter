import 'dart:developer' as developer;

import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/sinks/log_format.dart';

/// Writes a log record to the native console via dart:developer.
///
/// Called by `ConsoleSink.write` via conditional import on native platforms
/// (iOS, macOS, Android, Windows, Linux).
void writeToConsole(LogRecord record) {
  developer.log(
    formatLogMessage(record),
    name: record.loggerName,
    level: _mapLevel(record.level),
    time: record.timestamp,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}

/// Maps LogLevel to dart:developer log levels.
///
/// dart:developer uses numeric levels where higher values indicate
/// more severe log messages (0-2000 range).
int _mapLevel(LogLevel level) {
  return switch (level) {
    LogLevel.trace => 300,
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
    LogLevel.fatal => 1200,
  };
}
