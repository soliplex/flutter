import 'dart:js_interop';

import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/sinks/log_format.dart';

@JS('console')
external JSConsole get _console;

/// Extension type for browser console with flexible argument types.
///
/// Uses [JSAny?] to preserve object references for browser inspection.
/// The browser console can display these as expandable objects.
extension type JSConsole(JSObject _) implements JSObject {
  /// Logs a debug message (often hidden by default in browsers).
  external void debug(JSAny? message, [JSAny? arg1, JSAny? arg2]);

  /// Logs an info message (distinct icon in some browsers).
  external void info(JSAny? message, [JSAny? arg1, JSAny? arg2]);

  /// Logs a standard message.
  external void log(JSAny? message, [JSAny? arg1, JSAny? arg2]);

  /// Logs a warning message (yellow styling).
  external void warn(JSAny? message, [JSAny? arg1, JSAny? arg2]);

  /// Logs an error message (red styling).
  external void error(JSAny? message, [JSAny? arg1, JSAny? arg2]);
}

/// Writes a log record to the browser console.
///
/// Called by `ConsoleSink.write` via conditional import on web platform.
///
/// Maps log levels to appropriate console methods:
/// - trace/debug -> console.debug (often hidden by default)
/// - info -> console.info (distinct icon)
/// - warning -> console.warn (yellow styling)
/// - error/fatal -> console.error (red styling)
///
/// Stack traces are appended to the message for guaranteed visibility.
void writeToConsole(LogRecord record) {
  // Build message with stack trace appended for visibility.
  // Browser consoles often collapse additional arguments, so embedding
  // the stack trace in the message ensures it's always shown.
  var msgString = formatLogMessage(record);
  if (record.stackTrace != null) {
    msgString += '\n${record.stackTrace}';
  }

  final message = msgString.toJS;
  final errorArg = _convertError(record.error);

  switch (record.level) {
    case LogLevel.trace:
    case LogLevel.debug:
      _console.debug(message, errorArg);
    case LogLevel.info:
      _console.info(message, errorArg);
    case LogLevel.warning:
      _console.warn(message, errorArg);
    case LogLevel.error:
    case LogLevel.fatal:
      _console.error(message, errorArg);
  }
}

/// Converts a Dart error to a JS object for browser inspection.
///
/// Creates a structured object with type and message that browsers
/// can display as an expandable tree structure.
///
/// Returns null if conversion fails to ensure logging never crashes the app.
JSAny? _convertError(Object? error) {
  if (error == null) return null;

  // Create a JS object with error details that browsers can inspect.
  // Wrapped in try-catch because a logging library must never crash the app,
  // even if the error object has problematic toString() implementations.
  try {
    return <String, Object?>{
      'type': error.runtimeType.toString(),
      'message': error.toString(),
    }.jsify();
  } on Object {
    // If conversion fails (e.g., problematic toString), return a safe fallback.
    return '[Error conversion failed]'.toJS;
  }
}
