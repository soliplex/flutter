import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

const _baseUrlKey = 'backend_base_url';

/// Returns the default backend URL based on platform.
///
/// Native: returns [configUrl]
/// Web + localhost/127.0.0.1: returns [configUrl]
/// Web + production: returns same origin as client (ignores [configUrl])
String platformDefaultBackendUrl(String configUrl) {
  if (!kIsWeb) return configUrl;

  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return configUrl;
  }
  return Uri.base.origin;
}

/// Provider for preloaded base URL from SharedPreferences.
///
/// Override this in ProviderScope if a saved URL exists (loaded before app
/// starts). When null, [ConfigNotifier] falls back to
/// `shellConfigProvider.defaultBackendUrl`.
final preloadedBaseUrlProvider = Provider<String?>((ref) => null);

/// Loads saved base URL from SharedPreferences.
///
/// Call this in main() BEFORE runApp() to get the user's saved URL.
/// Pass the result as an override to [preloadedBaseUrlProvider].
///
/// Returns null if no URL was previously saved.
Future<String?> loadSavedBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString(_baseUrlKey);
  if (savedUrl != null && savedUrl.isNotEmpty) {
    return savedUrl;
  }
  return null;
}

/// Notifier for application configuration.
///
/// Persists baseUrl to SharedPreferences for cross-session persistence.
/// URL resolution priority:
/// 1. User's saved URL from SharedPreferences
/// 2. Platform default via [platformDefaultBackendUrl] (uses config URL on
///    native/localhost, origin on web production)
class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    // Priority: 1) User's saved URL from SharedPreferences
    //           2) Platform default (config URL on native, origin on web prod)
    //
    // Use ref.watch() per Riverpod best practices. While these values are
    // typically static, watch enables proper rebuilding in tests.
    final preloadedUrl = ref.watch(preloadedBaseUrlProvider);
    if (preloadedUrl != null) {
      Loggers.config.debug('URL resolved from saved preferences');
      return AppConfig(baseUrl: preloadedUrl);
    }

    final configUrl = ref.watch(shellConfigProvider).defaultBackendUrl;
    final resolved = platformDefaultBackendUrl(configUrl);
    Loggers.config.debug(
      'URL resolved from ${kIsWeb ? "platform origin" : "shell config"}',
    );
    return AppConfig(baseUrl: resolved);
  }

  /// Update the backend URL and persist to storage.
  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == state.baseUrl) {
      Loggers.config.trace('Base URL unchanged, skipped');
      return;
    }

    final oldUrl = state.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, trimmed);
    Loggers.config.debug('Base URL persisted to SharedPreferences');

    state = state.copyWith(baseUrl: trimmed);
    Loggers.config.info('Base URL changed: $oldUrl -> $trimmed');
  }

  /// Directly sets the config state without persisting.
  ///
  /// Use [setBaseUrl] for runtime changes that should survive restart.
  /// This method is primarily for testing.
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void set(AppConfig value) => state = value;
}

/// Provider for application configuration.
///
/// Dependent providers (API, auth, etc.) automatically rebuild when
/// baseUrl changes via ref.watch(configProvider).
final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(
  ConfigNotifier.new,
);
