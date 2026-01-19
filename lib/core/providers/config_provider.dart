import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';

const _baseUrlKey = 'backend_base_url';

/// Returns the default backend URL based on platform.
///
/// Native: localhost:8000
/// Web + localhost/127.0.0.1: localhost:8000 (local dev server)
/// Web + production: same origin as client
String defaultBaseUrl() {
  if (!kIsWeb) return 'http://localhost:8000';

  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return 'http://localhost:8000';
  }
  return Uri.base.origin;
}

/// Initial config loaded before app starts.
///
/// Set this in main() via [initializeConfig] BEFORE runApp().
AppConfig? _preloadedConfig;

/// Loads and caches config from SharedPreferences.
///
/// Call this in main() BEFORE runApp() to ensure the correct URL
/// is available from the first frame (avoids race conditions).
Future<void> initializeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString(_baseUrlKey);
  if (savedUrl != null && savedUrl.isNotEmpty) {
    _preloadedConfig = AppConfig(baseUrl: savedUrl);
  }
}

/// Notifier for application configuration.
///
/// Persists baseUrl to SharedPreferences for cross-session persistence.
class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    return _preloadedConfig ?? AppConfig(baseUrl: defaultBaseUrl());
  }

  /// Update the backend URL and persist to storage.
  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == state.baseUrl) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, trimmed);

    state = state.copyWith(baseUrl: trimmed);
  }

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
