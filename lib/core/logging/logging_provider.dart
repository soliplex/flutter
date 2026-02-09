import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/backend_logging_provider.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/connectivity_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

export 'package:soliplex_frontend/core/logging/backend_logging_provider.dart'
    show
        backendLogSinkProvider,
        installIdProvider,
        resourceAttributesProvider,
        sessionIdProvider;

/// SharedPreferences key for minimum log level.
const _kLogLevelKey = 'log_level';

/// SharedPreferences key for console logging enabled.
const _kConsoleLoggingKey = 'console_logging';

/// SharedPreferences key for stdout logging enabled.
const _kStdoutLoggingKey = 'stdout_logging';

/// SharedPreferences key for backend logging enabled.
const _kBackendLoggingKey = 'backend_logging';

/// SharedPreferences key for backend endpoint.
const _kBackendEndpointKey = 'backend_endpoint';

/// Notifier for managing log configuration.
///
/// Requires [SharedPreferences] to be pre-loaded via [preloadedPrefsProvider]
/// override in [ProviderScope]. This ensures synchronous config loading and
/// eliminates the race condition where early logs are dropped.
class LogConfigNotifier extends Notifier<LogConfig> {
  late final SharedPreferences _prefs;

  @override
  LogConfig build() {
    _prefs = ref.read(preloadedPrefsProvider);
    return _loadConfig(_prefs);
  }

  LogConfig _loadConfig(SharedPreferences prefs) {
    final levelIndex = prefs.getInt(_kLogLevelKey);
    final consoleEnabled = prefs.getBool(_kConsoleLoggingKey);
    final stdoutEnabled = prefs.getBool(_kStdoutLoggingKey);
    final backendEnabled = prefs.getBool(_kBackendLoggingKey);
    final backendEndpoint = prefs.getString(_kBackendEndpointKey);

    return LogConfig(
      minimumLevel: levelIndex != null && levelIndex < LogLevel.values.length
          ? LogLevel.values[levelIndex]
          : LogConfig.defaultConfig.minimumLevel,
      consoleLoggingEnabled:
          consoleEnabled ?? LogConfig.defaultConfig.consoleLoggingEnabled,
      stdoutLoggingEnabled:
          stdoutEnabled ?? LogConfig.defaultConfig.stdoutLoggingEnabled,
      backendLoggingEnabled:
          backendEnabled ?? LogConfig.defaultConfig.backendLoggingEnabled,
      backendEndpoint:
          backendEndpoint ?? LogConfig.defaultConfig.backendEndpoint,
    );
  }

  /// Updates the minimum log level.
  Future<void> setMinimumLevel(LogLevel level) async {
    await _prefs.setInt(_kLogLevelKey, level.index);
    state = state.copyWith(minimumLevel: level);
  }

  /// Updates whether console logging is enabled.
  Future<void> setConsoleLoggingEnabled({required bool enabled}) async {
    await _prefs.setBool(_kConsoleLoggingKey, enabled);
    state = state.copyWith(consoleLoggingEnabled: enabled);
  }

  /// Updates whether stdout logging is enabled (desktop only).
  Future<void> setStdoutLoggingEnabled({required bool enabled}) async {
    await _prefs.setBool(_kStdoutLoggingKey, enabled);
    state = state.copyWith(stdoutLoggingEnabled: enabled);
  }

  /// Updates whether backend log shipping is enabled.
  Future<void> setBackendLoggingEnabled({required bool enabled}) async {
    await _prefs.setBool(_kBackendLoggingKey, enabled);
    state = state.copyWith(backendLoggingEnabled: enabled);
  }

  /// Updates the backend endpoint for log ingestion.
  Future<void> setBackendEndpoint(String endpoint) async {
    await _prefs.setString(_kBackendEndpointKey, endpoint);
    state = state.copyWith(backendEndpoint: endpoint);
  }
}

/// Provider for pre-loaded [SharedPreferences] instance.
///
/// Must be overridden in [ProviderScope] before app starts. Throws if accessed
/// without override to fail fast rather than silently dropping early logs.
final preloadedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'preloadedPrefsProvider must be overridden with a SharedPreferences '
    'instance. Call SharedPreferences.getInstance() in main() before runApp().',
  );
});

/// Provider for log configuration.
final logConfigProvider =
    NotifierProvider<LogConfigNotifier, LogConfig>(LogConfigNotifier.new);

// ============================================================================
// Sink Instance Providers
// ============================================================================
// These providers own the sink lifecycle. They create the sink once, register
// it with LogManager, and clean up on dispose. They do NOT watch config -
// configuration is applied by the controller.

/// Holds the MemorySink instance (ring buffer for in-app log viewer).
///
/// Created once per provider container. Registered with LogManager on creation,
/// unregistered on dispose. Always enabled - the memory buffer captures all
/// records regardless of config so they are available for error reporting
/// and the log viewer UI.
final memorySinkProvider = Provider<MemorySink>((ref) {
  ref.keepAlive();

  final sink = MemorySink();
  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
    sink.close();
  });

  return sink;
});

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
/// Desktop platforms that support stdout logging.
const _desktopPlatforms = {
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
};

final stdoutSinkProvider = Provider<StdoutSink?>((ref) {
  if (kIsWeb) return null;
  if (!_desktopPlatforms.contains(defaultTargetPlatform)) return null;

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
/// - Creates/destroys `BackendLogSink` based on config
/// - Uses ref.listen to react to config changes without rebuilding sinks
///
/// Watch this provider in your app root to initialize logging.
final logConfigControllerProvider = Provider<void>((ref) {
  ref
    ..keepAlive()
    ..watch(memorySinkProvider); // Always active - no config toggle.

  // Use ref.watch to ensure controller rebuilds if sink instances change
  // (e.g., during hot reload or if sinks are ever recreated).
  final consoleSink = ref.watch(consoleSinkProvider);
  final stdoutSink = ref.watch(stdoutSinkProvider);

  // Apply config immediately and listen for changes.
  void applyConfig(LogConfig? previous, LogConfig config) {
    // Apply minimum level to LogManager (centralized ownership).
    LogManager.instance.minimumLevel = config.minimumLevel;

    // Enable/disable sinks based on config.
    consoleSink.enabled = config.consoleLoggingEnabled;
    stdoutSink?.enabled = config.stdoutLoggingEnabled;

    // Handle backend sink lifecycle on toggle change.
    final backendChanged = previous == null ||
        previous.backendLoggingEnabled != config.backendLoggingEnabled;
    if (backendChanged) {
      // Invalidate to dispose any existing sink (onDispose removes from
      // LogManager and closes it). Then re-read to trigger creation if
      // the new config has backend logging enabled.
      ref
        ..invalidate(backendLogSinkProvider)
        ..read(backendLogSinkProvider);
    }
  }

  // Listen to config changes and network connectivity.
  ref
    ..listen(
      logConfigProvider,
      applyConfig,
      fireImmediately: true,
    )
    ..listen(
      connectivityProvider,
      (previous, next) {
        if (previous == null || !previous.hasValue) return;
        next.whenData((results) {
          Loggers.telemetry.info(
            'network_changed',
            attributes: {
              'connectivity': results.map((r) => r.name).join(', '),
            },
          );
        });
      },
    );
});
