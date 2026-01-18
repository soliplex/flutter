import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soliplex_frontend/app.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/extension/soliplex_registry.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

/// Entry point for running a Soliplex-based application.
///
/// This function encapsulates all initialization required to run the app:
/// - OAuth callback handling
/// - Auth storage initialization
/// - Config loading
/// - Package info retrieval
///
/// Use this in your main.dart for a white-label app:
/// ```dart
/// void main() {
///   runSoliplexApp(
///     config: SoliplexConfig(
///       appName: 'MyBrand',
///       defaultBackendUrl: 'https://api.mybrand.com',
///       features: Features(enableHttpInspector: false),
///     ),
///   );
/// }
/// ```
///
/// For advanced customization, provide a [registry] with custom panels,
/// commands, and routes.
Future<void> runSoliplexApp({
  SoliplexConfig config = const SoliplexConfig(),
  SoliplexRegistry registry = const EmptyRegistry(),
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

  // Load saved config BEFORE app starts to avoid race conditions.
  // Wrapped in try/catch to ensure app launches even if config load fails.
  try {
    await initializeConfig();
  } catch (e) {
    debugPrint('Failed to load user config: $e');
  }

  // Load package info for version display.
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        // Inject shell configuration via ProviderScope (no global state)
        shellConfigProvider.overrideWithValue(config),
        registryProvider.overrideWithValue(registry),
        capturedCallbackParamsProvider.overrideWithValue(callbackParams),
        packageInfoProvider.overrideWithValue(packageInfo),
      ],
      child: const SoliplexApp(),
    ),
  );
}
