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

/// Provider that manages the console sink lifecycle.
///
/// This is the single source of truth for console sink management.
/// It watches the log config and adds/removes the sink accordingly.
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

  if (!config.consoleLoggingEnabled) {
    return null;
  }

  final sink = ConsoleSink();
  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
  });

  return sink;
});

/// Provider that manages the stdout sink lifecycle (desktop only).
///
/// On desktop platforms (macOS, Windows, Linux), writes logs to stdout
/// for terminal visibility. On mobile and web, this provider returns null.
final stdoutSinkProvider = Provider<StdoutSink?>((ref) {
  // Web never uses StdoutSink.
  if (kIsWeb) return null;

  // Only enable on desktop platforms.
  final isDesktop = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => true,
    TargetPlatform.windows => true,
    TargetPlatform.linux => true,
    _ => false,
  };

  if (!isDesktop) return null;

  // Keep this provider alive even when not watched.
  ref.keepAlive();

  final configAsync = ref.watch(logConfigProvider);

  final config = configAsync.when(
    data: (config) => config,
    loading: () => LogConfig.defaultConfig,
    error: (_, __) => LogConfig.defaultConfig,
  );

  if (!config.stdoutLoggingEnabled) return null;

  final sink = StdoutSink();
  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
  });

  return sink;
});
