import 'package:flutter/foundation.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Configuration for the logging system.
@immutable
class LogConfig {
  /// Creates a log configuration.
  const LogConfig({
    required this.minimumLevel,
    required this.consoleLoggingEnabled,
    required this.stdoutLoggingEnabled,
  });

  /// Default configuration used before preferences are loaded.
  ///
  /// Both console (dart:developer) and stdout logging are enabled by default
  /// on desktop. This provides dual output: DevTools + terminal visibility.
  static const defaultConfig = LogConfig(
    minimumLevel: LogLevel.debug,
    consoleLoggingEnabled: true,
    stdoutLoggingEnabled: true,
  );

  /// Minimum log level to emit.
  final LogLevel minimumLevel;

  /// Whether console logging is enabled.
  final bool consoleLoggingEnabled;

  /// Whether stdout logging is enabled (desktop only).
  ///
  /// When true on desktop platforms, logs are written to stdout in addition
  /// to dart:developer. On mobile and web, this setting has no effect.
  final bool stdoutLoggingEnabled;

  /// Creates a copy with the specified fields replaced.
  LogConfig copyWith({
    LogLevel? minimumLevel,
    bool? consoleLoggingEnabled,
    bool? stdoutLoggingEnabled,
  }) {
    return LogConfig(
      minimumLevel: minimumLevel ?? this.minimumLevel,
      consoleLoggingEnabled:
          consoleLoggingEnabled ?? this.consoleLoggingEnabled,
      stdoutLoggingEnabled: stdoutLoggingEnabled ?? this.stdoutLoggingEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogConfig &&
          runtimeType == other.runtimeType &&
          minimumLevel == other.minimumLevel &&
          consoleLoggingEnabled == other.consoleLoggingEnabled &&
          stdoutLoggingEnabled == other.stdoutLoggingEnabled;

  @override
  int get hashCode =>
      Object.hash(minimumLevel, consoleLoggingEnabled, stdoutLoggingEnabled);

  @override
  String toString() => 'LogConfig(minimumLevel: $minimumLevel, '
      'consoleLoggingEnabled: $consoleLoggingEnabled, '
      'stdoutLoggingEnabled: $stdoutLoggingEnabled)';
}
