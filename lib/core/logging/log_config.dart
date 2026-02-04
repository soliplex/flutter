import 'package:flutter/foundation.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Configuration for the logging system.
@immutable
class LogConfig {
  /// Creates a log configuration.
  const LogConfig({
    required this.minimumLevel,
    required this.consoleLoggingEnabled,
  });

  /// Default configuration used before preferences are loaded.
  static const defaultConfig = LogConfig(
    minimumLevel: LogLevel.info,
    consoleLoggingEnabled: true,
  );

  /// Minimum log level to emit.
  final LogLevel minimumLevel;

  /// Whether console logging is enabled.
  final bool consoleLoggingEnabled;

  /// Creates a copy with the specified fields replaced.
  LogConfig copyWith({
    LogLevel? minimumLevel,
    bool? consoleLoggingEnabled,
  }) {
    return LogConfig(
      minimumLevel: minimumLevel ?? this.minimumLevel,
      consoleLoggingEnabled:
          consoleLoggingEnabled ?? this.consoleLoggingEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogConfig &&
          runtimeType == other.runtimeType &&
          minimumLevel == other.minimumLevel &&
          consoleLoggingEnabled == other.consoleLoggingEnabled;

  @override
  int get hashCode => Object.hash(minimumLevel, consoleLoggingEnabled);

  @override
  String toString() =>
      'LogConfig(minimumLevel: $minimumLevel, '
      'consoleLoggingEnabled: $consoleLoggingEnabled)';
}
