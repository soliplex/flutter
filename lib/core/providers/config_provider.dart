import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';

const _baseUrlKey = 'backend_base_url';

/// Returns the default backend URL based on platform.
///
/// Used as fallback when shellConfigProvider is not available (e.g., in tests
/// that don't override it).
///
/// Native: localhost:8000
/// Web + localhost/127.0.0.1: localhost:8000 (local dev server)
/// Web + production: same origin as client
String _platformDefaultUrl() {
  if (!kIsWeb) return 'http://localhost:8000';

  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return 'http://localhost:8000';
  }
  return Uri.base.origin;
}

/// Provider for preloaded base URL from SharedPreferences.
///
/// Override this in ProviderScope if a saved URL exists (loaded before app
/// starts). When null, [ConfigNotifier] falls back to
/// [defaultBackendUrlProvider].
final preloadedBaseUrlProvider = Provider<String?>((ref) => null);

/// Provider for the default backend URL.
///
/// Override this in ProviderScope to set the white-label app's default URL.
/// Falls back to platform-specific default (localhost:8000 for native).
final defaultBackendUrlProvider = Provider<String>((ref) {
  return _platformDefaultUrl();
});

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
/// Uses [preloadedBaseUrlProvider] (user's saved preference) if available,
/// otherwise falls back to [defaultBackendUrlProvider].
class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    // Priority: 1) User's saved URL from SharedPreferences
    //           2) Default backend URL from provider
    //
    // Use ref.watch() per Riverpod best practices. While these values are
    // typically static, watch enables proper rebuilding in tests.
    final preloadedUrl = ref.watch(preloadedBaseUrlProvider);
    if (preloadedUrl != null) {
      return AppConfig(baseUrl: preloadedUrl);
    }

    return AppConfig(baseUrl: ref.watch(defaultBackendUrlProvider));
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
