import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/connectivity_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:uuid/uuid.dart';

/// SharedPreferences key for persistent install ID.
const _kInstallIdKey = 'install_id';

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

  final memorySink = ref.read(memorySinkProvider);

  final sink = BackendLogSink(
    endpoint: endpoint,
    client: client,
    installId: installId,
    sessionId: sessionId,
    diskQueue: diskQueue,
    memorySink: memorySink,
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
