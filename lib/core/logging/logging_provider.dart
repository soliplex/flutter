import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/connectivity_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:uuid/uuid.dart';

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

/// SharedPreferences key for persistent install ID.
const _kInstallIdKey = 'install_id';

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
// Backend Telemetry Providers
// ============================================================================

/// Persistent install ID (UUID v4), generated once and stored in prefs.
final installIdProvider = Provider<String>((ref) {
  ref.keepAlive();
  final prefs = ref.read(preloadedPrefsProvider);
  var id = prefs.getString(_kInstallIdKey);
  if (id == null) {
    id = const Uuid().v4();
    prefs.setString(_kInstallIdKey, id);
  }
  return id;
});

/// Session ID (UUID v4), generated once per provider container lifetime.
final sessionIdProvider = Provider<String>((ref) {
  ref.keepAlive();
  return const Uuid().v4();
});

/// Resource attributes gathered from device and package info.
///
/// Resolved once asynchronously; cached for the lifetime of the container.
final resourceAttributesProvider =
    FutureProvider<Map<String, Object>>((ref) async {
  ref.keepAlive();

  final packageInfo = await PackageInfo.fromPlatform();
  final attributes = <String, Object>{
    'app.version': packageInfo.version,
    'app.build': packageInfo.buildNumber,
    'app.package': packageInfo.packageName,
  };

  if (!kIsWeb) {
    final deviceInfo = DeviceInfoPlugin();
    final base = await deviceInfo.deviceInfo;
    final data = base.data;
    // Extract common fields safely.
    final model = data['model'];
    if (model is String) attributes['device.model'] = model;
    final systemVersion = data['systemVersion'] ?? data['version'];
    if (systemVersion is String) {
      attributes['os.version'] = systemVersion;
    } else if (systemVersion is Map) {
      final release = systemVersion['release'];
      if (release is String) attributes['os.version'] = release;
    }
  }

  attributes['os.type'] = defaultTargetPlatform.name;

  return attributes;
});

/// Holds the [BackendLogSink] instance when backend logging is enabled.
///
/// Created lazily when first accessed. The controller manages registration
/// with LogManager based on config.backendLoggingEnabled.
final backendLogSinkProvider = FutureProvider<BackendLogSink?>((ref) async {
  ref.keepAlive();

  final config = ref.read(logConfigProvider);
  if (!config.backendLoggingEnabled) return null;

  final appConfig = ref.read(configProvider);
  final client = ref.read(httpClientProvider);
  final installId = ref.read(installIdProvider);
  final sessionId = ref.read(sessionIdProvider);
  final endpoint = '${appConfig.baseUrl}${config.backendEndpoint}';

  // Resolve async dependencies.
  final resourceAttrs =
      await ref.read(resourceAttributesProvider.future).catchError(
            (_) => <String, Object>{},
          );

  // DiskQueue uses conditional imports: on web the factory returns an
  // in-memory implementation that ignores directoryPath. The kIsWeb guard
  // here avoids calling getApplicationSupportDirectory() which requires
  // dart:io and is unavailable on web.
  late final DiskQueue diskQueue;
  if (kIsWeb) {
    diskQueue = DiskQueue(directoryPath: '');
  } else {
    final appDir = await getApplicationSupportDirectory();
    diskQueue = DiskQueue(directoryPath: '${appDir.path}/log_queue');
  }

  final sink = BackendLogSink(
    endpoint: endpoint,
    client: client,
    installId: installId,
    sessionId: sessionId,
    diskQueue: diskQueue,
    resourceAttributes: resourceAttrs,
    jwtProvider: () {
      final authState = ref.read(authProvider);
      // AuthLoading: return null to buffer logs until auth resolves.
      if (authState is AuthLoading) return null;
      // Authenticated: send with JWT.
      if (authState is Authenticated) return authState.accessToken;
      // NoAuthRequired / Unauthenticated: send without auth header.
      // Empty string is non-null (skips pre-auth buffer) but omitted
      // from the Authorization header by BackendLogSink.
      return '';
    },
    networkChecker: () {
      final connectivity = ref.read(connectivityProvider);
      return connectivity.maybeWhen(
        data: (results) => !results.contains(ConnectivityResult.none),
        orElse: () => true,
      );
    },
    onError: (message, error) {
      developer.log(
        'BackendLogSink: $message',
        error: error,
        name: 'Telemetry',
      );
    },
  );

  LogManager.instance.addSink(sink);

  ref.onDispose(() {
    LogManager.instance.removeSink(sink);
    unawaited(sink.close());
    unawaited(diskQueue.close());
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
