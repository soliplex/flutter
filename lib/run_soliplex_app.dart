import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/app.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

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
///       logo: LogoConfig(assetPath: 'assets/my_logo.png'),
///       appName: 'MyBrand',
///       defaultBackendUrl: 'https://api.mybrand.com',
///       features: Features(enableHttpInspector: false),
///     ),
///   );
/// }
/// ```
Future<void> runSoliplexApp({
  required SoliplexConfig config,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors (layout, build, rendering).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogManager.instance.emit(
      LogRecord(
        level: LogLevel.fatal,
        message: 'FlutterError: ${details.exceptionAsString()}',
        timestamp: DateTime.now(),
        loggerName: 'Flutter',
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
  };

  // Capture unhandled async errors via PlatformDispatcher (modern Flutter).
  // Avoids zone mismatch issues and preserves debugger stack traces.
  PlatformDispatcher.instance.onError = (error, stack) {
    LogManager.instance.emit(
      LogRecord(
        level: LogLevel.fatal,
        message: 'Unhandled error: $error',
        timestamp: DateTime.now(),
        loggerName: 'Platform',
        error: error,
        stackTrace: stack,
      ),
    );
    return true; // Handled — prevent default error reporting.
  };

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

  // Pre-load SharedPreferences for synchronous log config initialization.
  // This eliminates the race condition where early logs are dropped.
  final prefs = await SharedPreferences.getInstance();

  // Load saved base URL BEFORE app starts to avoid race conditions.
  // Returns null if user hasn't saved a custom URL yet.
  String? savedBaseUrl;
  try {
    savedBaseUrl = await loadSavedBaseUrl();
  } catch (e, s) {
    Loggers.config.warning(
      'Failed to load saved base URL: $e',
      error: e,
      stackTrace: s,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        // Inject shell configuration via ProviderScope (no global state)
        shellConfigProvider.overrideWithValue(config),
        capturedCallbackParamsProvider.overrideWithValue(callbackParams),
        // Fulfills the contract of preloadedPrefsProvider, enabling
        // synchronous log config initialization (no race condition).
        preloadedPrefsProvider.overrideWithValue(prefs),
        // Inject user's saved base URL if available
        if (savedBaseUrl != null)
          preloadedBaseUrlProvider.overrideWithValue(savedBaseUrl),
      ],
      child: const SoliplexApp(),
    ),
  );
}
