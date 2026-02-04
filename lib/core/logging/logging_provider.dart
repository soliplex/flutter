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

/// The single console sink instance for the app lifecycle.
///
/// Created once and persisted. Enable/disable via config rather than
/// add/remove to avoid race conditions during provider rebuilds.
final _consoleSink = ConsoleSink();

/// Provider that manages the console sink lifecycle.
///
/// This is the single source of truth for console sink management.
/// It watches the log config and enables/disables the sink accordingly.
final consoleSinkProvider = Provider<ConsoleSink?>((ref) {
  // Keep this provider alive even when not watched.
  ref.keepAlive();

  final configAsync = ref.watch(logConfigProvider);

  final config = configAsync.when(
    data: (config) => config,
    loading: () => LogConfig.defaultConfig,
    error: (_, __) => LogConfig.defaultConfig,
  );

  // Apply minimum level to LogManager.
  LogManager.instance.minimumLevel = config.minimumLevel;

  // Ensure sink is registered (idempotent - LogManager checks for duplicates).
  LogManager.instance.addSink(_consoleSink);

  // Enable/disable based on config.
  _consoleSink.enabled = config.consoleLoggingEnabled;

  return config.consoleLoggingEnabled ? _consoleSink : null;
});

/// The single stdout sink instance for the app lifecycle (desktop only).
///
/// Created once and persisted. Enable/disable via config rather than
/// add/remove to avoid race conditions during provider rebuilds.
/// Null on non-desktop platforms.
final StdoutSink? _stdoutSink = _createStdoutSinkIfDesktop();

StdoutSink? _createStdoutSinkIfDesktop() {
  if (kIsWeb) return null;
  final isDesktop = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => true,
    TargetPlatform.windows => true,
    TargetPlatform.linux => true,
    _ => false,
  };
  return isDesktop ? StdoutSink() : null;
}

/// Provider that manages the stdout sink lifecycle (desktop only).
///
/// On desktop platforms (macOS, Windows, Linux), writes logs to stdout
/// for terminal visibility. On mobile and web, this provider returns null.
final stdoutSinkProvider = Provider<StdoutSink?>((ref) {
  // Non-desktop platforms don't have stdout sink.
  final sink = _stdoutSink;
  if (sink == null) return null;

  // Keep this provider alive even when not watched.
  ref.keepAlive();

  final configAsync = ref.watch(logConfigProvider);

  final config = configAsync.when(
    data: (config) => config,
    loading: () => LogConfig.defaultConfig,
    error: (_, __) => LogConfig.defaultConfig,
  );

  // Ensure sink is registered (idempotent - LogManager checks for duplicates).
  LogManager.instance.addSink(sink);

  // Enable/disable based on config.
  sink.enabled = config.stdoutLoggingEnabled;

  return config.stdoutLoggingEnabled ? sink : null;
});
