import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// SharedPreferences key for minimum log level.
const _kLogLevelKey = 'log_level';

/// SharedPreferences key for console logging enabled.
const _kConsoleLoggingKey = 'console_logging';

/// SharedPreferences key for stdout logging enabled.
const _kStdoutLoggingKey = 'stdout_logging';

/// Notifier for managing log configuration.
class LogConfigNotifier extends AsyncNotifier<LogConfig> {
  @override
  Future<LogConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadConfig(prefs);
  }

  LogConfig _loadConfig(SharedPreferences prefs) {
    final levelIndex = prefs.getInt(_kLogLevelKey);
    final consoleEnabled = prefs.getBool(_kConsoleLoggingKey);
    final stdoutEnabled = prefs.getBool(_kStdoutLoggingKey);

    return LogConfig(
      minimumLevel: levelIndex != null && levelIndex < LogLevel.values.length
          ? LogLevel.values[levelIndex]
          : LogConfig.defaultConfig.minimumLevel,
      consoleLoggingEnabled:
          consoleEnabled ?? LogConfig.defaultConfig.consoleLoggingEnabled,
      stdoutLoggingEnabled:
          stdoutEnabled ?? LogConfig.defaultConfig.stdoutLoggingEnabled,
    );
  }

  /// Updates the minimum log level.
  Future<void> setMinimumLevel(LogLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLogLevelKey, level.index);

    state = AsyncData(
      state.value?.copyWith(minimumLevel: level) ??
          LogConfig.defaultConfig.copyWith(minimumLevel: level),
    );
  }

  /// Updates whether console logging is enabled.
  Future<void> setConsoleLoggingEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsoleLoggingKey, enabled);

    state = AsyncData(
      state.value?.copyWith(consoleLoggingEnabled: enabled) ??
          LogConfig.defaultConfig.copyWith(consoleLoggingEnabled: enabled),
    );
  }

  /// Updates whether stdout logging is enabled (desktop only).
  Future<void> setStdoutLoggingEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStdoutLoggingKey, enabled);

    state = AsyncData(
      state.value?.copyWith(stdoutLoggingEnabled: enabled) ??
          LogConfig.defaultConfig.copyWith(stdoutLoggingEnabled: enabled),
    );
  }
}

/// Provider for log configuration.
final logConfigProvider =
    AsyncNotifierProvider<LogConfigNotifier, LogConfig>(LogConfigNotifier.new);

// ============================================================================
// Sink Instance Providers
// ============================================================================
// These providers own the sink lifecycle. They create the sink once, register
// it with LogManager, and clean up on dispose. They do NOT watch config -
// configuration is applied by the controller.

/// Holds the ConsoleSink instance.
///
/// Created once per provider container. Registered with LogManager on creation,
/// unregistered on dispose. The sink starts disabled and is enabled by the
/// controller when config loads.
final consoleSinkProvider = Provider<ConsoleSink>((ref) {
  ref.keepAlive();

  // Start disabled - controller will enable based on config.
  final sink = ConsoleSink(enabled: false);
  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
  });

  return sink;
});

/// Holds the StdoutSink instance (desktop platforms only).
///
/// Returns null on non-desktop platforms. On desktop, creates the sink once,
/// registers with LogManager, and cleans up on dispose. Starts disabled.
final stdoutSinkProvider = Provider<StdoutSink?>((ref) {
  if (kIsWeb) return null;

  final isDesktop = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => true,
    TargetPlatform.windows => true,
    TargetPlatform.linux => true,
    _ => false,
  };

  if (!isDesktop) return null;

  ref.keepAlive();

  // Start disabled - controller will enable based on config.
  final sink = StdoutSink(enabled: false);
  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
  });

  return sink;
});

// ============================================================================
// Log Config Controller
// ============================================================================
// This provider manages the side effects of applying config to the logging
// system. It listens to config changes and updates sink states accordingly.
// Uses ref.listen (not ref.watch) to avoid rebuilding on config changes.

/// Controller that applies log configuration to the logging system.
///
/// This provider:
/// - Sets the global minimum log level on LogManager
/// - Enables/disables sinks based on config
/// - Uses ref.listen to react to config changes without rebuilding sinks
///
/// Watch this provider in your app root to initialize logging.
final logConfigControllerProvider = Provider<void>((ref) {
  ref.keepAlive();

  // Get sink instances (these are stable - won't rebuild).
  final consoleSink = ref.read(consoleSinkProvider);
  final stdoutSink = ref.read(stdoutSinkProvider);

  // Listen to config changes and apply them.
  ref.listen(
    logConfigProvider,
    (previous, next) {
      next.whenData((config) {
        // Apply minimum level to LogManager (centralized ownership).
        LogManager.instance.minimumLevel = config.minimumLevel;

        // Enable/disable sinks based on config.
        consoleSink.enabled = config.consoleLoggingEnabled;
        stdoutSink?.enabled = config.stdoutLoggingEnabled;
      });
    },
    fireImmediately: true,
  );
});
