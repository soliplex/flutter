import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soliplex_frontend/app.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';

Future<void> main() async {
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
  await initializeConfig();

  // Load package info for version display.
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        capturedCallbackParamsProvider.overrideWithValue(callbackParams),
        packageInfoProvider.overrideWithValue(packageInfo),
      ],
      child: const SoliplexApp(),
    ),
  );
}
