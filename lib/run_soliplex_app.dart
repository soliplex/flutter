import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/app.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

/// Entry point for running a Soliplex-based application.
///
/// This function encapsulates all initialization required to run the app:
/// - OAuth callback handling
/// - Auth storage initialization
/// - Config loading
///
/// Use this in your main.dart for a white-label app:
/// ```dart
/// Future<void> main() async {
///   await runSoliplexApp(
///     config: SoliplexConfig(
///       appName: 'MyBrand',
///       defaultBackendUrl: 'https://api.mybrand.com',
///       features: Features(enableHttpInspector: false),
///     ),
///   );
/// }
/// ```
Future<void> runSoliplexApp({
  SoliplexConfig config = const SoliplexConfig(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture OAuth callback params BEFORE GoRouter initializes.
  // GoRouter may modify the URL, losing the callback tokens.
  final callbackParams = CallbackParamsCapture.captureNow();

  // Clear URL params immediately after capture (security: remove tokens).
  // Must happen before GoRouter initializes to avoid URL state conflicts.
  final callbackService = createCallbackParamsService();
  if (callbackParams is WebCallbackParams) {
    callbackService.clearUrlParams();
  }

  // Clear stale keychain tokens on first launch after reinstall.
  // iOS preserves Keychain across uninstall/reinstall.
  await clearAuthStorageOnReinstall();

  // Load saved base URL BEFORE app starts to avoid race conditions.
  // Returns null if user hasn't saved a custom URL yet.
  String? savedBaseUrl;
  try {
    savedBaseUrl = await loadSavedBaseUrl();
  } catch (e) {
    debugPrint('Failed to load saved base URL: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        // Inject shell configuration via ProviderScope (no global state)
        shellConfigProvider.overrideWithValue(config),
        capturedCallbackParamsProvider.overrideWithValue(callbackParams),
        // Inject user's saved base URL if available
        if (savedBaseUrl != null)
          preloadedBaseUrlProvider.overrideWithValue(savedBaseUrl),
      ],
      child: const SoliplexApp(),
    ),
  );
}
