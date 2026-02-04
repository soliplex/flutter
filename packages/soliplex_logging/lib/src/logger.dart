import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_manager.dart';
import 'package:soliplex_logging/src/log_record.dart';

/// Logger facade for emitting log records.
class Logger {
  /// Creates a logger with the given name.
  Logger._(this.name, this._manager);

  /// The name of this logger.
  final String name;

  final LogManager _manager;

  /// Logs a trace-level message.
  void trace(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    _log(
      LogLevel.trace,
      message,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );
  }

  /// Logs a debug-level message.
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    _log(
      LogLevel.debug,
      message,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );
  }

  /// Logs an info-level message.
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    _log(
      LogLevel.info,
      message,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );
  }

  /// Logs a warning-level message.
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    _log(
      LogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );
  }

  /// Logs an error-level message.
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );
  }

  /// Logs a fatal-level message.
  void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    _log(
      LogLevel.fatal,
      message,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? spanId,
    String? traceId,
  }) {
    if (level < _manager.minimumLevel) return;

    final record = LogRecord(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      loggerName: name,
      error: error,
      stackTrace: stackTrace,
      spanId: spanId,
      traceId: traceId,
    );

    _manager.emit(record);
  }
}

/// Extension to create loggers via LogManager.
extension LoggerFactory on LogManager {
  /// Creates or retrieves a cached logger with the given name.
  Logger getLogger(String name) => Logger._(name, this);
}
